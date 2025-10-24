/**
 * AI Assistant Tool Definitions
 * 
 * Defines all available tools/functions for GPT-4o function calling
 */

import OpenAI from "openai";

export const assistantTools: OpenAI.Chat.ChatCompletionTool[] = [
  {
    type: "function",
    function: {
      name: "summarize_conversation",
      description: "Summarize a conversation thread with key points, decisions, and action items",
      parameters: {
        type: "object",
        properties: {
          conversationId: {
            type: "string",
            description: "The ID of the conversation to summarize",
          },
          messageCount: {
            type: "number",
            description: "Number of recent messages to include (default 50)",
          },
        },
        required: ["conversationId"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_action_items",
      description: "Retrieve pending action items for the user",
      parameters: {
        type: "object",
        properties: {
          status: {
            type: "string",
            enum: ["pending", "completed", "cancelled", "all"],
            description: "Filter by action item status (default: pending)",
          },
          conversationId: {
            type: "string",
            description: "Optional: filter by specific conversation",
          },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "search_messages",
      description: "Search conversation history using semantic search",
      parameters: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "Search query",
          },
          conversationId: {
            type: "string",
            description: "Optional: search within specific conversation",
          },
          limit: {
            type: "number",
            description: "Maximum number of results (default 10)",
          },
        },
        required: ["query"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_decisions",
      description: "Retrieve decisions made in conversations",
      parameters: {
        type: "object",
        properties: {
          conversationId: {
            type: "string",
            description: "Optional: filter by specific conversation",
          },
          limit: {
            type: "number",
            description: "Maximum number of results (default 10)",
          },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_priority_messages",
      description: "Retrieve high-priority unread messages",
      parameters: {
        type: "object",
        properties: {
          limit: {
            type: "number",
            description: "Maximum number of results (default 20)",
          },
        },
      },
    },
  },
  {
    type: "function",
    function: {
      name: "translate_text",
      description: "Translate text to a target language",
      parameters: {
        type: "object",
        properties: {
          text: {
            type: "string",
            description: "The text to translate",
          },
          targetLanguage: {
            type: "string",
            description: "Target language (e.g., 'Chinese', 'Spanish', 'French', 'German')",
          },
          sourceLanguage: {
            type: "string",
            description: "Source language (optional, will auto-detect if not provided)",
          },
        },
        required: ["text", "targetLanguage"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "get_recent_messages",
      description: "Get the user's recent messages from a conversation. Useful for 'translate my last message' or 'what did I just say'",
      parameters: {
        type: "object",
        properties: {
          conversationId: {
            type: "string",
            description: "The conversation ID to fetch messages from",
          },
          limit: {
            type: "number",
            description: "Number of recent messages to fetch (default 5)",
          },
        },
        required: ["conversationId"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "send_message",
      description: "Send a message to a conversation on behalf of the user. Use this when user asks to send, resend, or deliver a message.",
      parameters: {
        type: "object",
        properties: {
          conversationId: {
            type: "string",
            description: "The conversation ID to send the message to",
          },
          text: {
            type: "string",
            description: "The message text to send",
          },
          generateEmbedding: {
            type: "boolean",
            description: "Whether to immediately generate embedding for AI access (default: true)",
          },
        },
        required: ["conversationId", "text"],
      },
    },
  },
];

