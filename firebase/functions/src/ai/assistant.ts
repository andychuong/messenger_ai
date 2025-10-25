/**
 * AI Assistant Functions
 * 
 * Main entry point for conversation with AI assistant
 * Handles multi-turn conversations with GPT-4o function calling
 */

import * as functions from "firebase-functions";
import OpenAI from "openai";
import { assistantTools } from "./tools";
import {
  summarizeConversation,
  getActionItems,
  semanticSearch,
  getDecisions,
  getPriorityMessages,
  getRecentMessages,
  sendMessage,
  translateText,
} from "./toolImplementations";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface AssistantRequest {
  query: string;
  conversationId?: string;
  userId: string;
  conversationHistory?: ConversationMessage[];
  context?: any;
}

interface ConversationMessage {
  role: "user" | "assistant" | "system";
  content: string;
  timestamp?: number;
}

/**
 * Phase 9.5 Redesign: Check if conversation has encrypted messages
 */
async function checkForEncryptedMessages(conversationId: string): Promise<boolean> {
  const admin = await import("firebase-admin");
  
  // Check last 10 messages for encrypted ones
  const messagesSnapshot = await admin.firestore()
    .collection("conversations")
    .doc(conversationId)
    .collection("messages")
    .orderBy("timestamp", "desc")
    .limit(10)
    .get();
  
  // Check if any recent messages are encrypted (isEncrypted = true or null/undefined for backward compatibility)
  for (const doc of messagesSnapshot.docs) {
    const data = doc.data();
    const isEncrypted = data.isEncrypted ?? true; // Default to true for backward compatibility
    if (isEncrypted) {
      return true; // Found at least one encrypted message
    }
  }
  
  return false;
}

/**
 * Chat with AI assistant using GPT-4o with function calling
 * Main entry point for all AI assistant interactions
 */
export const chatWithAssistant = functions.https.onCall(async (data: AssistantRequest, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { query, conversationId, userId, conversationHistory = [] } = data;
  
  // Phase 9.5 Redesign: Per-message encryption
  // AI Assistant now works with all conversations, but only processes unencrypted messages
  // (Messages without embeddings are automatically excluded from search results)
  
  try {
    // Check if recent messages are encrypted and inform user
    let encryptionNotice = "";
    if (conversationId) {
      const hasEncryptedMessages = await checkForEncryptedMessages(conversationId);
      if (hasEncryptedMessages) {
        encryptionNotice = "\n\nIMPORTANT: Some recent messages in this conversation are encrypted (🔒) and cannot be accessed by AI. Only unencrypted messages (🔓 AI-enhanced) are available for search, translation, and analysis. If the user asks about recent messages, inform them that encrypted messages are not visible to you.";
      }
    }
    
    // Build messages array with conversation history
    const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
      {
        role: "system",
        content: getSystemPrompt(userId, conversationId) + encryptionNotice,
      },
      // Add conversation history
      ...conversationHistory.map((msg) => ({
        role: msg.role,
        content: msg.content,
      })),
      // Add current user query
      {
        role: "user" as const,
        content: query,
      },
    ];

    // Call GPT-4o with function calling
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages,
      tools: assistantTools,
      tool_choice: "auto",
      temperature: 0.7,
      max_tokens: 1500,
    });

    const response = completion.choices[0]?.message;

    // Handle multi-turn tool calling
    const { finalResponse, toolsUsed } = await handleToolCalls(
      response,
      messages,
      userId,
      conversationId
    );

    return {
      response: finalResponse || "I processed your request but don't have additional information to share.",
      toolsUsed,
      timestamp: Date.now(),
    };
  } catch (error) {
    console.error("Assistant error:", error);
    throw new functions.https.HttpsError("internal", "Assistant request failed");
  }
});

/**
 * Get system prompt for the assistant
 */
