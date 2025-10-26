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
  translateTo?: string[]; // Phase 19.2: Optional array of language codes to translate to
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
interface TranscriptionResponse {
  transcript: string;
  detectedLanguage?: string;
  translations?: Record<string, string>; // languageCode -> translated text
  fromCache: boolean;
}

/**
 * Transcribe voice message using Whisper API
 * Phase 19.2: Enhanced with language detection and translation
 */
export const transcribeVoiceMessage = functions.https.onCall(
  async (data: TranscriptionRequest, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    
    const { messageId, conversationId, audioUrl, translateTo } = data;
    
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
      const messageData = messageSnap.data();
      const existingTranscript = messageData?.voiceTranscript;
      const existingTranslations = messageData?.voiceTranslations || {};
      const existingLanguage = messageData?.detectedLanguage;
      
      if (existingTranscript) {
        console.log("Returning cached transcript");
        
        // Check if we need new translations
        const translations: Record<string, string> = { ...existingTranslations };
        let needsNewTranslation = false;
        
        if (translateTo && translateTo.length > 0) {
          for (const targetLang of translateTo) {
            if (!translations[targetLang]) {
              needsNewTranslation = true;
              // Translate the existing transcript
              const translated = await translateText(existingTranscript, targetLang);
              translations[targetLang] = translated;
            }
          }
          
          // Update message with new translations if any
          if (needsNewTranslation) {
            await messageRef.update({
              voiceTranslations: translations,
            });
          }
        }
        
        return {
          transcript: existingTranscript,
          detectedLanguage: existingLanguage,
          translations,
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
      
      // Phase 19.2: Transcribe using Whisper with language detection
      // First, transcribe without language constraint to auto-detect
      const transcription = await openai.audio.transcriptions.create({
        file: audioFile,
        model: "whisper-1",
        // Remove language parameter to auto-detect
        response_format: "verbose_json", // Get language info
      });
      
      const transcript = transcription.text;
      const detectedLanguage = transcription.language || "unknown";
      
      console.log(`Detected language: ${detectedLanguage}`);
      
      // Phase 19.2: Generate translations if requested
      const translations: Record<string, string> = {};
      if (translateTo && translateTo.length > 0) {
        for (const targetLang of translateTo) {
          // Don't translate to the same language
          if (targetLang !== detectedLanguage) {
            const translated = await translateText(transcript, targetLang);
            translations[targetLang] = translated;
          }
        }
      }
      
      // Save transcript, detected language, and translations to message
      await messageRef.update({
        voiceTranscript: transcript,
        detectedLanguage,
        voiceTranslations: translations,
        transcribedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log(`Transcribed voice message ${messageId} (${detectedLanguage})`);
      
      return {
        transcript,
        detectedLanguage,
        translations,
        fromCache: false,
      };
    } catch (error) {
      console.error("Transcription error:", error);
      throw new functions.https.HttpsError("internal", "Transcription failed");
    }
  }
);

/**
 * Phase 19.2: Helper function to translate text using GPT-4o
 */
async function translateText(text: string, targetLanguage: string): Promise<string> {
  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: `You are a professional translator. Translate the following text to ${targetLanguage}. 
Preserve the meaning, tone, and context. Return only the translated text without any explanations.`,
        },
        {
          role: "user",
          content: text,
        },
      ],
      temperature: 0.3,
    });

    return response.choices[0]?.message?.content?.trim() || text;
  } catch (error) {
    console.error(`Translation error for language ${targetLanguage}:`, error);
    // Return original text if translation fails
    return text;
  }
}

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


