/**
 * Debug function to check database state
 * Useful for monitoring system health
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

export const debugDatabase = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const userId = context.auth.uid;

  try {
    // Check conversations
    const userConvsSnap = await admin.firestore()
      .collection("conversations")
      .where("participants", "array-contains", userId)
      .get();

    const conversations = userConvsSnap.docs.map((doc) => ({
      id: doc.id,
      type: doc.data().type,
      participants: doc.data().participants,
      participantCount: doc.data().participants?.length || 0,
    }));

    // Check embeddings
    const embeddingsSnap = await admin.firestore()
      .collection("embeddings")
      .limit(100)
      .get();

    const validEmbeddings = embeddingsSnap.docs.filter((doc) => {
      const data = doc.data();
      return data.embedding && 
             Array.isArray(data.embedding) && 
             data.embedding.length === 1536;
    });

    const invalidEmbeddings = embeddingsSnap.docs.filter((doc) => {
      const data = doc.data();
      return !data.embedding || 
             !Array.isArray(data.embedding) || 
             data.embedding.length !== 1536;
    });

    return {
      userId,
      conversations: {
        count: conversations.length,
        ids: conversations.map((c) => c.id),
      },
      embeddings: {
        total: embeddingsSnap.size,
        valid: validEmbeddings.length,
        invalid: invalidEmbeddings.length,
      },
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    console.error("Debug error:", error);
    throw new functions.https.HttpsError("internal", `Debug failed: ${error.message}`);
  }
});

