/**
 * Formality Level Adjustment Functions
 * 
 * Phase 15.2: Allow users to adjust the formality level of their messages
 * Helps adapt communication style for different contexts
 */

import * as functions from "firebase-functions";
import OpenAI from "openai";

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface FormalityAdjustmentRequest {
  text: string;
  language: string;
  targetFormality: "formal" | "neutral" | "casual";
  currentFormality?: string;
  context?: "business" | "personal" | "academic" | "customer_service";
}

interface FormalityChange {
  original: string;
  adjusted: string;
  reason: string;
}

interface FormalityAdjustmentResponse {
  adjustedText: string;
  originalFormality: string;
  targetFormality: string;
  changes: FormalityChange[];
}

/**
 * Adjust the formality level of a message
 * Rewrites text to match the desired formality while preserving meaning
 */
export const adjustFormality = functions.https.onCall(
  async (data: FormalityAdjustmentRequest, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { text, language, targetFormality, currentFormality, context: messageContext } = data;

    if (!text || !language || !targetFormality) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: text, language, targetFormality"
      );
    }

    if (!["formal", "neutral", "casual"].includes(targetFormality)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "targetFormality must be 'formal', 'neutral', or 'casual'"
      );
    }

    try {
      // Build context description
      let contextDescription = "";
      if (messageContext) {
        const contextMap = {
          business: "professional business communication",
          personal: "personal conversation with friends/family",
          academic: "academic or educational setting",
          customer_service: "customer service interaction",
        };
        contextDescription = ` in a ${contextMap[messageContext] || messageContext} context`;
      }

      // Use GPT-4o to adjust formality
      const completion = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content: `You are a professional writing assistant specializing in adjusting formality levels. 
Your task is to rewrite messages to match a specific formality level while preserving the original meaning and intent.

The target formality level is: ${targetFormality}${contextDescription}

Formality guidelines:
- FORMAL: Use polite language, honorifics, complete sentences, formal vocabulary, avoid contractions
- NEUTRAL: Balanced approach, clear and professional but not stiff
- CASUAL: Conversational tone, contractions allowed, informal vocabulary, can use slang appropriately

Provide your response in the following JSON format:
{
  "adjustedText": "the rewritten message",
  "originalFormality": "formal|neutral|casual",
  "changes": [
    {
      "original": "original phrase",
      "adjusted": "adjusted phrase",
      "reason": "brief explanation of why this was changed"
    }
  ]
}

If no changes are needed, return the original text with an empty changes array.`,
          },
          {
            role: "user",
            content: `Original message in ${language}: "${text}"`,
          },
        ],
        temperature: 0.4,
        max_tokens: 1500,
        response_format: { type: "json_object" },
      });

      const responseText = completion.choices[0]?.message?.content?.trim();
      if (!responseText) {
        throw new functions.https.HttpsError("internal", "Adjustment failed");
      }

      let adjustment: FormalityAdjustmentResponse;
      try {
        adjustment = JSON.parse(responseText);
      } catch (error) {
        console.error("Failed to parse GPT response:", responseText);
        throw new functions.https.HttpsError(
          "internal",
          "Failed to parse adjustment"
        );
      }

      // Validate and structure response
      const result: FormalityAdjustmentResponse = {
        adjustedText: adjustment.adjustedText || text,
        originalFormality: adjustment.originalFormality || currentFormality || "neutral",
        targetFormality,
        changes: adjustment.changes || [],
      };

      console.log(
        `Adjusted message formality from ${result.originalFormality} to ${targetFormality} in ${language}`
      );

      return result;
    } catch (error) {
      console.error("Formality adjustment error:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to adjust formality"
      );
    }
  }
);

/**
 * Detect the formality level of a message without adjusting it
 * Useful for showing current formality to users
 */
export const detectFormality = functions.https.onCall(
  async (data: { text: string; language: string }, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { text, language } = data;

    if (!text || !language) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields"
      );
    }

    try {
      const completion = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content: `Analyze the formality level of the following ${language} message.
Classify it as: "very_formal", "formal", "neutral", "casual", or "very_casual"

Return only a JSON object with this format:
{
  "formalityLevel": "the detected level",
  "reasoning": "brief explanation of why"
}`,
          },
          {
            role: "user",
            content: text,
          },
        ],
        temperature: 0.3,
        max_tokens: 200,
        response_format: { type: "json_object" },
      });

      const responseText = completion.choices[0]?.message?.content?.trim();
      if (!responseText) {
        throw new functions.https.HttpsError("internal", "Detection failed");
      }

      const result = JSON.parse(responseText);
      return result;
    } catch (error) {
      console.error("Formality detection error:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to detect formality"
      );
    }
  }
);

