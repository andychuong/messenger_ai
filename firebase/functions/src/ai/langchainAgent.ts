/**
 * LangChain AI Agent for Messaging App
 * 
 * Provides fluid, conversational AI with tool use capabilities
 * Can handle complex multi-step tasks related to messaging
 */

import * as functions from "firebase-functions";
import { ChatOpenAI } from "@langchain/openai";
import { AgentExecutor, createOpenAIFunctionsAgent } from "langchain/agents";
import { ChatPromptTemplate, MessagesPlaceholder } from "@langchain/core/prompts";
import { DynamicStructuredTool } from "@langchain/core/tools";
import { HumanMessage, AIMessage, BaseMessage } from "@langchain/core/messages";
import { z } from "zod";
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

/**
 * Create LangChain tools from existing functions
 */
function createMessagingTools(userId: string, conversationId?: string) {
  return [
    // Search messages tool
    new DynamicStructuredTool({
      name: "search_messages",
      description: "Search message history using semantic search. Searches across ALL user's conversations by default. Use this for questions like 'who did I say hello to', 'what did I talk about yesterday', etc. Only specify conversationId to limit search to a specific conversation.",
      schema: z.object({
        query: z.string().describe("Search query (e.g., 'hello', 'meeting tomorrow', 'project updates')"),
        conversationId: z.string().optional().describe("Optional: limit search to a specific conversation. Leave blank to search ALL conversations."),
        limit: z.number().optional().default(10).describe("Maximum number of results"),
      }),
      func: async ({ query, conversationId: convId, limit }) => {
        const result = await semanticSearch(query, userId, convId, limit);
        return JSON.stringify(result);
      },
    }),

    // Summarize conversation tool
    new DynamicStructuredTool({
      name: "summarize_conversation",
      description: "Summarize a conversation thread with key points, decisions, and action items",
      schema: z.object({
        conversationId: z.string().describe("The ID of the conversation to summarize"),
        messageCount: z.number().optional().default(50).describe("Number of recent messages to include"),
      }),
      func: async ({ conversationId: convId, messageCount }) => {
        const result = await summarizeConversation(convId, userId, messageCount);
        return JSON.stringify(result);
      },
    }),

    // Get action items tool
    new DynamicStructuredTool({
      name: "get_action_items",
      description: "Retrieve pending action items for the user",
      schema: z.object({
        status: z.enum(["pending", "completed", "cancelled", "all"]).optional().default("pending").describe("Filter by action item status"),
        conversationId: z.string().optional().describe("Optional: filter by specific conversation"),
      }),
      func: async ({ status, conversationId: convId }) => {
        const result = await getActionItems(userId, status, convId);
        return JSON.stringify(result);
      },
    }),

    // Get decisions tool
    new DynamicStructuredTool({
      name: "get_decisions",
      description: "Retrieve decisions made in conversations",
      schema: z.object({
        conversationId: z.string().optional().describe("Optional: filter by specific conversation"),
        limit: z.number().optional().default(10).describe("Maximum number of results"),
      }),
      func: async ({ conversationId: convId, limit }) => {
        const result = await getDecisions(userId, convId, limit);
        return JSON.stringify(result);
      },
    }),

    // Get priority messages tool
    new DynamicStructuredTool({
      name: "get_priority_messages",
      description: "Retrieve high-priority unread messages",
      schema: z.object({
        limit: z.number().optional().default(20).describe("Maximum number of results"),
      }),
      func: async ({ limit }) => {
        const result = await getPriorityMessages(userId, limit);
        return JSON.stringify(result);
      },
    }),

    // Translate text tool
    new DynamicStructuredTool({
      name: "translate_text",
      description: "Translate text to a target language using AI",
      schema: z.object({
        text: z.string().describe("The text to translate"),
        targetLanguage: z.string().describe("Target language (e.g., 'Chinese', 'Spanish', 'French', 'German')"),
        sourceLanguage: z.string().optional().describe("Source language (optional, will auto-detect if not provided)"),
      }),
      func: async ({ text, targetLanguage, sourceLanguage }) => {
        const result = await translateText(text, targetLanguage, sourceLanguage);
        return JSON.stringify(result);
      },
    }),

    // Get recent messages tool
    new DynamicStructuredTool({
      name: "get_recent_messages",
      description: "Get the user's recent messages from a conversation. Useful for 'translate my last message' or 'what did I just say'",
      schema: z.object({
        conversationId: z.string().describe("The conversation ID to fetch messages from"),
        limit: z.number().optional().default(5).describe("Number of recent messages to fetch"),
      }),
      func: async ({ conversationId: convId, limit }) => {
        const result = await getRecentMessages(convId, userId, limit);
        return JSON.stringify(result);
      },
    }),

    // Send message tool
    new DynamicStructuredTool({
      name: "send_message",
      description: "Send a message to a conversation on behalf of the user. Use this when user asks to send, resend, or deliver a message.",
      schema: z.object({
        conversationId: z.string().describe("The conversation ID to send the message to"),
        text: z.string().describe("The message text to send"),
        generateEmbedding: z.boolean().optional().default(true).describe("Whether to immediately generate embedding for AI access"),
      }),
      func: async ({ conversationId: convId, text, generateEmbedding }) => {
        const result = await sendMessage(convId, userId, text, generateEmbedding);
        return JSON.stringify(result);
      },
    }),
  ];
}

