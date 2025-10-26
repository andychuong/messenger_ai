/**
 * Sync user data to all conversations
 * 
 * When a user's data changes (status, photoURL, displayName),
 * this function automatically updates the participantDetails in all
 * conversations where the user is a participant.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * Firestore trigger: Sync user changes to all conversations
 * Triggers when any user document is updated
 */
export const syncUserDataToConversations = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if relevant fields changed
    const statusChanged = beforeData.status !== afterData.status;
    const photoChanged = beforeData.photoURL !== afterData.photoURL;
    const nameChanged = beforeData.displayName !== afterData.displayName;

    if (!statusChanged && !photoChanged && !nameChanged) {
      console.log(`No relevant changes for user ${userId}, skipping sync`);
      return null;
    }

    console.log(`Syncing user data for ${afterData.displayName} (${userId})`);
    if (statusChanged) {
      console.log(`  Status: ${beforeData.status} → ${afterData.status}`);
    }
    if (photoChanged) {
      console.log(`  Photo: ${beforeData.photoURL || "none"} → ${afterData.photoURL || "none"}`);
    }
    if (nameChanged) {
      console.log(`  Name: ${beforeData.displayName} → ${afterData.displayName}`);
    }

    try {
      // Find all conversations where this user is a participant
      const conversationsSnapshot = await db
        .collection("conversations")
        .where("participants", "array-contains", userId)
        .get();

      if (conversationsSnapshot.empty) {
        console.log(`No conversations found for user ${userId}`);
        return null;
      }

      console.log(`Found ${conversationsSnapshot.docs.length} conversation(s) to update`);

      // Update participant details in all conversations using batch writes
      const batchSize = 500; // Firestore batch limit
      const batches: admin.firestore.WriteBatch[] = [];
      let currentBatch = db.batch();
      let operationCount = 0;

      for (const doc of conversationsSnapshot.docs) {
        const conversationData = doc.data();
        const participantDetails = conversationData.participantDetails || {};

        // Update the participant details for this user
        if (participantDetails[userId]) {
          participantDetails[userId] = {
            ...participantDetails[userId],
            status: afterData.status,
            photoURL: afterData.photoURL,
            name: afterData.displayName,
          };

          currentBatch.update(doc.ref, { participantDetails });
          operationCount++;

          // Create a new batch if we hit the limit
          if (operationCount >= batchSize) {
            batches.push(currentBatch);
            currentBatch = db.batch();
            operationCount = 0;
          }
        }
      }

      // Add the last batch if it has operations
      if (operationCount > 0) {
        batches.push(currentBatch);
      }

      // Commit all batches
      await Promise.all(batches.map((batch) => batch.commit()));

      console.log(`✅ Successfully synced user data to ${conversationsSnapshot.docs.length} conversation(s)`);
      return null;
    } catch (error) {
      console.error(`❌ Error syncing user data for ${userId}:`, error);
      throw error;
    }
  });

