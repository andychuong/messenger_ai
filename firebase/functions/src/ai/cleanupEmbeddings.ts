/**
 * Cleanup invalid embeddings from the database
 * Deletes embedding documents that don't have proper embedding vectors
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Cleanup invalid embeddings
 * This removes embedding documents that:
 * - Don't have an 'embedding' field
 * - Have empty embedding arrays
 * - Have wrong dimensions (not 1536)
 */
export const cleanupInvalidEmbeddings = functions.https.onCall(async (data, context) => {
  // Only allow admin users or authenticated users to run cleanup
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  console.log("🧹 Starting embedding cleanup...");

  try {
    const db = admin.firestore();
    const embeddingsRef = db.collection("embeddings");

    // Get all embedding documents (in batches)
    const snapshot = await embeddingsRef.get();

    console.log(`📊 Found ${snapshot.size} embedding documents`);

    let deletedCount = 0;
    let validCount = 0;
    const invalidEmbeddings: string[] = [];

    // Check each embedding
    for (const doc of snapshot.docs) {
      const data = doc.data();

      // Check if embedding is valid
      const isValid =
        data.embedding &&
        Array.isArray(data.embedding) &&
        data.embedding.length === 1536;

      if (!isValid) {
        console.log(
          `❌ Invalid embedding: ${doc.id} (dimensions: ${data.embedding?.length || 0})`
        );
        invalidEmbeddings.push(doc.id);

        // Delete in batches to avoid overwhelming Firestore
        if (invalidEmbeddings.length >= 500) {
          const batch = db.batch();
          invalidEmbeddings.forEach((id) => {
            batch.delete(embeddingsRef.doc(id));
          });
          await batch.commit();
          deletedCount += invalidEmbeddings.length;
          invalidEmbeddings.length = 0; // Clear array
        }
      } else {
        validCount++;
      }
    }

    // Delete remaining invalid embeddings
    if (invalidEmbeddings.length > 0) {
      const batch = db.batch();
      invalidEmbeddings.forEach((id) => {
        batch.delete(embeddingsRef.doc(id));
      });
      await batch.commit();
      deletedCount += invalidEmbeddings.length;
    }

    console.log(`✅ Cleanup complete!`);
    console.log(`   - Valid embeddings: ${validCount}`);
    console.log(`   - Deleted invalid: ${deletedCount}`);

    return {
      success: true,
      totalProcessed: snapshot.size,
      validEmbeddings: validCount,
      deletedInvalid: deletedCount,
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    console.error("Cleanup error:", error);
    throw new functions.https.HttpsError("internal", `Cleanup failed: ${error.message}`);
  }
});

/**
 * Scheduled function to automatically cleanup invalid embeddings daily
 * Runs at 2 AM UTC every day
 */
export const scheduledEmbeddingCleanup = functions.pubsub
  .schedule("0 2 * * *")
  .timeZone("UTC")
  .onRun(async (context) => {
    console.log("🧹 Running scheduled embedding cleanup...");

    try {
      const db = admin.firestore();
      const embeddingsRef = db.collection("embeddings");
      const snapshot = await embeddingsRef.get();

      let deletedCount = 0;

      const batch = db.batch();
      let batchCount = 0;

      for (const doc of snapshot.docs) {
        const data = doc.data();

        const isValid =
          data.embedding &&
          Array.isArray(data.embedding) &&
          data.embedding.length === 1536;

        if (!isValid) {
          batch.delete(doc.ref);
          batchCount++;
          deletedCount++;

          // Commit batch every 500 operations
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      // Commit remaining deletions
      if (batchCount > 0) {
        await batch.commit();
      }

      console.log(`✅ Scheduled cleanup complete: deleted ${deletedCount} invalid embeddings`);
    } catch (error) {
      console.error("Scheduled cleanup error:", error);
    }
  });

