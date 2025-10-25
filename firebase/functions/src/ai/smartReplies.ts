/**
 * Smart Replies Cloud Function
 * Phase 16: Generate context-aware smart reply suggestions
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface SmartRepliesRequest {
  conversationId: string;
  recentMessages: Array<{
    senderId: string;
    senderName?: string;
    text: string;
    timestamp: any;
  }>;
  userLanguage: string;
  recipientInfo?: {
    relationship: "friend" | "colleague" | "family" | "customer";
    formalityPreference?: string;
  };
  currentUserId: string;
}

interface SmartReply {
  text: string;
  tone: "friendly" | "professional" | "casual" | "formal";
  reasoning?: string;
  confidence: number;
}

interface SmartRepliesResponse {
  suggestions: SmartReply[];
  contextSummary?: string;
  success: boolean;
  error?: string;
}

/**
 * Generate smart reply suggestions based on conversation context
 */
export const generateSmartReplies = functions.https.onCall(
  async (data: SmartRepliesRequest, context): Promise<SmartRepliesResponse> => {
    try {
      // Validate authentication
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "User must be authenticated"
        );
      }

      const {
        conversationId,
        recentMessages,
        userLanguage,
        recipientInfo,
        currentUserId,
      } = data;

      // Validate required fields
      if (!conversationId || !recentMessages || !userLanguage) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required fields"
        );
      }

      // Build conversation context
      const conversationContext = recentMessages
        .map((msg) => {
          const sender = msg.senderId === currentUserId ? "You" : msg.senderName || "Other";
          return `${sender}: ${msg.text}`;
        })
        .join("\n");

      // Determine relationship context
      const relationship = recipientInfo?.relationship || "friend";
      const formalityGuide = getformalityGuide(relationship);

      // Create system prompt for smart replies
      const systemPrompt = `You are an AI assistant that generates contextually appropriate reply suggestions for a messaging app.

Your task is to analyze the recent conversation and generate 3-5 smart reply suggestions that:
1. Are contextually relevant to the last message
2. Match the tone and formality of the conversation
3. Are in ${userLanguage}
4. Are concise (1-2 sentences max)
5. Are diverse in tone and intent
6. ${formalityGuide}

Relationship context: ${relationship}

Return a JSON object with this structure:
{
  "suggestions": [
    {
      "text": "The reply text",
      "tone": "friendly" | "professional" | "casual" | "formal",
      "reasoning": "Brief explanation why this reply is appropriate",
      "confidence": 0.0-1.0
    }
  ],
  "contextSummary": "Brief summary of what the conversation is about"
}`;

      // Call OpenAI API
      const completion = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: `Conversation:\n${conversationContext}\n\nGenerate smart reply suggestions.` },
        ],
        response_format: { type: "json_object" },
        temperature: 0.7,
        max_tokens: 1000,
      });

      const responseText = completion.choices[0].message.content;
      if (!responseText) {
        throw new Error("Empty response from OpenAI");
      }

      const result = JSON.parse(responseText);

      // Validate response structure
      if (!result.suggestions || !Array.isArray(result.suggestions)) {
        throw new Error("Invalid response structure from OpenAI");
      }

      // Cache the results in Firestore for potential reuse
      await admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .collection("smartReplies")
        .doc(currentUserId)
        .set({
          suggestions: result.suggestions,
          contextSummary: result.contextSummary,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 5 * 60 * 1000) // Cache for 5 minutes
          ),
        });

      return {
        suggestions: result.suggestions,
        contextSummary: result.contextSummary,
        success: true,
      };
    } catch (error: any) {
      console.error("Error generating smart replies:", error);
      
      // Return fallback suggestions on error
      const fallbackSuggestions = getFallbackSuggestions(data.userLanguage);
      
      return {
        suggestions: fallbackSuggestions,
        success: false,
        error: error.message || "Failed to generate smart replies",
      };
    }
  }
);

/**
 * Get formality guide based on relationship
 */
function getformalityGuide(relationship: string): string {
  const guides: Record<string, string> = {
    friend: "Keep replies casual and friendly",
    colleague: "Maintain professional but approachable tone",
    family: "Be warm and personal",
    customer: "Be professional, courteous, and solution-oriented",
  };
  return guides[relationship] || guides.friend;
}

/**
 * Get fallback suggestions when AI fails
 */
function getFallbackSuggestions(language: string): SmartReply[] {
  const fallbacks: Record<string, SmartReply[]> = {
    English: [
      { text: "Thanks!", tone: "casual", confidence: 0.5 },
      { text: "Sounds good!", tone: "friendly", confidence: 0.5 },
      { text: "I'll get back to you soon.", tone: "professional", confidence: 0.5 },
    ],
    Spanish: [
      { text: "¡Gracias!", tone: "casual", confidence: 0.5 },
      { text: "¡Suena bien!", tone: "friendly", confidence: 0.5 },
      { text: "Te responderé pronto.", tone: "professional", confidence: 0.5 },
    ],
    French: [
      { text: "Merci!", tone: "casual", confidence: 0.5 },
      { text: "Ça a l'air bien!", tone: "friendly", confidence: 0.5 },
      { text: "Je vous répondrai bientôt.", tone: "professional", confidence: 0.5 },
    ],
  };

  return fallbacks[language] || fallbacks.English;
}

