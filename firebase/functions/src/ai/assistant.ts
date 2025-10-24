/**
 * AI Assistant Functions
 * 
 * Handles conversation with AI assistant for:
 * - Conversation summarization
 * - Action item extraction
 * - Semantic search
 * - Question answering
 * - Decision tracking
 * - Multi-turn conversations
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
  conversationHistory?: ConversationMessage[];
  context?: any;
}

interface ConversationMessage {
  role: "user" | "assistant" | "system";
  content: string;
  timestamp?: number;
}

// Define available tools for GPT-4o function calling
const assistantTools: OpenAI.Chat.ChatCompletionTool[] = [
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

/**
 * Chat with AI assistant using GPT-4o with function calling
 * Main entry point for all AI assistant interactions
 */
export const chatWithAssistant = functions.https.onCall(async (data: AssistantRequest, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required");
  }
  
  const { query, conversationId, userId, conversationHistory = [] } = data;
  
  try {
    // Build messages array with conversation history
    const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [
      {
        role: "system",
        content: `You are a helpful AI assistant for a messaging app. You have access to:
- Conversation summaries
- Action item tracking
- Semantic search across message history
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

Special handling for translations:
- When asked to "translate and send" or "send in [language]":
  1. Use get_recent_messages to fetch their last message
  2. Use translate_text to translate it
  3. Use send_message to send the translation to the conversation
- If they just ask to translate (without sending), only provide the translation
- Always confirm after sending a message

Current user ID: ${userId}
${conversationId ? `Current conversation ID: ${conversationId}` : "No conversation context - user may need to provide conversation ID"}`,
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

    // Keep calling tools until GPT gives a final text response
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

          let result;
          switch (functionName) {
          case "summarize_conversation":
            result = await summarizeConversation(
              functionArgs.conversationId,
              userId,
              functionArgs.messageCount
            );
            break;
          case "get_action_items":
            result = await getActionItems(
              userId,
              functionArgs.status,
              functionArgs.conversationId
            );
            break;
          case "search_messages":
            result = await semanticSearch(
              functionArgs.query,
              userId,
              functionArgs.conversationId,
              functionArgs.limit
            );
            break;
          case "get_decisions":
            result = await getDecisions(
              userId,
              functionArgs.conversationId,
              functionArgs.limit
            );
            break;
          case "get_priority_messages":
            result = await getPriorityMessages(
              userId,
              functionArgs.limit
            );
            break;
          case "translate_text":
            result = await translateText(
              functionArgs.text,
              functionArgs.targetLanguage,
              functionArgs.sourceLanguage
            );
            break;
          case "get_recent_messages":
            result = await getRecentMessages(
              functionArgs.conversationId,
              userId,
              functionArgs.limit
            );
            break;
          case "send_message":
            result = await sendMessage(
              functionArgs.conversationId,
              userId,
              functionArgs.text,
              functionArgs.generateEmbedding !== false
            );
            break;
          default:
            result = { error: "Unknown function" };
          }

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

    // Return final text response (or direct response if no tools were called)
    // Ensure we always have a non-empty response
    const finalContent = currentResponse?.content?.trim();
    
    return {
      response: finalContent || "I processed your request but don't have additional information to share.",
      toolsUsed: allToolsUsed,
      timestamp: Date.now(),
    };
  } catch (error) {
    console.error("Assistant error:", error);
    throw new functions.https.HttpsError("internal", "Assistant request failed");
  }
});

/**
 * Summarize conversation thread
 */
async function summarizeConversation(
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
  
  const messages = messagesSnap.docs.map((doc) => ({
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
  const userIds = [...new Set(messages.map((m: any) => m.senderId))];
  const userNames: Record<string, string> = {};
  
  for (const uid of userIds) {
    const userSnap = await admin.firestore().collection("users").doc(uid).get();
    userNames[uid] = userSnap.data()?.displayName || "Unknown";
  }
  
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
async function getActionItems(
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
async function semanticSearch(
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
async function getDecisions(
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
async function getPriorityMessages(
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
 * Calculate cosine similarity between two vectors
 */
function cosineSimilarity(vecA: number[], vecB: number[]): number {
  if (vecA.length !== vecB.length) {
    throw new Error("Vectors must have the same length");
  }

  let dotProduct = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }

  normA = Math.sqrt(normA);
  normB = Math.sqrt(normB);

  if (normA === 0 || normB === 0) {
    return 0;
  }

  return dotProduct / (normA * normB);
}

/**
 * Get recent messages from a conversation
 * Uses embeddings collection which has unencrypted text for AI features
 * Note: Requires messages to be sent from updated iOS app (after rebuild)
 */
async function getRecentMessages(
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
    const userNames: Record<string, string> = {};

    for (const uid of userIds) {
      const userSnap = await admin.firestore().collection("users").doc(uid).get();
      userNames[uid] = userSnap.data()?.displayName || "Unknown";
    }

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
 * Includes real-time embedding generation for instant AI access
 */
async function sendMessage(
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

    // Generate embedding immediately if requested (real-time generation)
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

/**
 * Generate embedding for a message (real-time)
 * Called synchronously when sending messages via AI
 */
async function generateMessageEmbedding(
  messageId: string,
  conversationId: string,
  text: string,
  senderId: string
) {
  // Generate embedding using OpenAI
  const embeddingResponse = await openai.embeddings.create({
    model: "text-embedding-3-large",
    input: text,
  });

  const embedding = embeddingResponse.data[0].embedding;

  // Store in embeddings collection
  const embeddingRef = admin.firestore().collection("embeddings").doc(messageId);
  
  await embeddingRef.set({
    messageId: messageId,
    conversationId: conversationId,
    senderId: senderId,
    text: text,
    embedding: embedding,
    timestamp: admin.firestore.Timestamp.now(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    embeddingId: embeddingRef.id,
    dimensions: embedding.length,
  };
}

/**
 * Translate text to target language
 */
async function translateText(
  text: string,
  targetLanguage: string,
  sourceLanguage?: string
) {
  try {
    const sourceInfo = sourceLanguage ? ` from ${sourceLanguage}` : "";
    
    const completion = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: `You are a professional translator. Translate the given text${sourceInfo} to ${targetLanguage}. 
Provide ONLY the translation, without any explanations or additional text.
Maintain the tone and context of the original message.`,
        },
        {
          role: "user",
          content: text,
        },
      ],
      temperature: 0.3,
      max_tokens: 500,
    });

    const translation = completion.choices[0]?.message?.content || "";

    return {
      translation,
      sourceLanguage: sourceLanguage || "auto-detected",
      targetLanguage,
      originalText: text,
    };
  } catch (error) {
    console.error("Translation error:", error);
    return {
      translation: "",
      error: "Translation failed",
      originalText: text,
    };
  }
}


