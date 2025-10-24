/**
 * Action Items Extraction
 * 
 * Handles extraction and management of action items from messages
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/**
 * Extract action items from a message
 */
export const extractActionItems = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { messageText, messageId, conversationId, senderId } = data;
  
  try {
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

