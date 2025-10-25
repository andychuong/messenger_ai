/**
 * Seed test messages with embeddings for testing semantic search
 */

import * as admin from "firebase-admin";
import OpenAI from "openai";
import * as dotenv from "dotenv";

// Load environment variables
dotenv.config();

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const testMessages = [
  "I love pizza and pasta for dinner",
  "Meeting with the team tomorrow at 3pm",
  "The weather is beautiful today, perfect for a walk",
  "Need to buy groceries: milk, eggs, bread, and cheese",
  "Going to the gym later for a workout",
  "Let's watch a movie tonight, maybe a comedy",
  "I'm craving sushi and ramen for lunch",
  "The project deadline is next Friday, we need to hurry",
  "Coffee sounds great right now, maybe a latte",
  "Vacation plans for summer - thinking about the beach",
  "My favorite music is jazz and classical",
  "Doctor appointment scheduled for Monday morning",
  "Birthday party this weekend, don't forget the cake",
  "The new restaurant downtown has amazing tacos",
  "Working from home tomorrow, need to set up the desk",
];

async function seedMessages(userId: string, conversationId: string) {
  console.log("🌱 Starting message seeding...");
  console.log(`👤 User ID: ${userId}`);
  console.log(`💬 Conversation ID: ${conversationId}`);
  
  const db = admin.firestore();
  let successCount = 0;
  let errorCount = 0;

  for (let i = 0; i < testMessages.length; i++) {
    const text = testMessages[i];
    console.log(`\n📝 [${i + 1}/${testMessages.length}] Creating message: "${text}"`);

    try {
      // Create message document
      const messageRef = await db
        .collection("conversations")
        .doc(conversationId)
        .collection("messages")
        .add({
          conversationId,
          senderId: userId,
          senderName: "Test User",
          text,
          timestamp: admin.firestore.Timestamp.now(),
          type: "text",
          status: "sent",
          isEncrypted: false,
        });

      console.log(`   ✅ Message created: ${messageRef.id}`);

      // Generate embedding
      console.log(`   🤖 Generating embedding...`);
      const embeddingResponse = await openai.embeddings.create({
        model: "text-embedding-3-large",
        input: text,
        dimensions: 1536,
      });

      const embedding = embeddingResponse.data[0].embedding;

      // Save embedding
      await db.collection("embeddings").doc(messageRef.id).set({
        conversationId,
        messageId: messageRef.id,
        embedding,
        text,
        senderId: userId,
        timestamp: admin.firestore.Timestamp.now(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`   ✅ Embedding created for ${messageRef.id}`);
      successCount++;

      // Small delay to avoid rate limits
      await new Promise((resolve) => setTimeout(resolve, 500));
    } catch (error) {
      console.error(`   ❌ Error:`, error);
      errorCount++;
    }
  }

  console.log(`\n✅ Seeding complete!`);
  console.log(`   - Success: ${successCount} messages`);
  console.log(`   - Errors: ${errorCount}`);
  console.log(`\n💡 You can now test semantic search with queries like:`);
  console.log(`   - "What food did I mention?"`);
  console.log(`   - "When is my meeting?"`);
  console.log(`   - "What do I need to buy?"`);
  console.log(`   - "Tell me about my plans"`);
}

// Get command line arguments
const userId = process.argv[2];
const conversationId = process.argv[3];

if (!userId || !conversationId) {
  console.error("❌ Usage: npm run seed <userId> <conversationId>");
  console.error("\nExample:");
  console.error("  npm run seed BBBxtZ64PiPtgy7soychLKLviLJ2 s8igHXSa9FiZ2JwRCUpr");
  process.exit(1);
}

seedMessages(userId, conversationId)
  .then(() => {
    console.log("\n🎉 All done!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Fatal error:", error);
    process.exit(1);
  });

