/**
 * Smart Compose Cloud Function
 * Phase 16: Type-ahead suggestions for message composition
 */

import * as functions from "firebase-functions";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface SmartComposeRequest {
  partialText: string;
  conversationContext: string[];
  language: string;
  tone?: "casual" | "professional" | "friendly" | "formal";
}

interface SmartComposeResponse {
  completion: string;
  fullText: string;
  confidence: number;
  success: boolean;
  error?: string;
}

/**
 * Generate type-ahead completion for partially typed messages
 */
export const generateSmartCompose = functions.https.onCall(
  async (data: SmartComposeRequest, context): Promise<SmartComposeResponse> => {
    try {
      // Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated"
        );
      }

      const { partialText, conversationContext, language, tone = "casual" } = data;

      // Validate required fields
      if (!partialText || partialText.trim().length === 0) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Partial text is required"
        );
      }

      // Don't suggest for very short text (less than 3 words)
      const words = partialText.trim().split(/\s+/);
      if (words.length < 3) {
        return {
          completion: "",
          fullText: partialText,
          confidence: 0,
          success: true,
        };
      }

      // Build context from recent messages
      const contextString = conversationContext && conversationContext.length > 0
        ? `Recent conversation:\n${conversationContext.slice(-5).join("\n")}\n\n`
        : "";

      // Create system prompt for smart compose
      const systemPrompt = `You are an AI writing assistant that completes partially written messages in a messaging app.

Your task:
1. Complete the user's partially written message naturally and contextually
2. Keep completions concise (1-2 sentences max)
3. Match the tone: ${tone}
4. Write in ${language}
5. Consider the conversation context if provided

Rules:
- Only provide the completion, not the original partial text
- Make it sound natural and conversational
- Don't change what the user already wrote
- If the partial text seems complete, return empty completion

Return ONLY the completion text, nothing else.`;

      // Call OpenAI API with streaming disabled for simplicity
      const completion = await openai.chat.completions.create({
        model: "gpt-4o-mini", // Use mini for faster, cheaper completions
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: `${contextString}Partial message: "${partialText}"\n\nComplete this message:` },
        ],
        temperature: 0.5, // Lower temperature for more predictable completions
        max_tokens: 100,
        stop: ["\n", ".", "!", "?"], // Stop at sentence boundaries
      });

      const completionText = completion.choices[0].message.content?.trim() || "";

      // Calculate confidence based on finish reason and text quality
      const confidence = calculateConfidence(
        completion.choices[0].finish_reason || "",
        completionText,
        partialText
      );

      return {
        completion: completionText,
        fullText: partialText + completionText,
        confidence,
        success: true,
      };
    } catch (error: any) {
      console.error("Error generating smart compose:", error);
      
      return {
        completion: "",
        fullText: data.partialText,
        confidence: 0,
        success: false,
        error: error.message || "Failed to generate completion",
      };
    }
  }
);

/**
 * Calculate confidence score for completion
 */
function calculateConfidence(
  finishReason: string,
  completion: string,
  partialText: string
): number {
  let confidence = 0.7; // Base confidence

  // Penalize if finish reason is not "stop"
  if (finishReason !== "stop") {
    confidence -= 0.2;
  }

  // Penalize very short or very long completions
  const completionWords = completion.trim().split(/\s+/).length;
  if (completionWords < 2 || completionWords > 15) {
    confidence -= 0.1;
  }

  // Penalize if completion doesn't start with lowercase (suggests it's not a continuation)
  if (completion.length > 0 && completion[0] === completion[0].toUpperCase()) {
    confidence -= 0.1;
  }

  // Ensure confidence is between 0 and 1
  return Math.max(0, Math.min(1, confidence));
}

/**
 * Streaming version of smart compose (future enhancement)
 * This would allow real-time character-by-character suggestions
 */
export const generateSmartComposeStream = functions.https.onRequest(
  async (request, response) => {
    // Set headers for SSE (Server-Sent Events)
    response.setHeader("Content-Type", "text/event-stream");
    response.setHeader("Cache-Control", "no-cache");
    response.setHeader("Connection", "keep-alive");

    // TODO: Implement streaming with OpenAI streaming API
    // This would require more complex implementation with SSE
    response.write("data: {\"message\": \"Streaming not yet implemented\"}\n\n");
    response.end();
  }
);

