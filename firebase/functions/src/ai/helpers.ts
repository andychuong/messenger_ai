/**
 * AI Assistant Helper Functions
 * 
 * Shared helper functions used across AI features
 */

import * as admin from "firebase-admin";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/**
 * Calculate cosine similarity between two vectors
 */
export function cosineSimilarity(vecA: number[], vecB: number[]): number {
  if (vecA.length !== vecB.length) {
    throw new Error("Vectors must have the same length");
  }

  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }

  normA = Math.sqrt(normA);
  normB = Math.sqrt(normB);

  if (normA === 0 || normB === 0) {
    return 0;
  }

  return dotProduct / (normA * normB);
}

/**
 * Get user names from a list of user IDs
 */
export async function getUserNames(userIds: string[]): Promise<Record<string, string>> {
  const userNames: Record<string, string> = {};
  
  for (const uid of userIds) {
    const userSnap = await admin.firestore().collection("users").doc(uid).get();
    userNames[uid] = userSnap.data()?.displayName || "Unknown";
  }
  
  return userNames;
}

/**
 * Generate embedding for a message (real-time)
 */
export async function generateMessageEmbedding(
  messageId: string,
  conversationId: string,
  text: string,
  senderId: string
) {
  // Generate embedding using OpenAI
  const embeddingResponse = await openai.embeddings.create({
    model: "text-embedding-3-large",
    input: text,
  });

  const embedding = embeddingResponse.data[0].embedding;

  // Store in embeddings collection
  const embeddingRef = admin.firestore().collection("embeddings").doc(messageId);
  
  await embeddingRef.set({
    messageId: messageId,
    conversationId: conversationId,
    senderId: senderId,
    text: text,
    embedding: embedding,
    timestamp: admin.firestore.Timestamp.now(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    embeddingId: embeddingRef.id,
    dimensions: embedding.length,
  };
}

/**
 * Translate text to target language
 */
export async function translateText(
  text: string,
  targetLanguage: string,
  sourceLanguage?: string
) {
  try {
    const sourceInfo = sourceLanguage ? ` from ${sourceLanguage}` : "";
    
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: `You are a professional translator. Translate the given text${sourceInfo} to ${targetLanguage}. 
Provide ONLY the translation, without any explanations or additional text.
Maintain the tone and context of the original message.`,
        },
        {
          role: "user",
          content: text,
        },
      ],
      temperature: 0.3,
      max_tokens: 500,
    });

    const translation = completion.choices[0]?.message?.content || "";

    return {
      translation,
      sourceLanguage: sourceLanguage || "auto-detected",
      targetLanguage,
      originalText: text,
    };
  } catch (error) {
    console.error("Translation error:", error);
    return {
      translation: "",
      error: "Translation failed",
      originalText: text,
    };
  }
}

