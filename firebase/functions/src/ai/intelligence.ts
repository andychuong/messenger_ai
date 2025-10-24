/**
 * Conversation Intelligence Functions
 * 
 * Handles:
 * - Action item extraction
 * - Decision tracking
 * - Priority message detection
 * 
 * Uses GPT-4o with function calling for structured data extraction
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/**
 * Extract action items from a message
 * Can be triggered automatically or manually
 */
export const extractActionItems = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { messageText, messageId, conversationId, senderId } = data;
  // userId available for future permission checks
  // const userId = context.auth.uid;
  
  try {
    // Use GPT-4o to extract action items
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: `You are an expert at extracting action items from conversations.
Analyze the message and identify any tasks, to-dos, or action items.
Extract:
- The specific task description
- Who it's assigned to (if mentioned)
- Any deadline or due date (if mentioned)

Return an array of action items. If none found, return an empty array.`,
        },
        {
          role: "user",
          content: `Extract action items from this message:\n\n${messageText}`,
        },
      ],
      functions: [
        {
          name: "extract_action_items",
          description: "Extract action items from a message",
          parameters: {
            type: "object",
            properties: {
              actionItems: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    task: {
                      type: "string",
                      description: "The task or action item",
                    },
                    assignee: {
                      type: "string",
                      description: "Who the task is assigned to (name or 'unassigned')",
                    },
                    dueDate: {
                      type: "string",
                      description: "Due date if mentioned (ISO format or 'none')",
                    },
                    priority: {
                      type: "string",
                      enum: ["low", "medium", "high"],
                      description: "Priority level",
                    },
                  },
                  required: ["task", "assignee", "priority"],
                },
              },
            },
            required: ["actionItems"],
          },
        },
      ],
      function_call: { name: "extract_action_items" },
      temperature: 0.3,
    });

    const functionCall = completion.choices[0]?.message?.function_call;
    if (!functionCall || !functionCall.arguments) {
      return { actionItems: [], count: 0 };
    }

    const result = JSON.parse(functionCall.arguments);
    const actionItems = result.actionItems || [];

    // Store action items in Firestore
    const batch = admin.firestore().batch();
    const createdItems: any[] = [];

    for (const item of actionItems) {
      const actionItemRef = admin.firestore().collection("actionItems").doc();
      
      const actionItemData = {
        task: item.task,
        assignedTo: item.assignee !== "unassigned" ? item.assignee : null,
        createdBy: senderId,
        conversationId,
        messageId,
        priority: item.priority || "medium",
        status: "pending",
        dueDate: item.dueDate && item.dueDate !== "none" ? item.dueDate : null,
        extractedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      batch.set(actionItemRef, actionItemData);
      createdItems.push({ id: actionItemRef.id, ...actionItemData });
    }

    await batch.commit();

    console.log(`Extracted ${actionItems.length} action items from message ${messageId}`);

    return {
      actionItems: createdItems,
      count: createdItems.length,
    };
  } catch (error) {
    console.error("Extract action items error:", error);
    throw new functions.https.HttpsError("internal", "Failed to extract action items");
  }
});

/**
 * Batch extract action items from multiple messages in a conversation
 */
export const extractActionItemsFromConversation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { conversationId, limit = 50 } = data;
  
  try {
    // Fetch recent messages
    const messagesSnap = await admin.firestore()
      .collection("conversations")
      .doc(conversationId)
      .collection("messages")
      .orderBy("timestamp", "desc")
      .limit(limit)
      .get();
    
    const messages = messagesSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    if (messages.length === 0) {
      return { actionItems: [], count: 0 };
    }

    // Combine messages for batch processing
    const conversationText = messages
      .reverse()
      .map((m: any) => m.text)
      .join("\n");

    // Extract action items from entire conversation
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: `Extract all action items and tasks from this conversation.
Focus on concrete tasks, to-dos, and commitments made.`,
        },
        {
          role: "user",
          content: conversationText,
        },
      ],
      functions: [
        {
          name: "extract_action_items",
          description: "Extract action items from conversation",
          parameters: {
            type: "object",
            properties: {
              actionItems: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    task: { type: "string" },
                    assignee: { type: "string" },
                    priority: { type: "string", enum: ["low", "medium", "high"] },
                  },
                },
              },
            },
          },
        },
      ],
      function_call: { name: "extract_action_items" },
      temperature: 0.3,
    });

    const functionCall = completion.choices[0]?.message?.function_call;
    if (!functionCall || !functionCall.arguments) {
      return { actionItems: [], count: 0 };
    }

    const result = JSON.parse(functionCall.arguments);
    const actionItems = result.actionItems || [];

    // Store in Firestore
    const batch = admin.firestore().batch();
    const createdItems: any[] = [];

    for (const item of actionItems) {
      const actionItemRef = admin.firestore().collection("actionItems").doc();
      
      const actionItemData = {
        task: item.task,
        assignedTo: item.assignee !== "unassigned" ? item.assignee : null,
        createdBy: context.auth!.uid,
        conversationId,
        priority: item.priority || "medium",
        status: "pending",
        extractedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      batch.set(actionItemRef, actionItemData);
      createdItems.push({ id: actionItemRef.id, ...actionItemData });
    }

    await batch.commit();

    return {
      actionItems: createdItems,
      count: createdItems.length,
    };
  } catch (error) {
    console.error("Batch extract action items error:", error);
    throw new functions.https.HttpsError("internal", "Failed to extract action items");
  }
});

/**
 * Detect and track decisions made in conversations
 */
