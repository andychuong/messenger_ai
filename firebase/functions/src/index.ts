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
export * from "./ai/translation";
export * from "./ai/assistant";
export * from "./ai/embeddings";
export * from "./ai/voiceToText";
export * from "./ai/intelligence";

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

