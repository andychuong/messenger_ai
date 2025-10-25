/**
 * Cleanup script to delete invalid embedding documents
 * Run this to remove embedding docs that don't have actual embedding vectors
 */

import * as admin from "firebase-admin";
import * as dotenv from "dotenv";

// Load environment variables
dotenv.config();

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

async function cleanupInvalidEmbeddings() {
  console.log("🧹 Starting embedding cleanup...");
  
  const db = admin.firestore();
  const embeddingsRef = db.collection("embeddings");
  
  // Get all embedding documents
  const snapshot = await embeddingsRef.get();
  
  console.log(`📊 Found ${snapshot.size} embedding documents`);
  
  let deletedCount = 0;
  let validCount = 0;
  
  // Check each embedding
  for (const doc of snapshot.docs) {
    const data = doc.data();
    
    // If it doesn't have an 'embedding' field (the actual vector), delete it
    if (!data.embedding || !Array.isArray(data.embedding)) {
      console.log(`❌ Deleting invalid embedding: ${doc.id} (no embedding vector)`);
      await doc.ref.delete();
      deletedCount++;
    } else {
      console.log(`✅ Valid embedding: ${doc.id}`);
      validCount++;
    }
  }
  
  console.log(`\n✅ Cleanup complete!`);
  console.log(`   - Valid embeddings: ${validCount}`);
  console.log(`   - Deleted invalid: ${deletedCount}`);
  console.log(`\n💡 Now the Firebase trigger will generate proper embeddings for new messages!`);
}

cleanupInvalidEmbeddings()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Error:", error);
    process.exit(1);
  });