/**
 * Create the system prompt for the agent
 */
function getAgentSystemPrompt(userId: string, conversationId?: string): string {
  return `You are an intelligent AI assistant integrated into a messaging application. Your role is to help users with their messaging needs in a natural, conversational way.

**Your Capabilities:**
- Search and find information across all conversations
- Summarize conversations and extract key points
- Track and manage action items
- Identify important decisions
- Translate messages between languages
- Send messages on behalf of the user
- Answer questions about message history

**Important Guidelines:**
1. **Be proactive**: When a user asks a question, use the appropriate tools to find the answer
2. **Be specific**: Cite sources when referencing messages (mention conversation, sender, etc.)
3. **Be conversational**: Respond naturally, as if you're a helpful colleague
4. **Be accurate**: If you can't find information, say so clearly
5. **Respect privacy**: Only access conversations the user is part of

**Search Behavior:**
- For general questions like "who did I talk to about X" or "when did someone mention Y", search across ALL conversations (don't specify conversationId)
- Only search specific conversations when the user explicitly asks about that conversation or you're already in a conversation context
- Use semantic search to understand intent, not just exact words

**Translation & Messaging:**
- When asked to "translate and send", first get their recent message, translate it, then send it
- When asked to just translate, only provide the translation without sending
- Always confirm after sending a message

**Context:**
- User ID: ${userId}
- ${conversationId ? `Current Conversation: ${conversationId}` : "Global Mode - Can access all user's conversations"}

Be helpful, efficient, and friendly!`;
}

/**
 * LangChain-powered AI Agent
 */
export const chatWithAgent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const { query, conversationId, userId, conversationHistory = [] } = data;

  try {
    // Initialize ChatOpenAI model
    const model = new ChatOpenAI({
      modelName: "gpt-4o",
      temperature: 0.7,
      maxTokens: 1500,
      openAIApiKey: process.env.OPENAI_API_KEY,
    });

    // Create tools
    const tools = createMessagingTools(userId, conversationId);

    // Create prompt template
    const prompt = ChatPromptTemplate.fromMessages([
      ["system", getAgentSystemPrompt(userId, conversationId)],
      new MessagesPlaceholder("chat_history"),
      ["human", "{input}"],
      new MessagesPlaceholder("agent_scratchpad"),
    ]);

    // Create agent
    const agent = await createOpenAIFunctionsAgent({
      llm: model,
      tools,
      prompt,
    });

    // Create agent executor
    const agentExecutor = new AgentExecutor({
      agent,
      tools,
      verbose: true,
      maxIterations: 10,
      returnIntermediateSteps: true,
    });

    // Prepare conversation history in LangChain format
    const chatHistory: BaseMessage[] = conversationHistory.map((msg: any) => {
      if (msg.role === "user") {
        return new HumanMessage(msg.content);
      } else {
        return new AIMessage(msg.content);
      }
    });

    // Execute agent
    const result = await agentExecutor.invoke({
      input: query,
      chat_history: chatHistory,
    });

    // Extract tool names that were used
    const toolsUsed = (result.intermediateSteps || []).map((step: any) => 
      step.action?.tool || "unknown"
    );

    return {
      finalResponse: result.output,
      toolsUsed: [...new Set(toolsUsed)], // Remove duplicates
    };
  } catch (error: any) {
    console.error("Agent error:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Agent request failed: ${error.message}`
    );
  }
});

/**
 * Batch process multiple queries with the agent
 * Useful for analyzing conversations or generating insights
 */
export const batchAgentQueries = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }

  const { queries, conversationId, userId } = data;

  if (!Array.isArray(queries) || queries.length === 0) {
    throw new functions.https.HttpsError("invalid-argument", "queries must be a non-empty array");
  }

  if (queries.length > 10) {
    throw new functions.https.HttpsError("invalid-argument", "Maximum 10 queries per batch");
  }

  try {
    const results = await Promise.all(
      queries.map(async (query: string) => {
        try {
          const result = await chatWithAgent.run(
            { query, conversationId, userId, conversationHistory: [] },
            context as any
          );
          return {
            query,
            success: true,
            ...result,
          };
        } catch (error: any) {
          console.error(`Failed to process query: ${query}`, error);
          return {
            query,
            success: false,
            error: error.message,
          };
        }
      })
    );

    return {
      results,
      totalProcessed: results.length,
      successCount: results.filter((r) => r.success).length,
    };
  } catch (error: any) {
    console.error("Batch agent error:", error);
    throw new functions.https.HttpsError("internal", "Batch processing failed");
  }
});

