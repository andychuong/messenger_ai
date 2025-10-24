/**
 * Cleanup Script: Remove old conversations and messages
 * 
 * This script helps clean up test data by:
 * 1. Deleting all messages in specified conversations
 * 2. Optionally deleting the conversations themselves
 * 3. Removing old per-user encryption keys
 * 4. Removing embeddings for deleted messages
 * 
 * Usage:
 *   npm run cleanup -- --all                    # Delete all conversations
 *   npm run cleanup -- --conversation <id>      # Delete specific conversation
 *   npm run cleanup -- --user <userId>          # Delete user's conversations
 *   npm run cleanup -- --dry-run                # Preview what would be deleted
 */

import * as admin from "firebase-admin";
import * as path from "path";

// Initialize Firebase Admin
// Try to load service account key, fallback to application default credentials
let credential: admin.credential.Credential;

try {
  const serviceAccountPath = path.join(__dirname, "../../service-account-key.json");
  const serviceAccount = require(serviceAccountPath);
  credential = admin.credential.cert(serviceAccount);
  console.log("✅ Using service account credentials");
} catch (error) {
  // Fallback to application default credentials (works if GOOGLE_APPLICATION_CREDENTIALS is set)
  credential = admin.credential.applicationDefault();
  console.log("✅ Using application default credentials");
}

admin.initializeApp({
  credential: credential,
});

const db = admin.firestore();

interface CleanupOptions {
  all?: boolean;
  conversationId?: string;
  userId?: string;
  dryRun?: boolean;
  keepConversations?: boolean;
}

/**
 * Delete all messages in a conversation
 */
async function deleteConversationMessages(conversationId: string, dryRun: boolean = false): Promise<number> {
  console.log(`\n📋 Processing conversation: ${conversationId}`);
  
  const messagesRef = db.collection("conversations").doc(conversationId).collection("messages");
  const snapshot = await messagesRef.get();
  
  if (snapshot.empty) {
    console.log("  ℹ️  No messages found");
    return 0;
  }
  
  console.log(`  📊 Found ${snapshot.size} messages`);
  
  if (dryRun) {
    console.log("  🔍 DRY RUN - Would delete these messages");
    return snapshot.size;
  }
  
  // Delete in batches of 500
  const batchSize = 500;
  let deletedCount = 0;
  
  while (true) {
    const batch = db.batch();
    const docs = await messagesRef.limit(batchSize).get();
    
    if (docs.empty) break;
    
    docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    deletedCount += docs.size;
    console.log(`  ✅ Deleted ${deletedCount}/${snapshot.size} messages`);
    
    if (docs.size < batchSize) break;
  }
  
  return deletedCount;
}

/**
 * Delete embeddings for a conversation
 */
async function deleteConversationEmbeddings(conversationId: string, dryRun: boolean = false): Promise<number> {
  const embeddingsRef = db.collection("embeddings").where("conversationId", "==", conversationId);
  const snapshot = await embeddingsRef.get();
  
  if (snapshot.empty) {
    console.log("  ℹ️  No embeddings found");
    return 0;
  }
  
  console.log(`  📊 Found ${snapshot.size} embeddings`);
  
  if (dryRun) {
    console.log("  🔍 DRY RUN - Would delete these embeddings");
    return snapshot.size;
  }
  
  const batch = db.batch();
  snapshot.forEach((doc) => {
    batch.delete(doc.ref);
  });
  
  await batch.commit();
  console.log(`  ✅ Deleted ${snapshot.size} embeddings`);
  
  return snapshot.size;
}

/**
 * Delete old per-user encryption keys
 */
async function deletePerUserKeys(conversationId: string, dryRun: boolean = false): Promise<number> {
  const usersSnapshot = await db.collection("users").get();
  let deletedCount = 0;
  
  console.log(`  🔑 Checking per-user encryption keys...`);
  
  for (const userDoc of usersSnapshot.docs) {
    const keyRef = userDoc.ref.collection("encryptionKeys").doc(conversationId);
    const keyDoc = await keyRef.get();
    
    if (keyDoc.exists) {
      if (dryRun) {
        console.log(`  🔍 DRY RUN - Would delete key for user: ${userDoc.id}`);
      } else {
        await keyRef.delete();
        console.log(`  ✅ Deleted per-user key for: ${userDoc.id}`);
      }
      deletedCount++;
    }
  }
  
  if (deletedCount === 0) {
    console.log("  ℹ️  No per-user keys found");
  }
  
  return deletedCount;
}

/**
 * Delete shared encryption key
 */
async function deleteSharedKey(conversationId: string, dryRun: boolean = false): Promise<boolean> {
  const keyRef = db.collection("conversations").doc(conversationId).collection("metadata").doc("encryptionKey");
  const keyDoc = await keyRef.get();
  
  if (!keyDoc.exists) {
    console.log("  ℹ️  No shared encryption key found");
    return false;
  }
  
  if (dryRun) {
    console.log("  🔍 DRY RUN - Would delete shared encryption key");
  } else {
    await keyRef.delete();
    console.log("  ✅ Deleted shared encryption key");
  }
  
  return true;
}

/**
 * Delete the conversation document itself
 */
