/**
 * Slang and Idiom Explanation Functions
 * 
 * Phase 15.3: Automatically detect and explain slang, idioms, and colloquial expressions
 * Helps improve understanding across cultures and generations
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface SlangExplanationRequest {
  messageId: string;
  conversationId: string;
  text: string;
  language: string;
  userLanguage?: string; // For explanation language
}

interface DetectedExpression {
  phrase: string;
  type: "slang" | "idiom" | "colloquialism" | "cultural_reference";
  explanation: string;
  literalMeaning?: string;
  origin?: string;
  usage: string;
  alternatives?: string[];
  isRegional?: boolean;
  region?: string;
}

interface SlangExplanationResponse {
  detectedExpressions: DetectedExpression[];
  hasSlang: boolean;
  timestamp: string;
}

/**
 * Detect and explain slang and idioms in a message
 */
export const explainSlangAndIdioms = functions.https.onCall(
  async (data: SlangExplanationRequest, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const { messageId, conversationId, text, language, userLanguage } = data;

    if (!text || !language) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Missing required fields: text, language"
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
        const cachedAnalysis = messageSnap.data()?.slangAnalysis;
        if (cachedAnalysis && cachedAnalysis.analyzed) {
          console.log("Returning cached slang analysis");
          return {
            ...cachedAnalysis,
            fromCache: true,
          };
        }
      }

      const explanationLanguage = userLanguage || language;

      // Use GPT-4o to detect and explain slang/idioms
      const completion = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content: `You are a linguistics expert specializing in slang, idioms, and colloquial expressions.

Analyze the following ${language} message and identify any:
1. Slang terms (informal words/phrases specific to a group or region)
2. Idioms (figurative expressions with meanings different from literal interpretation)
3. Colloquialisms (informal conversational expressions)
4. Cultural references (references to culture-specific concepts)

For each expression found, provide explanations in ${explanationLanguage}.

Return your analysis in this JSON format:
{
  "detectedExpressions": [
    {
      "phrase": "the exact phrase from the text",
      "type": "slang|idiom|colloquialism|cultural_reference",
      "explanation": "clear explanation of what it means",
      "literalMeaning": "what it literally says (if different from meaning)",
      "origin": "brief origin/etymology if interesting",
      "usage": "how and when to use it",
      "alternatives": ["more formal alternatives"],
      "isRegional": true/false,
      "region": "region name if regional"
    }
  ]
}

Only include expressions that would genuinely benefit from explanation. Ignore common everyday language.
If no slang/idioms found, return empty array.`,
          },
          {
            role: "user",
            content: `Message: "${text}"`,
          },
        ],
        temperature: 0.3,
        max_tokens: 2000,
        response_format: { type: "json_object" },
      });

      const responseText = completion.choices[0]?.message?.content?.trim();
      if (!responseText) {
        throw new functions.https.HttpsError("internal", "Analysis failed");
      }

      let analysis: { detectedExpressions: DetectedExpression[] };
      try {
        analysis = JSON.parse(responseText);
      } catch (error) {
        console.error("Failed to parse GPT response:", responseText);
        throw new functions.https.HttpsError(
          "internal",
          "Failed to parse analysis"
        );
      }

      const result: SlangExplanationResponse = {
        detectedExpressions: analysis.detectedExpressions || [],
        hasSlang: (analysis.detectedExpressions || []).length > 0,
        timestamp: new Date().toISOString(),
      };

      // Cache in Firestore
      await messageRef.set(
        {
          slangAnalysis: {
            analyzed: true,
            expressions: result.detectedExpressions,
            hasSlang: result.hasSlang,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );

      console.log(
        `Analyzed slang/idioms for message ${messageId}: found ${result.detectedExpressions.length} expressions`
      );

      return {
        ...result,
        fromCache: false,
      };
    } catch (error) {
      console.error("Slang explanation error:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        "Failed to analyze slang and idioms"
      );
    }
  }
);

/**
 * Batch analyze multiple messages for slang/idioms
 * Useful for analyzing entire conversations
 */
export const batchExplainSlang = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    const { messageIds, conversationId, language, userLanguage } = data;

    if (!Array.isArray(messageIds) || messageIds.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "messageIds must be a non-empty array"
      );
    }

    if (messageIds.length > 20) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Maximum 20 messages per batch"
      );
    }

    try {
      const analyses: any[] = [];

      // Get all messages
      const messagesRef = admin
        .firestore()
        .collection("conversations")
        .doc(conversationId)
        .collection("messages");

      for (const messageId of messageIds) {
        try {
          const messageSnap = await messagesRef.doc(messageId).get();
          if (!messageSnap.exists) {
            analyses.push({
              messageId,
              success: false,
              error: "Message not found",
            });
            continue;
          }

          const messageData = messageSnap.data();
          const result = await explainSlangAndIdioms.run(
            {
              messageId,
              conversationId,
              text: messageData?.text || "",
              language,
              userLanguage,
            },
            context as any
          );

          analyses.push({
            messageId,
            success: true,
            ...result,
          });
        } catch (error) {
          console.error(`Failed to analyze message ${messageId}:`, error);
          analyses.push({
            messageId,
            success: false,
            error: "Analysis failed",
          });
        }
      }

      return {
        analyses,
        totalProcessed: analyses.length,
        successCount: analyses.filter((a) => a.success).length,
        totalExpressionsFound: analyses
          .filter((a) => a.success)
          .reduce((sum, a) => sum + (a.detectedExpressions?.length || 0), 0),
      };
    } catch (error) {
      console.error("Batch slang analysis error:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Batch analysis failed"
      );
    }
  }
);

