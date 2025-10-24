/**
 * AI Assistant Tool Implementations
 * 
 * Actual function implementations for all assistant tools
 */

import * as admin from "firebase-admin";
import OpenAI from "openai";
import { cosineSimilarity, getUserNames, generateMessageEmbedding, translateText } from "./helpers";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

/**
 * Summarize conversation thread
 */
export async function summarizeConversation(
  conversationId: string,
  userId: string,
  messageCount: number = 50
) {
  // Fetch recent messages
  const messagesSnap = await admin.firestore()
    .collection("conversations")
    .doc(conversationId)
    .collection("messages")
    .orderBy("timestamp", "desc")
    .limit(messageCount)
    .get();
  
  const messages = messagesSnap.docs.map((doc: admin.firestore.QueryDocumentSnapshot) => ({
    id: doc.id,
    ...doc.data(),
  })).reverse();
  
  if (messages.length === 0) {
    return {
      summary: "No messages found in this conversation.",
      messageCount: 0,
      keyPoints: [],
    };
  }
  
  // Get user names for attribution
  const userIds = [...new Set(messages.map((m: any) => m.senderId))] as string[];
  const userNames = await getUserNames(userIds);
  
  // Format messages for GPT
  const formattedMessages = messages.map((m: any) => 
    `${userNames[m.senderId]}: ${m.text || "[media]"}`
  ).join("\n");
  
  // Generate summary with GPT-4o
  const completion = await openai.chat.completions.create({
    model: "gpt-4o",
    messages: [
      {
        role: "system",
        content: `You are summarizing a conversation. Focus on:
- Key decisions made
- Action items assigned
- Important questions raised
- Main discussion points
- Outcomes or conclusions

Format as structured bullet points. Be concise but comprehensive.`,
      },
      {
        role: "user",
        content: `Summarize this conversation (${messages.length} messages):\n\n${formattedMessages}`,
      },
    ],
    temperature: 0.5,
    max_tokens: 1000,
  });
  
  const summary = completion.choices[0]?.message?.content || "";
  
  const firstMsg = messages[0] as any;
  const lastMsg = messages[messages.length - 1] as any;
  
  return {
    summary,
    messageCount: messages.length,
    participants: Object.values(userNames),
    timeRange: {
      start: firstMsg?.timestamp,
      end: lastMsg?.timestamp,
    },
  };
}

/**
 * Get action items for user with filtering
 */
export async function getActionItems(
  userId: string,
  status: string = "pending",
  conversationId?: string
) {
  let query: FirebaseFirestore.Query = admin.firestore().collection("actionItems");

  // Filter by assignee or creator
  query = query.where("assignedTo", "==", userId);

  // Filter by status
  if (status !== "all") {
    query = query.where("status", "==", status);
  }

  // Filter by conversation
  if (conversationId) {
    query = query.where("conversationId", "==", conversationId);
  }

  const actionItemsSnap = await query
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();
  
  const actionItems = actionItemsSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));
  
  return {
    items: actionItems,
    count: actionItems.length,
    status,
  };
}

/**
 * Semantic search using embeddings
 */
export async function semanticSearch(
  query: string,
  userId: string,
  conversationId?: string,
  limit: number = 10
) {
  try {
    // Generate embedding for query
    const embeddingResponse = await openai.embeddings.create({
      model: "text-embedding-3-large",
      input: query,
    });

    const queryEmbedding = embeddingResponse.data[0].embedding;

    // Get embeddings from Firestore
    let embeddingsQuery: FirebaseFirestore.Query = admin.firestore().collection("embeddings");

    // Filter by conversation if specified
    if (conversationId) {
      embeddingsQuery = embeddingsQuery.where("conversationId", "==", conversationId);
    }

    const embeddingsSnap = await embeddingsQuery.limit(500).get();

    // Calculate cosine similarity
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
    results.sort((a, b) => b.similarity - a.similarity);
    const topResults = results.slice(0, limit);

    return {
      results: topResults,
      count: topResults.length,
      query,
    };
  } catch (error) {
    console.error("Semantic search error:", error);
    return {
      results: [],
      count: 0,
      query,
      error: "Search failed",
    };
  }
}

/**
 * Get decisions from conversations
 */
export async function getDecisions(
  userId: string,
  conversationId?: string,
  limit: number = 10
) {
  let query: FirebaseFirestore.Query = admin.firestore().collection("decisions");

  // Filter by conversation if specified
  if (conversationId) {
    query = query.where("conversationId", "==", conversationId);
  }

  const decisionsSnap = await query
    .orderBy("createdAt", "desc")
    .limit(limit)
    .get();

  const decisions = decisionsSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  return {
    decisions,
    count: decisions.length,
  };
}

/**
 * Get high-priority unread messages
 */
