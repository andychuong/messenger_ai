/**
 * Translation Functions
 * 
 * AI-powered message translation using OpenAI GPT-4o
 * Supports context-aware translation with caching
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/**
 * Extract emojis from text
 * Returns object with text without emojis and the extracted emojis
 */
function extractEmojis(text: string): { textWithoutEmojis: string; emojis: string[] } {
  // Regex to match emojis (covers most common emoji ranges)
  const emojiRegex = /[\u{1F300}-\u{1F9FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F900}-\u{1F9FF}\u{1F1E0}-\u{1F1FF}\u{1FA70}-\u{1FAFF}]/gu;
  
  const emojis: string[] = [];
  const textWithoutEmojis = text.replace(emojiRegex, (match) => {
    emojis.push(match);
    return "";
  }).trim();
  
  return { textWithoutEmojis, emojis };
}

/**
 * Add emojis back to translated text
 */
function addEmojisToText(text: string, emojis: string[]): string {
  if (emojis.length === 0) {
    return text;
  }
  // Add emojis at the end with a space
  return `${text} ${emojis.join("")}`;
}

interface TranslationRequest {
  messageId: string;
  conversationId: string;
  targetLanguage: string;
  userId: string;
  text?: string; // Optional: pass decrypted text directly (for encrypted messages)
}

/**
 * Translate a message to target language
 * Uses GPT-4o for context-aware translation
 */
export const translateMessage = functions.https.onCall(async (data: TranslationRequest, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to translate messages"
    );
  }
  
  const { messageId, conversationId, targetLanguage, text } = data;
  
  // Phase 9.5 Redesign: Per-message encryption
  // Translation works for all messages, but only unencrypted messages have embeddings
  // Encrypted messages can still be translated if the client passes the decrypted text
  
  try {
    let originalText: string;
    let messageRef;
    
    // If text is provided (decrypted), use it directly
    if (text) {
      originalText = text;
      messageRef = admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .collection("messages")
        .doc(messageId);
    } else {
      // Otherwise, fetch from Firestore (for non-encrypted messages)
      messageRef = admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .collection("messages")
        .doc(messageId);
      
      const messageSnap = await messageRef.get();
      
      if (!messageSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Message not found");
      }
      
      const message = messageSnap.data();
      originalText = message?.text;
      
      if (!originalText) {
        throw new functions.https.HttpsError("invalid-argument", "Message has no text");
      }
    }
    
    // Check if translation already cached in Firestore
    const messageSnap = await messageRef.get();
    const message = messageSnap.data();
    
    // Check if translation already cached
    const cachedTranslation = message?.translations?.[targetLanguage];
    if (cachedTranslation) {
      console.log("Returning cached translation");
      return {
        originalText,
        translatedText: cachedTranslation,
        targetLanguage,
        fromCache: true,
      };
    }
    
    // Extract emojis from text before translation
    const { textWithoutEmojis, emojis } = extractEmojis(originalText);
    
    // Translate using GPT-4o (without emojis)
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: `You are a professional translator. Translate the following message to ${targetLanguage}. 
Maintain the tone and style. Only return the translated text, nothing else. Do not include any emojis in your response.`,
        },
        {
          role: "user",
          content: textWithoutEmojis,
        },
      ],
      temperature: 0.3,
      max_tokens: 1000,
    });
    
    let translatedText = completion.choices[0]?.message?.content?.trim();
    
    if (!translatedText) {
      throw new functions.https.HttpsError("internal", "Translation failed");
    }
    
    // Remove any emojis that GPT might have added (we only want the original ones)
    const cleanedTranslation = extractEmojis(translatedText).textWithoutEmojis;
    
    // Add back ONLY the original emojis from the source text
    translatedText = addEmojisToText(cleanedTranslation, emojis);
    
    // Cache the translation
    await messageRef.update({
      [`translations.${targetLanguage}`]: translatedText,
    });
    
    console.log(`Translated message ${messageId} to ${targetLanguage}`);
    
    return {
      originalText,
      translatedText,
      targetLanguage,
      fromCache: false,
    };
  } catch (error) {
    console.error("Translation error:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError("internal", "Failed to translate message");
  }
});

/**
 * Translate text directly without storing to database
 * Used for pre-send translation (hold send button feature)
 */
export const translateText = functions.https.onCall(async (data: { text: string; targetLanguage: string }, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated to translate text"
    );
  }
  
  const { text, targetLanguage } = data;
  
  if (!text || !targetLanguage) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Text and target language are required"
    );
  }
  
  try {
    console.log(`Translating text to ${targetLanguage}`);
    
    // Extract emojis from text before translation
    const { textWithoutEmojis, emojis } = extractEmojis(text);
    
    // Translate using GPT-4o (without emojis)
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: `You are a professional translator. Translate the following message to ${targetLanguage}. 
Maintain the tone and style. Only return the translated text, nothing else. Do not include any emojis in your response.`,
        },
        {
          role: "user",
          content: textWithoutEmojis,
        },
      ],
      temperature: 0.3,
      max_tokens: 1000,
    });
    
    let translatedText = completion.choices[0]?.message?.content?.trim();
    
    if (!translatedText) {
      throw new functions.https.HttpsError("internal", "Translation failed");
    }
    
    // Remove any emojis that GPT might have added (we only want the original ones)
    const cleanedTranslation = extractEmojis(translatedText).textWithoutEmojis;
    
    // Add back ONLY the original emojis from the source text
    translatedText = addEmojisToText(cleanedTranslation, emojis);
    
    console.log(`Successfully translated text to ${targetLanguage}`);
    
    return {
      originalText: text,
      translatedText,
      targetLanguage,
      fromCache: false,
    };
  } catch (error) {
    console.error("Translation error:", error);
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError("internal", "Failed to translate text");
  }
});

/**
 * Batch translate multiple messages
 * Useful for translating entire conversations
 */
export const batchTranslate = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { messageIds, conversationId, targetLanguage } = data;
  
  if (!Array.isArray(messageIds) || messageIds.length === 0) {
    throw new functions.https.HttpsError("invalid-argument", "messageIds must be a non-empty array");
  }
  
  if (messageIds.length > 50) {
    throw new functions.https.HttpsError("invalid-argument", "Maximum 50 messages per batch");
  }
  
  try {
    const translations: any[] = [];
    
    // Process each message
    for (const messageId of messageIds) {
      try {
        const result = await translateMessage.run({
          messageId,
          conversationId,
          targetLanguage,
        }, context as any);
        
        translations.push({
          messageId,
          success: true,
          ...result,
        });
      } catch (error) {
        console.error(`Failed to translate message ${messageId}:`, error);
        translations.push({
          messageId,
          success: false,
          error: "Translation failed",
        });
      }
    }
    
    return {
      translations,
      totalProcessed: translations.length,
      successCount: translations.filter((t) => t.success).length,
    };
  } catch (error) {
    console.error("Batch translation error:", error);
    throw new functions.https.HttpsError("internal", "Batch translation failed");
  }
});

