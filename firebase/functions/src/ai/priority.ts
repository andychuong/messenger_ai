/**
 * Priority Classification
 * 
 * Handles message priority detection and classification
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
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