export const detectDecision = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { messageText, messageId, conversationId, senderId } = data;
  
  try {
    // Use GPT-4o to detect decisions
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: `You are an expert at identifying decisions in conversations.
Analyze the message and determine if a decision was made.
A decision is:
- A firm choice between alternatives
- A commitment to a course of action
- An agreement or resolution

Extract:
- The decision made
- The rationale or reasoning (if provided)
- The outcome or next steps

Return null if no clear decision is present.`,
        },
        {
          role: "user",
          content: `Analyze this message for decisions:\n\n${messageText}`,
        },
      ],
      functions: [
        {
          name: "detect_decision",
          description: "Detect if a decision was made in the message",
          parameters: {
            type: "object",
            properties: {
              hasDecision: {
                type: "boolean",
                description: "Whether a decision was made",
              },
              decision: {
                type: "string",
                description: "The decision that was made",
              },
              rationale: {
                type: "string",
                description: "The reasoning behind the decision",
              },
              outcome: {
                type: "string",
                description: "Expected outcome or next steps",
              },
            },
            required: ["hasDecision"],
          },
        },
      ],
      function_call: { name: "detect_decision" },
      temperature: 0.3,
    });

    const functionCall = completion.choices[0]?.message?.function_call;
    if (!functionCall || !functionCall.arguments) {
      return { hasDecision: false };
    }

    const result = JSON.parse(functionCall.arguments);

    if (!result.hasDecision) {
      return { hasDecision: false };
    }

    // Store decision in Firestore
    const decisionRef = admin.firestore().collection("decisions").doc();
    
    const decisionData = {
      decision: result.decision,
      rationale: result.rationale || null,
      outcome: result.outcome || null,
      conversationId,
      messageId,
      decidedBy: senderId,
      detectedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await decisionRef.set(decisionData);

    console.log(`Detected decision in message ${messageId}`);

    return {
      hasDecision: true,
      decision: { id: decisionRef.id, ...decisionData },
    };
  } catch (error) {
    console.error("Detect decision error:", error);
    throw new functions.https.HttpsError("internal", "Failed to detect decision");
  }
});

/**
 * Classify message priority
 * Detects urgent messages, mentions, questions, etc.
 */
export const classifyPriority = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { messageText, messageId, conversationId, mentions } = data;
  const userId = context.auth.uid;
  
  try {
    // Use GPT-4o to classify priority
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: `You are an expert at classifying message priority.
Analyze the message and determine its priority level based on:
- Urgency indicators (ASAP, urgent, immediately, deadline)
- Questions requiring response
- Mentions or direct requests
- Emotional tone
- Time sensitivity

Priority levels:
- high: Urgent, requires immediate attention
- medium: Important but not urgent
- low: Informational, no action needed`,
        },
        {
          role: "user",
          content: `Classify priority for this message:\n\n${messageText}`,
        },
      ],
      functions: [
        {
          name: "classify_priority",
          description: "Classify message priority",
          parameters: {
            type: "object",
            properties: {
              priority: {
                type: "string",
                enum: ["low", "medium", "high"],
                description: "Priority level",
              },
              reason: {
                type: "string",
                description: "Reason for the priority classification",
              },
              requiresResponse: {
                type: "boolean",
                description: "Whether the message requires a response",
              },
            },
            required: ["priority", "reason"],
          },
        },
      ],
      function_call: { name: "classify_priority" },
      temperature: 0.3,
    });

    const functionCall = completion.choices[0]?.message?.function_call;
    if (!functionCall || !functionCall.arguments) {
      return { priority: "medium", reason: "Unable to classify" };
    }

    const result = JSON.parse(functionCall.arguments);

    // Boost priority if user is mentioned
    let finalPriority = result.priority;
    if (mentions && mentions.includes(userId)) {
      finalPriority = "high";
      result.reason = "You were mentioned - " + result.reason;
    }

    // Update message metadata with priority
    await admin.firestore()
      .collection("conversations")
      .doc(conversationId)
      .collection("messages")
      .doc(messageId)
      .update({
        priority: finalPriority,
        priorityReason: result.reason,
        requiresResponse: result.requiresResponse || false,
        priorityUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      priority: finalPriority,
      reason: result.reason,
      requiresResponse: result.requiresResponse,
    };
  } catch (error) {
    console.error("Classify priority error:", error);
    throw new functions.https.HttpsError("internal", "Failed to classify priority");
  }
});

/**
 * Update action item status
 */
export const updateActionItemStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { actionItemId, status, completedBy } = data;
  
  try {
    await admin.firestore()
      .collection("actionItems")
      .doc(actionItemId)
      .update({
        status,
        completedBy: status === "completed" ? completedBy : null,
        completedAt: status === "completed" ? admin.firestore.FieldValue.serverTimestamp() : null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return { success: true };
  } catch (error) {
    console.error("Update action item error:", error);
    throw new functions.https.HttpsError("internal", "Failed to update action item");
  }
});

/**
 * Get user's action items
 */
export const getUserActionItems = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { status = "pending", limit = 50 } = data;
  const userId = context.auth.uid;
  
  try {
    const actionItemsSnap = await admin.firestore()
      .collection("actionItems")
      .where("assignedTo", "==", userId)
      .where("status", "==", status)
      .orderBy("priority", "desc")
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    const actionItems = actionItemsSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      actionItems,
      count: actionItems.length,
    };
  } catch (error) {
    console.error("Get action items error:", error);
    throw new functions.https.HttpsError("internal", "Failed to get action items");
  }
});

/**
 * Get conversation decisions
 */
export const getConversationDecisions = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { conversationId, limit = 20 } = data;
  
  try {
    const decisionsSnap = await admin.firestore()
      .collection("decisions")
      .where("conversationId", "==", conversationId)
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    const decisions = decisionsSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      decisions,
      count: decisions.length,
    };
  } catch (error) {
    console.error("Get decisions error:", error);
    throw new functions.https.HttpsError("internal", "Failed to get decisions");
  }
});

