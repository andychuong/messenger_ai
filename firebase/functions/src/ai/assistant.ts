/**
 * AI Assistant Functions
 * 
 * Handles conversation with AI assistant for:
 * - Conversation summarization
 * - Action item extraction
 * - Semantic search
 * - Question answering
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface AssistantRequest {
  query: string;
  conversationId?: string;
  userId: string;
  context?: any;
}

/**
 * Chat with AI assistant
 * Main entry point for all AI assistant interactions
 */
export const chatWithAssistant = functions.https.onCall(async (data: AssistantRequest, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { query, conversationId, userId } = data;
  
  try {
    // Determine intent and route to appropriate function
    const intent = await classifyIntent(query);
    
    switch (intent) {
    case "summarize":
      return await summarizeConversation(conversationId, userId);
    case "action_items":
      return await getActionItems(userId);
    case "search":
      return await semanticSearch(query, userId);
    case "translate":
      return await handleTranslateRequest(query, userId);
    default:
      return await generalAssistant(query, userId);
    }
  } catch (error) {
    console.error("Assistant error:", error);
    throw new functions.https.HttpsError("internal", "Assistant request failed");
  }
});

/**
 * Classify user intent from query
 */
async function classifyIntent(query: string): Promise<string> {
  const lowerQuery = query.toLowerCase();
  
  if (lowerQuery.includes("summarize") || lowerQuery.includes("summary")) {
    return "summarize";
  }
  if (lowerQuery.includes("action item") || lowerQuery.includes("task") || lowerQuery.includes("todo")) {
    return "action_items";
  }
  if (lowerQuery.includes("find") || lowerQuery.includes("search") || lowerQuery.includes("what did")) {
    return "search";
  }
  if (lowerQuery.includes("translate")) {
    return "translate";
  }
  
  return "general";
}

/**
 * Summarize conversation thread
 */
async function summarizeConversation(conversationId: string | undefined, userId: string) {
  if (!conversationId) {
    throw new functions.https.HttpsError("invalid-argument", "Conversation ID required");
  }
  
  // Fetch last 50 messages
  const messagesSnap = await admin.firestore()
    .collection("conversations")
    .doc(conversationId)
    .collection("messages")
    .orderBy("timestamp", "desc")
    .limit(50)
    .get();
  
  const messages = messagesSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })).reverse();
  
  if (messages.length === 0) {
    return {
      response: "No messages found in this conversation.",
      type: "summary",
    };
  }
  
  // Get user names for attribution
  const userIds = [...new Set(messages.map((m: any) => m.senderId))];
  const userNames: Record<string, string> = {};
  
  for (const uid of userIds) {
    const userSnap = await admin.firestore().collection("users").doc(uid).get();
    userNames[uid] = userSnap.data()?.displayName || "Unknown";
  }
  
  // Format messages for GPT
  const formattedMessages = messages.map((m: any) => 
    `${userNames[m.senderId]}: ${m.text}`
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

Format as bullet points with attribution. Be concise but comprehensive.`,
      },
      {
        role: "user",
        content: `Summarize this conversation:\n\n${formattedMessages}`,
      },
    ],
    temperature: 0.5,
    max_tokens: 800,
  });
  
  const summary = completion.choices[0]?.message?.content;
  
  return {
    response: summary,
    type: "summary",
    messageCount: messages.length,
  };
}

/**
 * Get action items for user
 */
async function getActionItems(userId: string) {
  const actionItemsSnap = await admin.firestore()
    .collection("actionItems")
    .where("assignedTo", "==", userId)
    .where("status", "==", "pending")
    .orderBy("dueDate", "asc")
    .limit(20)
    .get();
  
  const actionItems = actionItemsSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));
  
  if (actionItems.length === 0) {
    return {
      response: "You have no pending action items! 🎉",
      type: "action_items",
      items: [],
    };
  }
  
  // Format action items
  const formatted = actionItems.map((item: any, idx: number) => 
    `${idx + 1}. ${item.task}${item.dueDate ? ` (Due: ${new Date(item.dueDate).toLocaleDateString()})` : ""}`
  ).join("\n");
  
  return {
    response: `Here are your pending action items:\n\n${formatted}`,
    type: "action_items",
    items: actionItems,
    count: actionItems.length,
  };
}

/**
 * Semantic search placeholder
 * TODO: Implement with embeddings and vector search
 */
async function semanticSearch(query: string, userId: string) {
  // This will be implemented with embeddings in embeddings.ts
  return {
    response: "Semantic search is coming soon! For now, try using specific keywords.",
    type: "search",
  };
}

/**
 * Handle translation request from assistant
 */
async function handleTranslateRequest(query: string, userId: string) {
  return {
    response: "To translate a message, long-press on it and select 'Translate'.",
    type: "translation_help",
  };
}

/**
 * General assistant for other queries
 */
async function generalAssistant(query: string, userId: string) {
  const completion = await openai.chat.completions.create({
    model: "gpt-4o",
    messages: [
      {
        role: "system",
        content: `You are a helpful AI assistant for a messaging app. You can help users:
- Summarize conversations
- Find action items
- Search past messages
- Answer questions about their chats

Be friendly, concise, and helpful.`,
      },
      {
        role: "user",
        content: query,
      },
    ],
    temperature: 0.7,
    max_tokens: 500,
  });
  
  const response = completion.choices[0]?.message?.content;
  
  return {
    response,
    type: "general",
  };
}

