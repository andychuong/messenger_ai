/**
 * Decision Tracking
 * 
 * Handles detection and tracking of decisions made in conversations
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
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