export async function getPriorityMessages(
  userId: string,
  limit: number = 20
) {
  // Get user's conversations
  const conversationsSnap = await admin.firestore()
    .collection("conversations")
    .where("participants", "array-contains", userId)
    .get();

  const priorityMessages: any[] = [];

  // Check each conversation for priority messages
  for (const convDoc of conversationsSnap.docs) {
    const messagesSnap = await convDoc.ref
      .collection("messages")
      .where("priority", "==", "high")
      .orderBy("timestamp", "desc")
      .limit(5)
      .get();

    messagesSnap.docs.forEach((msgDoc) => {
      const data = msgDoc.data();
      // Only include unread messages
      const readBy = data.readBy || [];
      if (!readBy.some((r: any) => r.userId === userId)) {
        priorityMessages.push({
          messageId: msgDoc.id,
          conversationId: convDoc.id,
          text: data.text,
          senderId: data.senderId,
          timestamp: data.timestamp,
        });
      }
    });
  }

  // Sort by timestamp and limit
  priorityMessages.sort((a, b) => b.timestamp - a.timestamp);
  const topMessages = priorityMessages.slice(0, limit);

  return {
    messages: topMessages,
    count: topMessages.length,
  };
}

/**
 * Get recent messages from a conversation
 */
export async function getRecentMessages(
  conversationId: string,
  userId: string,
  limit: number = 5
) {
  try {
    console.log(`Fetching recent messages for conversation: ${conversationId}, user: ${userId}`);
    
    // Fetch from embeddings collection (has unencrypted text for AI)
    const embeddingsSnap = await admin.firestore()
      .collection("embeddings")
      .where("conversationId", "==", conversationId)
      .orderBy("timestamp", "desc")
      .limit(limit * 2)
      .get();

    console.log(`Found ${embeddingsSnap.size} embeddings`);

    if (embeddingsSnap.empty) {
      return {
        messages: [],
        count: 0,
        note: "No messages with AI access found. Please send a new message from the updated app.",
      };
    }

    // Map embeddings (which have unencrypted text)
    const messages = embeddingsSnap.docs
      .map((doc) => {
        const data = doc.data();
        return {
          messageId: data.messageId,
          text: data.text,
          senderId: data.senderId,
          timestamp: data.timestamp,
        };
      })
      .reverse(); // Chronological order

    // Get user names
    const userIds = [...new Set(messages.map((m: any) => m.senderId))];
    const userNames = await getUserNames(userIds);

    // Filter for user's messages only
    const userMessages = messages
      .filter((m: any) => m.senderId === userId)
      .slice(0, limit)
      .map((m: any) => ({
        text: m.text || "[media]",
        sender: userNames[m.senderId],
        isFromCurrentUser: true,
        timestamp: m.timestamp,
      }));

    console.log(`Found ${userMessages.length} messages from user ${userId}`);

    return {
      messages: userMessages,
      count: userMessages.length,
      conversationId,
    };
  } catch (error) {
    console.error("Error fetching recent messages:", error);
    return {
      messages: [],
      count: 0,
      error: "Failed to fetch messages",
    };
  }
}

/**
 * Send a message to a conversation
 */
export async function sendMessage(
  conversationId: string,
  userId: string,
  text: string,
  generateEmbedding: boolean = true
) {
  try {
    console.log(`Sending message to conversation ${conversationId} from user ${userId}`);

    // Get user info
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const userName = userDoc.data()?.displayName || "Unknown";

    // Create message document
    const messageRef = admin.firestore()
      .collection("conversations")
      .doc(conversationId)
      .collection("messages")
      .doc();

    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    const messageData = {
      conversationId: conversationId,
      senderId: userId,
      senderName: userName,
      text: text,
      timestamp: timestamp,
      status: "sent",
      type: "text",
      readBy: [],
      deliveredTo: [],
      reactions: {},
      createdAt: timestamp,
      isEncrypted: false,  // AI-sent messages are not encrypted
    };

    // Save message
    await messageRef.set(messageData);

    // Update conversation's last message
    await admin.firestore()
      .collection("conversations")
      .doc(conversationId)
      .update({
        lastMessage: {
          text: text,
          senderId: userId,
          timestamp: timestamp,
        },
        lastMessageTime: timestamp,
        updatedAt: timestamp,
      });

    console.log(`Message sent successfully: ${messageRef.id}`);

    // Generate embedding immediately if requested
    if (generateEmbedding) {
      console.log("Generating embedding in real-time...");
      
      try {
        const embeddingResult = await generateMessageEmbedding(
          messageRef.id,
          conversationId,
          text,
          userId
        );
        
        console.log("Real-time embedding generated successfully");
        
        return {
          success: true,
          messageId: messageRef.id,
          text: text,
          sender: userName,
          embeddingGenerated: true,
          embeddingId: embeddingResult.embeddingId,
          note: "Message sent and immediately indexed for AI access",
        };
      } catch (embeddingError) {
        console.error("Error generating embedding:", embeddingError);
        return {
          success: true,
          messageId: messageRef.id,
          text: text,
          sender: userName,
          embeddingGenerated: false,
          note: "Message sent but embedding generation failed. Message may not be immediately searchable.",
        };
      }
    }

    return {
      success: true,
      messageId: messageRef.id,
      text: text,
      sender: userName,
      embeddingGenerated: false,
    };
  } catch (error) {
    console.error("Error sending message:", error);
    return {
      success: false,
      error: "Failed to send message",
    };
  }
}

export { translateText };

