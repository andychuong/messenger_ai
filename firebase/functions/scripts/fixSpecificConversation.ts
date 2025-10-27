/**
 * Script to fix a specific corrupted conversation
 * Usage: npx ts-node --transpile-only scripts/fixSpecificConversation.ts <conversationId>
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function fixSpecificConversation(conversationId: string) {
  console.log(`🔍 Checking conversation: ${conversationId}`);

  try {
    const conversationRef = db.collection("conversations").doc(conversationId);
    const conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      console.log(`❌ Conversation not found: ${conversationId}`);
      process.exit(1);
    }

    const data = conversationDoc.data();
    console.log(`\n📄 Current lastMessage:`, data?.lastMessage);
    console.log(`   Type: ${typeof data?.lastMessage}`);

    // Check if lastMessage needs fixing
    if (typeof data?.lastMessage === "string" || !data?.lastMessage) {
      console.log(`\n🔧 Fixing corrupted lastMessage...`);

      // Get the last message from messages subcollection
      const messagesSnapshot = await conversationRef
        .collection("messages")
        .orderBy("timestamp", "desc")
        .limit(1)
        .get();

      let properLastMessage;

      if (!messagesSnapshot.empty) {
        const lastMessageDoc = messagesSnapshot.docs[0];
        const lastMessageData = lastMessageDoc.data();

        properLastMessage = {
          text: lastMessageData.text || "Message",
          senderId: lastMessageData.senderId || "system",
          senderName: lastMessageData.senderName || "System",
          timestamp: lastMessageData.timestamp || admin.firestore.Timestamp.now(),
          type: lastMessageData.type || "text",
        };
      } else {
        // No messages, create default
        properLastMessage = {
          text: "",
          senderId: "system",
          senderName: "System",
          timestamp: admin.firestore.Timestamp.now(),
          type: "text",
        };
      }

      // Update the conversation
      await conversationRef.update({
        lastMessage: properLastMessage,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`\n✅ Fixed! New lastMessage:`);
      console.log(JSON.stringify(properLastMessage, null, 2));
    } else {
      console.log(`\n✅ Conversation is already in correct format`);
    }

  } catch (error) {
    console.error(`❌ Error:`, error);
    process.exit(1);
  }

  process.exit(0);
}

// Get conversation ID from command line args
const conversationId = process.argv[2];

if (!conversationId) {
  console.log("Usage: npx ts-node --transpile-only scripts/fixSpecificConversation.ts <conversationId>");
  console.log("\nOr to fix ALL conversations:");
  console.log("npx ts-node --transpile-only scripts/fixSpecificConversation.ts ALL");
  process.exit(1);
}

if (conversationId === "ALL") {
  // Fix all conversations
  (async () => {
    const conversationsSnapshot = await db.collection("conversations").get();
    console.log(`Found ${conversationsSnapshot.size} conversations\n`);
    
    for (const doc of conversationsSnapshot.docs) {
      await fixSpecificConversation(doc.id);
    }
  })();
} else {
  fixSpecificConversation(conversationId);
}