function getSystemPrompt(userId: string, conversationId?: string): string {
  return `You are a helpful AI assistant for a messaging app. You have access to:
- Conversation summaries
- Action item tracking
- Semantic search across message history (global or per-conversation)
- Decision logs
- Priority message detection
- Message translation
- Recent message retrieval
- Sending messages to conversations

When users ask questions:
1. Use the appropriate tool if needed
2. Provide clear, concise answers
3. Cite sources when referencing specific messages
4. Be friendly and conversational

Search behavior:
- For questions like "who did I say hello to" or "what did I talk about yesterday", use search_messages WITHOUT a conversationId to search across ALL conversations
- Only specify conversationId if the user explicitly asks about a specific conversation or if you're already in a conversation context
- The search_messages tool can search globally - use it proactively for questions about past messages

Special handling for translations:
- When asked to "translate and send" or "send in [language]":
  1. Use get_recent_messages to fetch their last message (requires conversationId)
  2. Use translate_text to translate it
  3. Use send_message to send the translation to the conversation
- If they just ask to translate (without sending), only provide the translation
- Always confirm after sending a message

Current user ID: ${userId}
${conversationId ? `Current conversation ID: ${conversationId}` : "Global assistant mode - can search across all user's conversations"}`;
}

/**
 * Handle multi-turn tool calling until GPT provides a final response
 */
async function handleToolCalls(
  response: OpenAI.Chat.ChatCompletionMessage | undefined,
  messages: OpenAI.Chat.ChatCompletionMessageParam[],
  userId: string,
  conversationId?: string
): Promise<{ finalResponse: string; toolsUsed: string[] }> {
  let currentMessages = [...messages];
  let allToolsUsed: string[] = [];
  let currentResponse = response;
  const maxIterations = 10; // Prevent infinite loops
  let iteration = 0;

  while (currentResponse?.tool_calls && currentResponse.tool_calls.length > 0 && iteration < maxIterations) {
    iteration++;
    
    // Execute all tool calls
    const toolResults = await Promise.all(
      currentResponse.tool_calls.map(async (toolCall) => {
        const functionName = toolCall.function.name;
        const functionArgs = JSON.parse(toolCall.function.arguments);

        console.log(`[Iteration ${iteration}] Executing tool: ${functionName}`, functionArgs);
        allToolsUsed.push(functionName);

        const result = await executeToolCall(functionName, functionArgs, userId, conversationId);

        return {
          tool_call_id: toolCall.id,
          role: "tool" as const,
          content: JSON.stringify(result),
        };
      })
    );

    // Add tool calls and results to message history
    currentMessages = [
      ...currentMessages,
      currentResponse,
      ...toolResults,
    ];

    // Call GPT again with tool results
    const nextCompletion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: currentMessages,
      tools: assistantTools,
      tool_choice: "auto",
      temperature: 0.7,
      max_tokens: 1500,
    });

    currentResponse = nextCompletion.choices[0]?.message;
  }

  const finalContent = currentResponse?.content?.trim() || "";
  
  return {
    finalResponse: finalContent,
    toolsUsed: allToolsUsed,
  };
}

/**
 * Execute a single tool call
 */
async function executeToolCall(
  functionName: string,
  functionArgs: any,
  userId: string,
  conversationId?: string
): Promise<any> {
  switch (functionName) {
  case "summarize_conversation":
    return await summarizeConversation(
      functionArgs.conversationId,
      userId,
      functionArgs.messageCount
    );
  case "get_action_items":
    return await getActionItems(
      userId,
      functionArgs.status,
      functionArgs.conversationId
    );
  case "search_messages":
    return await semanticSearch(
      functionArgs.query,
      userId,
      functionArgs.conversationId,
      functionArgs.limit
    );
  case "get_decisions":
    return await getDecisions(
      userId,
      functionArgs.conversationId,
      functionArgs.limit
    );
  case "get_priority_messages":
    return await getPriorityMessages(
      userId,
      functionArgs.limit
    );
  case "translate_text":
    return await translateText(
      functionArgs.text,
      functionArgs.targetLanguage,
      functionArgs.sourceLanguage
    );
  case "get_recent_messages":
    return await getRecentMessages(
      functionArgs.conversationId,
      userId,
      functionArgs.limit
    );
  case "send_message":
    return await sendMessage(
      functionArgs.conversationId,
      userId,
      functionArgs.text,
      functionArgs.generateEmbedding !== false
    );
  default:
    return { error: "Unknown function" };
  }
}