async function deleteConversation(conversationId: string, dryRun: boolean = false): Promise<boolean> {
  const conversationRef = db.collection("conversations").doc(conversationId);
  const conversationDoc = await conversationRef.get();
  
  if (!conversationDoc.exists) {
    console.log("  ℹ️  Conversation document not found");
    return false;
  }
  
  if (dryRun) {
    console.log("  🔍 DRY RUN - Would delete conversation document");
  } else {
    await conversationRef.delete();
    console.log("  ✅ Deleted conversation document");
  }
  
  return true;
}

/**
 * Clean up a single conversation
 */
async function cleanupConversation(conversationId: string, options: CleanupOptions): Promise<void> {
  console.log(`\n${"=".repeat(60)}`);
  console.log(`🧹 Cleaning up conversation: ${conversationId}`);
  console.log(`${"=".repeat(60)}`);
  
  try {
    // Delete messages
    const messagesDeleted = await deleteConversationMessages(conversationId, options.dryRun);
    
    // Delete embeddings
    const embeddingsDeleted = await deleteConversationEmbeddings(conversationId, options.dryRun);
    
    // Delete encryption keys
    const perUserKeysDeleted = await deletePerUserKeys(conversationId, options.dryRun);
    const sharedKeyDeleted = await deleteSharedKey(conversationId, options.dryRun);
    
    // Delete conversation document (if requested)
    if (!options.keepConversations) {
      await deleteConversation(conversationId, options.dryRun);
    }
    
    console.log(`\n✅ Cleanup complete for ${conversationId}`);
    console.log(`   Messages: ${messagesDeleted}`);
    console.log(`   Embeddings: ${embeddingsDeleted}`);
    console.log(`   Per-user keys: ${perUserKeysDeleted}`);
    console.log(`   Shared key: ${sharedKeyDeleted ? "Yes" : "No"}`);
    console.log(`   Conversation: ${options.keepConversations ? "Kept" : "Deleted"}`);
  } catch (error) {
    console.error(`❌ Error cleaning up conversation ${conversationId}:`, error);
  }
}

/**
 * Get all conversations for a user
 */
async function getUserConversations(userId: string): Promise<string[]> {
  const snapshot = await db.collection("conversations")
    .where("participants", "array-contains", userId)
    .get();
  
  return snapshot.docs.map((doc) => doc.id);
}

/**
 * Get all conversations
 */
async function getAllConversations(): Promise<string[]> {
  const snapshot = await db.collection("conversations").get();
  return snapshot.docs.map((doc) => doc.id);
}

/**
 * Main cleanup function
 */
async function main() {
  const args = process.argv.slice(2);
  
  const options: CleanupOptions = {
    all: args.includes("--all"),
    dryRun: args.includes("--dry-run"),
    keepConversations: args.includes("--keep-conversations"),
  };
  
  // Parse conversation ID
  const conversationIdIndex = args.indexOf("--conversation");
  if (conversationIdIndex !== -1 && args[conversationIdIndex + 1]) {
    options.conversationId = args[conversationIdIndex + 1];
  }
  
  // Parse user ID
  const userIdIndex = args.indexOf("--user");
  if (userIdIndex !== -1 && args[userIdIndex + 1]) {
    options.userId = args[userIdIndex + 1];
  }
  
  console.log("\n🧹 Conversation Cleanup Script");
  console.log("================================\n");
  
  if (options.dryRun) {
    console.log("🔍 DRY RUN MODE - No data will be deleted\n");
  }
  
  let conversationIds: string[] = [];
  
  // Determine which conversations to clean
  if (options.conversationId) {
    conversationIds = [options.conversationId];
    console.log(`📋 Target: Specific conversation (${options.conversationId})`);
  } else if (options.userId) {
    conversationIds = await getUserConversations(options.userId);
    console.log(`📋 Target: User's conversations (${options.userId})`);
    console.log(`   Found ${conversationIds.length} conversations`);
  } else if (options.all) {
    conversationIds = await getAllConversations();
    console.log(`📋 Target: All conversations`);
    console.log(`   Found ${conversationIds.length} conversations`);
  } else {
    console.log("❌ Error: Please specify --all, --conversation <id>, or --user <userId>");
    console.log("\nUsage:");
    console.log("  npm run cleanup -- --all");
    console.log("  npm run cleanup -- --conversation <id>");
    console.log("  npm run cleanup -- --user <userId>");
    console.log("  npm run cleanup -- --all --dry-run");
    console.log("  npm run cleanup -- --all --keep-conversations");
    process.exit(1);
  }
  
  if (conversationIds.length === 0) {
    console.log("\nℹ️  No conversations found to clean up");
    process.exit(0);
  }
  
  // Confirm before proceeding (unless dry run)
  if (!options.dryRun) {
    console.log(`\n⚠️  WARNING: This will delete data from ${conversationIds.length} conversation(s)`);
    console.log("   Press Ctrl+C to cancel, or wait 5 seconds to continue...\n");
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }
  
  // Clean up each conversation
  for (const conversationId of conversationIds) {
    await cleanupConversation(conversationId, options);
  }
  
  console.log(`\n${"=".repeat(60)}`);
  console.log(`✅ Cleanup complete! Processed ${conversationIds.length} conversation(s)`);
  console.log(`${"=".repeat(60)}\n`);
  
  process.exit(0);
}

// Run the script
main().catch((error) => {
  console.error("❌ Fatal error:", error);
  process.exit(1);
});

