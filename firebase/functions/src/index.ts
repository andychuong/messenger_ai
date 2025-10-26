/**
 * Cloud Functions for MessageAI
 * 
 * Main entry point for all Firebase Cloud Functions including:
 * - Push notifications for messages and calls
 * - AI features (translation, summarization, RAG)
 * - Voice-to-text transcription
 * - Action item extraction
 * - Decision tracking
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as dotenv from "dotenv";

// Load environment variables
dotenv.config();

// Initialize Firebase Admin
admin.initializeApp();

// Export function modules
export * from "./messaging/notifications";
export * from "./messaging/friendships";
export * from "./messaging/callNotifications";
export * from "./messaging/syncUserData"; // Sync user data to conversations
export * from "./messaging/fileProcessing"; // Phase 19: File processing
export * from "./ai/translation";
export * from "./ai/assistant";
export * from "./ai/langchainAgent"; // LangChain-powered agent
export * from "./ai/embeddings";
export * from "./ai/cleanupEmbeddings"; // Cleanup invalid embeddings
export * from "./ai/debugDatabase"; // Database health check
export * from "./ai/voiceToText";
export * from "./ai/actionItems";
export * from "./ai/decisions";
export * from "./ai/priority";
// Phase 15: Enhanced Translation Features
export * from "./ai/culturalContext"; // Cultural context hints
export * from "./ai/formalityAdjustment"; // Formality level adjustments
export * from "./ai/slangExplanation"; // Slang and idiom explanations
// Phase 16: Smart Replies & Suggestions
export * from "./ai/smartReplies"; // Context-aware smart replies
export * from "./ai/smartCompose"; // Type-ahead suggestions
// Phase 17: Enhanced Data Extraction
export * from "./ai/dataExtraction"; // Multilingual structured data extraction
// Phase 18: Timezone Coordination
export * from "./ai/meetingScheduler"; // Meeting time suggestions with timezone awareness

/**
 * Health check function
 * Useful for monitoring and testing deployment
 */
export const healthCheck = functions.https.onRequest((request, response) => {
  response.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    version: "1.0.0",
    services: {
      firestore: "connected",
      openai: process.env.OPENAI_API_KEY ? "configured" : "not configured",
      pinecone: process.env.PINECONE_API_KEY ? "configured" : "not configured",
    },
  });
});

/**
 * Example: Get configuration status
 * Debug endpoint to check environment setup
 */
export const getConfig = functions.https.onRequest((request, response) => {
  // NEVER expose actual API keys
  response.json({
    openai_configured: !!process.env.OPENAI_API_KEY,
    pinecone_configured: !!process.env.PINECONE_API_KEY,
    firebase_project: process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID,
    region: process.env.FIREBASE_REGION || "us-central1",
    ai_features_enabled: process.env.ENABLE_AI_FEATURES === "true",
  });
});

