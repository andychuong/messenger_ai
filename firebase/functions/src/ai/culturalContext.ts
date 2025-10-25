/**
 * Cultural Context Analysis Functions
 * 
 * Phase 15.1: Provides cultural context and nuances for translated messages
 * Helps users understand cultural-specific phrases, idioms, and formality levels
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface CulturalContextRequest {
  messageId: string;
  conversationId: string;
  text: string;
  sourceLanguage: string;
  targetLanguage: string;
  messageContext?: string[]; // Previous messages for context
}

interface Idiom {
  phrase: string;
  meaning: string;
  culturalSignificance?: string;
}

interface CulturalContextResponse {
  culturalNotes: string[];
  idioms: Idiom[];
  formalityLevel: "very_formal" | "formal" | "neutral" | "casual" | "very_casual";
  recommendations?: string[];
  timestamp: string;
}

/**
 * Analyze cultural context of a message
 * Identifies culturally-specific phrases, idioms, and formality level
 */
export const analyzeCulturalContext = functions.https.onCall(
  async (data: CulturalContextRequest, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const {
      messageId,
      conversationId,
      text,
      sourceLanguage,
      targetLanguage,
      messageContext,
    } = data;

    if (!text || !sourceLanguage || !targetLanguage) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields"
      );
    }

    try {
      // Check if already cached
      const messageRef = admin
        .firestore()
        .collection("conversations")
        .doc(conversationId)
        .collection("messages")
        .doc(messageId);

      const messageSnap = await messageRef.get();
      if (messageSnap.exists) {
        const cachedContext = messageSnap.data()?.culturalContext;
        if (
          cachedContext &&
          cachedContext.sourceLanguage === sourceLanguage &&
          cachedContext.analyzed
        ) {
          console.log("Returning cached cultural context");
          return {
            ...cachedContext,
            fromCache: true,
          };
        }
      }

      // Build context from previous messages if available
      let contextString = "";
      if (messageContext && messageContext.length > 0) {
        contextString = "\n\nPrevious conversation context:\n" + messageContext.join("\n");
      }

      // Use GPT-4o to analyze cultural context
      const completion = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content: `You are a cultural linguistics expert. Analyze the following message in ${sourceLanguage} for cultural context, idioms, and formality level. The reader speaks ${targetLanguage}.

Provide your analysis in the following JSON format:
{
  "culturalNotes": ["note1", "note2", ...],
  "idioms": [{"phrase": "...", "meaning": "...", "culturalSignificance": "..."}],
  "formalityLevel": "very_formal|formal|neutral|casual|very_casual",
  "recommendations": ["recommendation1", ...]
}

Focus on:
1. Cultural-specific expressions or references
2. Idioms and their literal vs. figurative meanings
3. The formality level based on language markers (honorifics, vocabulary, grammar)
4. Recommendations for understanding the message in the target culture

Only include significant findings. If there are no idioms, return an empty array. Keep notes concise and informative.`,
          },
          {
            role: "user",
            content: `Message to analyze: "${text}"${contextString}`,
          },
        ],
        temperature: 0.3,
        max_tokens: 1000,
        response_format: { type: "json_object" },
      });

      const responseText = completion.choices[0]?.message?.content?.trim();
      if (!responseText) {
        throw new functions.https.HttpsError("internal", "Analysis failed");
      }

      let analysis: CulturalContextResponse;
      try {
        analysis = JSON.parse(responseText);
      } catch (error) {
        console.error("Failed to parse GPT response:", responseText);
        throw new functions.https.HttpsError(
          "internal",
          "Failed to parse analysis"
        );
      }

      // Add timestamp
      const result: CulturalContextResponse = {
        culturalNotes: analysis.culturalNotes || [],
        idioms: analysis.idioms || [],
        formalityLevel: analysis.formalityLevel || "neutral",
        recommendations: analysis.recommendations || [],
        timestamp: new Date().toISOString(),
      };

      // Cache in Firestore
      await messageRef.set(
        {
          culturalContext: {
            analyzed: true,
            sourceLanguage,
            notes: result.culturalNotes,
            idioms: result.idioms,
            formalityLevel: result.formalityLevel,
            recommendations: result.recommendations,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );

      console.log(
        `Analyzed cultural context for message ${messageId} (${sourceLanguage} → ${targetLanguage})`
      );

      return {
        ...result,
        fromCache: false,
      };
    } catch (error) {
      console.error("Cultural context analysis error:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to analyze cultural context"
      );
    }
  }
);

