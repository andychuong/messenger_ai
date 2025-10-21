/**
 * Push Notification Functions
 * 
 * Handles sending push notifications for:
 * - New messages
 * - Incoming calls
 * - Friend requests
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Send notification when a new message is created
 * Triggered by Firestore onCreate event
 */
export const sendMessageNotification = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const conversationId = context.params.conversationId;
    
    try {
      // Get conversation to find recipient
      const conversationRef = admin.firestore()
        .collection("conversations")
        .doc(conversationId);
      const conversationSnap = await conversationRef.get();
      
      if (!conversationSnap.exists) {
        console.log("Conversation not found");
        return null;
      }
      
      const conversation = conversationSnap.data();
      const senderId = message.senderId;
      const participants = conversation?.participants || [];
      
      // Get recipient IDs (all participants except sender)
      const recipientIds = participants.filter((id: string) => id !== senderId);
      
      if (recipientIds.length === 0) {
        console.log("No recipients found");
        return null;
      }
      
      // Get sender info
      const senderSnap = await admin.firestore()
        .collection("users")
        .doc(senderId)
        .get();
      const senderName = senderSnap.data()?.displayName || "Someone";
      
      // Get FCM tokens for recipients
      const recipientTokens: string[] = [];
      for (const recipientId of recipientIds) {
        const recipientSnap = await admin.firestore()
          .collection("users")
          .doc(recipientId)
          .get();
        const fcmToken = recipientSnap.data()?.fcmToken;
        if (fcmToken) {
          recipientTokens.push(fcmToken);
        }
      }
      
      if (recipientTokens.length === 0) {
        console.log("No FCM tokens found for recipients");
        return null;
      }
      
      // Prepare notification payload
      const messageText = message.text || "Sent an image";
      const payload = {
        notification: {
          title: senderName,
          body: messageText.length > 100 
            ? messageText.substring(0, 100) + "..." 
            : messageText,
          sound: "default",
        },
        data: {
          conversationId: conversationId,
          messageId: snapshot.id,
          senderId: senderId,
          type: "message",
        },
        apns: {
          payload: {
            aps: {
              badge: 1, // TODO: Calculate actual unread count
              sound: "default",
            },
          },
        },
      };
      
      // Send notification to all recipients
      const response = await admin.messaging().sendEachForMulticast({
        tokens: recipientTokens,
        ...payload,
      });
      
      console.log(`Sent ${response.successCount} notifications successfully`);
      
      // Handle failures
      if (response.failureCount > 0) {
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(recipientTokens[idx]);
            console.error(`Failed to send to token: ${recipientTokens[idx]}`, resp.error);
          }
        });
        
        // TODO: Remove invalid tokens from user documents
      }
      
      return response;
    } catch (error) {
      console.error("Error sending message notification:", error);
      return null;
    }
  });

/**
 * Send notification for incoming call
 */
export const sendCallNotification = functions.firestore
  .document("calls/{callId}")
  .onCreate(async (snapshot, context) => {
    const call = snapshot.data();
    const callId = context.params.callId;
    
    try {
      const callerId = call.callerId;
      const recipientId = call.recipientId;
      const callType = call.type; // "audio" or "video"
      
      // Get caller info
      const callerSnap = await admin.firestore()
        .collection("users")
        .doc(callerId)
        .get();
      const callerName = callerSnap.data()?.displayName || "Someone";
      
      // Get recipient FCM token
      const recipientSnap = await admin.firestore()
        .collection("users")
        .doc(recipientId)
        .get();
      const fcmToken = recipientSnap.data()?.fcmToken;
      
      if (!fcmToken) {
        console.log("No FCM token for recipient");
        return null;
      }
      
      // Send VoIP-style notification
      const payload = {
        notification: {
          title: `Incoming ${callType} call`,
          body: `${callerName} is calling...`,
          sound: "ringtone.caf",
        },
        data: {
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callType: callType,
          type: "call",
        },
        apns: {
          payload: {
            aps: {
              sound: "ringtone.caf",
              category: "CALL",
              "content-available": 1,
            },
          },
        },
      };
      
      const response = await admin.messaging().send({
        token: fcmToken,
        ...payload,
      });
      
      console.log("Call notification sent successfully:", response);
      return response;
    } catch (error) {
      console.error("Error sending call notification:", error);
      return null;
    }
  });

// Friend request notifications are now handled in ./friendships.ts

