/**
 * Embeddings & RAG Functions
 * 
 * Handles vector embeddings for semantic search
 * Uses OpenAI embeddings + Firestore (free, no external vector DB needed)
 * 
 * For MVP: Stores embeddings in Firestore and uses simple similarity search
 * Can be upgraded to Pinecone/Chroma later if needed
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/**
 * Generate embedding for a message
 * Triggered when new message is created
 */
export const generateMessageEmbedding = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const messageId = context.params.messageId;
    const conversationId = context.params.conversationId;
    
    // Skip if no text content
    if (!message.text) {
      console.log("No text content, skipping embedding");
      return null;
    }
    
    try {
      // Generate embedding using OpenAI
      const response = await openai.embeddings.create({
        model: "text-embedding-3-large",
        input: message.text,
        dimensions: 1536,
      });
      
      const embedding = response.data[0].embedding;
      
      // Store embedding in Firestore
      // Alternative: Store in Pinecone for better performance at scale
      await admin.firestore()
        .collection("embeddings")
        .doc(messageId)
        .set({
          conversationId,
          messageId,
          embedding,
          text: message.text,
          senderId: message.senderId,
          timestamp: message.timestamp,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      console.log(`Generated embedding for message ${messageId}`);
      return null;
    } catch (error) {
      console.error("Error generating embedding:", error);
      return null;
    }
  });

/**
 * Semantic search across messages using Firestore
 * Free implementation - no external vector database needed
 */
export const semanticSearch = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { query, conversationId, limit = 10 } = data;
  // userId available for future permission checks
  // const userId = context.auth.uid;
  
  try {
    // Generate query embedding
    const response = await openai.embeddings.create({
      model: "text-embedding-3-large",
      input: query,
      dimensions: 1536,
    });
    
    const queryEmbedding = response.data[0].embedding;
    
    // Fetch embeddings from Firestore
    let embeddingsQuery = admin.firestore()
      .collection("embeddings")
      .limit(100); // Limit to recent messages for performance
    
    // Optionally filter by conversation
    if (conversationId) {
      embeddingsQuery = embeddingsQuery.where("conversationId", "==", conversationId);
    }
    
    const embeddingsSnap = await embeddingsQuery.get();
    
    // Calculate similarity for each embedding
    const results = embeddingsSnap.docs.map((doc) => {
      const data = doc.data();
      const similarity = cosineSimilarity(queryEmbedding, data.embedding);
      return {
        messageId: data.messageId,
        conversationId: data.conversationId,
        text: data.text,
        similarity,
        timestamp: data.timestamp,
      };
    });
    
    // Sort by similarity and return top results
    const topResults = results
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, limit);
    
    return {
      query,
      results: topResults,
      count: topResults.length,
    };
  } catch (error) {
    console.error("Semantic search error:", error);
    throw new functions.https.HttpsError("internal", "Search failed");
  }
});

/**
 * Helper function to calculate cosine similarity
 * Used for vector comparison
 */
function cosineSimilarity(vecA: number[], vecB: number[]): number {
  const dotProduct = vecA.reduce((sum, a, i) => sum + a * vecB[i], 0);
  const magnitudeA = Math.sqrt(vecA.reduce((sum, a) => sum + a * a, 0));
  const magnitudeB = Math.sqrt(vecB.reduce((sum, b) => sum + b * b, 0));
  return dotProduct / (magnitudeA * magnitudeB);
}

