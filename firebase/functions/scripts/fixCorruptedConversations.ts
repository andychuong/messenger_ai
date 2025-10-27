/**
 * Script to fix corrupted conversation documents
 * 
 * Issue: lastMessage was incorrectly set as a string instead of an object
 * This script finds and fixes those conversations
 * 
 * Usage: npx ts-node scripts/fixCorruptedConversations.ts
 */

import * as admin from "firebase-admin";

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function fixCorruptedConversations() {
  console.log("🔍 Searching for corrupted conversations...");

  try {
    // Get all conversations
    const conversationsSnapshot = await db.collection("conversations").get();
    let fixedCount = 0;
    let errorCount = 0;

    for (const doc of conversationsSnapshot.docs) {
      const data = doc.data();
      const conversationId = doc.id;

      // Check if lastMessage is a string (corrupted)
      if (typeof data.lastMessage === "string") {
        console.log(`\n🔧 Found corrupted conversation: ${conversationId}`);
        console.log(`   Corrupted lastMessage: "${data.lastMessage}"`);

        try {
          // Try to get the actual last message from the messages subcollection
          const messagesSnapshot = await db
            .collection("conversations")
            .doc(conversationId)
            .collection("messages")
            .orderBy("timestamp", "desc")
            .limit(1)
            .get();

          if (!messagesSnapshot.empty) {
            const lastMessageDoc = messagesSnapshot.docs[0];
            const lastMessageData = lastMessageDoc.data();

            // Create proper lastMessage object
            const properLastMessage = {
              text: lastMessageData.text || data.lastMessage || "",
              senderId: lastMessageData.senderId || "system",
              senderName: lastMessageData.senderName || "System",
              timestamp: lastMessageData.timestamp || admin.firestore.Timestamp.now(),
              type: lastMessageData.type || "text",
            };

            // Update the conversation
            await db.collection("conversations").doc(conversationId).update({
              lastMessage: properLastMessage,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`   ✅ Fixed! New lastMessage:`);
            console.log(`      Text: ${properLastMessage.text}`);
            console.log(`      Sender: ${properLastMessage.senderName}`);
            console.log(`      Type: ${properLastMessage.type}`);

            fixedCount++;
          } else {
            // No messages found, create a system message
            console.log(`   ⚠️  No messages found for this conversation`);
            
            await db.collection("conversations").doc(conversationId).update({
              lastMessage: {
                text: "No messages yet",
                senderId: "system",
                senderName: "System",
                timestamp: admin.firestore.Timestamp.now(),
                type: "system",
              },
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`   ✅ Fixed with default message`);
            fixedCount++;
          }
        } catch (error) {
          console.error(`   ❌ Error fixing conversation ${conversationId}:`, error);
          errorCount++;
        }
      }
    }

    console.log("\n" + "=".repeat(60));
    console.log(`✅ Completed! Fixed ${fixedCount} conversation(s)`);
    if (errorCount > 0) {
      console.log(`❌ Errors: ${errorCount} conversation(s) could not be fixed`);
    }
    console.log("=".repeat(60));

  } catch (error) {
    console.error("❌ Error running script:", error);
    process.exit(1);
  }

  process.exit(0);
}

// Run the script
fixCorruptedConversations();

