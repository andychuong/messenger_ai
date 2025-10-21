/**
 * Cloud Functions for Friend Request Notifications
 * 
 * Handles push notifications for:
 * - New friend requests
 * - Friend request accepted
 * - Friend request declined
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Triggers when a new friendship document is created
 * Sends push notification to the recipient of the friend request
 */
export const onFriendRequestSent = functions.firestore
  .document("friendships/{friendshipId}")
  .onCreate(async (snap, context) => {
    const friendship = snap.data();
    const friendshipId = context.params.friendshipId;

    try {
      // Only send notification for pending requests
      if (friendship.status !== "pending") {
        return null;
      }

      const requestedBy = friendship.requestedBy;
      const userId1 = friendship.userId1;
      const userId2 = friendship.userId2;
      
      // Determine who is the recipient (the one who didn't send the request)
      const recipientId = requestedBy === userId1 ? userId2 : userId1;

      // Fetch requester details
      const requesterDoc = await admin.firestore()
        .collection("users")
        .doc(requestedBy)
        .get();

      if (!requesterDoc.exists) {
        console.error("Requester user not found:", requestedBy);
        return null;
      }

      const requester = requesterDoc.data();

      // Fetch recipient details to get FCM token
      const recipientDoc = await admin.firestore()
        .collection("users")
        .doc(recipientId)
        .get();

      if (!recipientDoc.exists) {
        console.error("Recipient user not found:", recipientId);
        return null;
      }

      const recipient = recipientDoc.data();

      // Check if recipient has FCM token
      if (!recipient?.fcmToken) {
        console.log("Recipient has no FCM token, skipping notification");
        return null;
      }

      // Send push notification
      const message = {
        notification: {
          title: "New Friend Request",
          body: `${requester?.displayName || "Someone"} sent you a friend request`,
        },
        data: {
          type: "friend_request",
          friendshipId: friendshipId,
          requesterId: requestedBy,
          requesterName: requester?.displayName || "",
          requesterEmail: requester?.email || "",
        },
        token: recipient.fcmToken,
      };

      await admin.messaging().send(message);
      console.log(`Friend request notification sent to ${recipientId}`);

      return null;
    } catch (error) {
      console.error("Error sending friend request notification:", error);
      return null;
    }
  });

/**
 * Triggers when a friendship document is updated
 * Sends notification when request is accepted or declined
 */
export const onFriendRequestUpdated = functions.firestore
  .document("friendships/{friendshipId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const friendshipId = context.params.friendshipId;

    try {
      // Check if status changed
      if (before.status === after.status) {
        return null;
      }

      const requestedBy = after.requestedBy;
      const userId1 = after.userId1;
      const userId2 = after.userId2;
      
      // The requester should get the notification
      const requesterId = requestedBy;
      const responderId = requestedBy === userId1 ? userId2 : userId1;

      // Fetch responder details (person who accepted/declined)
      const responderDoc = await admin.firestore()
        .collection("users")
        .doc(responderId)
        .get();

      if (!responderDoc.exists) {
        console.error("Responder user not found:", responderId);
        return null;
      }

      const responder = responderDoc.data();

      // Fetch requester details to get FCM token
      const requesterDoc = await admin.firestore()
        .collection("users")
        .doc(requesterId)
        .get();

      if (!requesterDoc.exists) {
        console.error("Requester user not found:", requesterId);
        return null;
      }

      const requester = requesterDoc.data();

      // Check if requester has FCM token
      if (!requester?.fcmToken) {
        console.log("Requester has no FCM token, skipping notification");
        return null;
      }

      let notificationTitle = "";
      let notificationBody = "";
      let notificationType = "";

      // Send notification based on new status
      if (after.status === "accepted") {
        notificationTitle = "Friend Request Accepted";
        notificationBody = `${responder?.displayName || "Someone"} accepted your friend request`;
        notificationType = "friend_request_accepted";
      } else if (after.status === "declined") {
        notificationTitle = "Friend Request Declined";
        notificationBody = `${responder?.displayName || "Someone"} declined your friend request`;
        notificationType = "friend_request_declined";
      } else {
        // No notification for other status changes
        return null;
      }

      // Send push notification
      const message = {
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          type: notificationType,
          friendshipId: friendshipId,
          friendId: responderId,
          friendName: responder?.displayName || "",
        },
        token: requester.fcmToken,
      };

      await admin.messaging().send(message);
      console.log(`Friend request ${after.status} notification sent to ${requesterId}`);

      return null;
    } catch (error) {
      console.error("Error sending friend request update notification:", error);
      return null;
    }
  });

/**
 * HTTP function to manually send a friend request notification
 * Useful for testing and debugging
 */
export const sendFriendRequestNotificationManual = functions.https.onCall(
  async (data, context) => {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to send friend requests"
      );
    }

    const { recipientId } = data;

    if (!recipientId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "recipientId is required"
      );
    }

    try {
      const senderId = context.auth.uid;

      // Fetch sender details
      const senderDoc = await admin.firestore()
        .collection("users")
        .doc(senderId)
        .get();

      if (!senderDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Sender user not found"
        );
      }

      const sender = senderDoc.data();

      // Fetch recipient details
      const recipientDoc = await admin.firestore()
        .collection("users")
        .doc(recipientId)
        .get();

      if (!recipientDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Recipient user not found"
        );
      }

      const recipient = recipientDoc.data();

      // Check if recipient has FCM token
      if (!recipient?.fcmToken) {
        console.log("Recipient has no FCM token, skipping notification");
        return { success: true, message: "Recipient has no FCM token" };
      }

      // Send push notification
      const message = {
        notification: {
          title: "New Friend Request",
          body: `${sender?.displayName || "Someone"} sent you a friend request`,
        },
        data: {
          type: "friend_request",
          senderId: senderId,
          senderName: sender?.displayName || "",
        },
        token: recipient.fcmToken,
      };

      await admin.messaging().send(message);

      return {
        success: true,
        message: "Friend request notification sent",
      };
    } catch (error) {
      console.error("Error sending friend request notification:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send notification"
      );
    }
  }
);

