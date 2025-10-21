/**
 * Voice-to-Text Functions
 * 
 * Transcribes voice messages using OpenAI Whisper API
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";
import axios from "axios";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface TranscriptionRequest {
  messageId: string;
  conversationId: string;
  audioUrl: string;
}

/**
 * Transcribe voice message using Whisper API
 */
export const transcribeVoiceMessage = functions.https.onCall(
  async (data: TranscriptionRequest, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    
    const { messageId, conversationId, audioUrl } = data;
    
    try {
      // Get the message
      const messageRef = admin.firestore()
        .collection("conversations")
        .doc(conversationId)
        .collection("messages")
        .doc(messageId);
      
      const messageSnap = await messageRef.get();
      
      if (!messageSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Message not found");
      }
      
      // Check if already transcribed
      const existingTranscript = messageSnap.data()?.voiceTranscript;
      if (existingTranscript) {
        console.log("Returning cached transcript");
        return {
          transcript: existingTranscript,
          fromCache: true,
        };
      }
      
      // Download audio file from Firebase Storage
      const audioResponse = await axios.get(audioUrl, {
        responseType: "arraybuffer",
      });
      
      const audioBuffer = Buffer.from(audioResponse.data);
      
      // Create a File-like object for Whisper API
      const audioFile = new File([audioBuffer], "audio.m4a", {
        type: "audio/m4a",
      });
      
      // Transcribe using Whisper
      const transcription = await openai.audio.transcriptions.create({
        file: audioFile,
        model: "whisper-1",
        language: "en", // TODO: Auto-detect language
        response_format: "json",
      });
      
      const transcript = transcription.text;
      
      // Save transcript to message
      await messageRef.update({
        voiceTranscript: transcript,
        transcribedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`Transcribed voice message ${messageId}`);
      
      return {
        transcript,
        fromCache: false,
      };
    } catch (error) {
      console.error("Transcription error:", error);
      throw new functions.https.HttpsError("internal", "Transcription failed");
    }
  }
);

/**
 * Auto-transcribe voice messages (triggered by onCreate)
 * Optional: Automatically transcribe all voice messages
 */
export const autoTranscribeVoiceMessage = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    
    // Only process voice messages
    if (message.mediaType !== "voice" || !message.mediaURL) {
      return null;
    }
    
    // Check if transcription is enabled
    if (process.env.ENABLE_VOICE_TRANSCRIPTION !== "true") {
      console.log("Auto-transcription disabled");
      return null;
    }
    
    const messageId = context.params.messageId;
    const conversationId = context.params.conversationId;
    
    try {
      // Call transcription function
      await transcribeVoiceMessage.run({
        messageId,
        conversationId,
        audioUrl: message.mediaURL,
      }, context as any);
      
      console.log(`Auto-transcribed voice message ${messageId}`);
      return null;
    } catch (error) {
      console.error("Auto-transcription error:", error);
      // Don't throw - transcription is optional
      return null;
    }
  });


