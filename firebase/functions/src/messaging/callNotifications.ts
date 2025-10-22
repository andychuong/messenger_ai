/**
 * callNotifications.ts
 * 
 * Cloud Functions for call notifications
 * Phase 5: Voice/Video Calling
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize admin if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Send push notification when a call is initiated
 * Triggered when a new call document is created
 */
export const sendCallNotification = functions.firestore
  .document("calls/{callId}")
  .onCreate(async (snapshot, context) => {
    try {
      const callData = snapshot.data();
      const callId = context.params.callId;

      // Only send notification for ringing calls
      if (callData.status !== "ringing") {
        console.log(`Call ${callId} is not ringing, skipping notification`);
        return;
      }

      const callerId = callData.callerId;
      const recipientId = callData.recipientId;
      const callType = callData.type; // 'audio' or 'video'

      console.log(`📞 New ${callType} call from ${callerId} to ${recipientId}`);

      // Get caller info
      const callerDoc = await db.collection("users").doc(callerId).get();
      if (!callerDoc.exists) {
        console.error("Caller not found");
        return;
      }
      const callerData = callerDoc.data();
      const callerName = callerData?.displayName || "Someone";
      const callerPhoto = callerData?.photoURL || "";

      // Get recipient's FCM token
      const recipientDoc = await db.collection("users").doc(recipientId).get();
      if (!recipientDoc.exists) {
        console.error("Recipient not found");
        return;
      }
      const recipientData = recipientDoc.data();
      const fcmToken = recipientData?.fcmToken;

      if (!fcmToken) {
        console.log("Recipient has no FCM token, cannot send notification");
        return;
      }

      // Prepare notification payload
      const callTypeText = callType === "video" ? "Video Call" : "Call";
      
      const message = {
        token: fcmToken,
        notification: {
          title: `Incoming ${callTypeText}`,
          body: `${callerName} is calling...`,
          ...(callerPhoto && { imageUrl: callerPhoto }),
        },
        data: {
          type: "call",
          callId: callId,
          callerId: callerId,
          callerName: callerName,
          callType: callType,
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: `Incoming ${callTypeText}`,
                body: `${callerName} is calling...`,
              },
              sound: "default",
              badge: 1,
              category: "CALL",
              // VoIP-specific properties
              "content-available": 1,
            },
          },
          headers: {
            "apns-priority": "10", // High priority
            "apns-push-type": "alert",
          },
        },
        android: {
          priority: "high" as const,
          notification: {
            channelId: "calls",
            priority: "high" as const,
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
      };

      // Send notification
      try {
        const response = await admin.messaging().send(message);
        console.log(`✅ Call notification sent successfully: ${response}`);
      } catch (notifError) {
        console.error("Error sending call notification:", notifError);
      }
    } catch (error) {
      console.error("Error in sendCallNotification:", error);
    }
  });

/**
 * Optional: Clean up old call records
 * Run daily to remove calls older than 30 days
 */
export const cleanupOldCalls = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const oldCallsQuery = db
      .collection("calls")
      .where("startedAt", "<", admin.firestore.Timestamp.fromDate(thirtyDaysAgo));

    const snapshot = await oldCallsQuery.get();
    
    if (snapshot.empty) {
      console.log("No old calls to clean up");
      return;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
    console.log(`Cleaned up ${snapshot.size} old call records`);
  });

