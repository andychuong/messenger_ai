/**
 * Phase 19: File Processing Cloud Function
 * 
 * Handles file uploads, validation, and metadata extraction
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

interface FileMetadata {
  fileName: string;
  fileSize: number;
  mimeType: string;
  thumbnailURL?: string;
  downloadURL: string;
  uploadedBy: string;
  uploadedAt: admin.firestore.Timestamp;
  isEncrypted: boolean;
  encryptionKeyId?: string;
  metadata?: {
    pages?: number;
    author?: string;
    createdDate?: string;
  };
}

interface FileUploadRequest {
  conversationId: string;
  fileName: string;
  fileSize: number;
  mimeType: string;
  downloadURL: string;
  isEncrypted: boolean;
  encryptionKeyId?: string;
}

const MAX_FILE_SIZE_FREE = 10 * 1024 * 1024; // 10 MB
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const MAX_FILE_SIZE_PREMIUM = 100 * 1024 * 1024; // 100 MB (for future premium tier)

// Supported MIME types (whitelist for security)
const SUPPORTED_MIME_TYPES = [
  // Documents
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/vnd.ms-excel",
  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "application/vnd.ms-powerpoint",
  "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  
  // Apple iWork
  "application/vnd.apple.pages",
  "application/vnd.apple.numbers",
  "application/vnd.apple.keynote",
  
  // Text
  "text/plain",
  "text/rtf",
  "text/markdown",
  "text/csv",
  "application/json",
  "application/xml",
  "text/xml",
  
  // Archives
  "application/zip",
  "application/x-rar-compressed",
  "application/x-7z-compressed",
  
  // Code files (text-based)
  "text/javascript",
  "application/javascript",
  "text/typescript",
  "text/x-python",
  "text/x-swift",
  "text/x-java",
  "text/x-c",
  "text/x-c++",
];

/**
 * Validate and process file upload
 * This function is called after the file is uploaded to Storage
 * It validates the file and extracts metadata
 */
export const processFileUpload = functions.https.onCall(
  async (data: FileUploadRequest, context) => {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const userId = context.auth.uid;
    const {
      conversationId,
      fileName,
      fileSize,
      mimeType,
      downloadURL,
      isEncrypted,
      encryptionKeyId,
    } = data;

    try {
      // 1. Validate user has access to conversation
      const conversationRef = admin
        .firestore()
        .collection("conversations")
        .doc(conversationId);
      const conversationDoc = await conversationRef.get();

      if (!conversationDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Conversation not found"
        );
      }

      const conversationData = conversationDoc.data();
      if (!conversationData?.participants?.includes(userId)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "User is not a participant in this conversation"
        );
      }

      // 2. Validate file size
      // TODO: Check user tier (free vs premium)
      const maxSize = MAX_FILE_SIZE_FREE;
      if (fileSize > maxSize) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          `File size exceeds maximum allowed (${maxSize / 1024 / 1024} MB)`
        );
      }

      // 3. Validate MIME type
      if (!SUPPORTED_MIME_TYPES.includes(mimeType)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          `File type not supported: ${mimeType}`
        );
      }

      // 4. Extract additional metadata (if applicable)
      const additionalMetadata = await extractFileMetadata(
        fileName,
        mimeType,
        downloadURL
      );

      // 5. Create file metadata object
      const fileMetadata: FileMetadata = {
        fileName,
        fileSize,
        mimeType,
        downloadURL,
        uploadedBy: userId,
        uploadedAt: admin.firestore.Timestamp.now(),
        isEncrypted,
        encryptionKeyId,
        metadata: additionalMetadata,
      };

      // 6. Generate thumbnail (optional, for future implementation)
      // const thumbnailURL = await generateThumbnail(downloadURL, mimeType);
      // if (thumbnailURL) {
      //   fileMetadata.thumbnailURL = thumbnailURL;
      // }

      // 7. Return processed metadata
      return {
        success: true,
        fileMetadata,
      };
    } catch (error: any) {
      console.error("Error processing file upload:", error);

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError(
        "internal",
        "Failed to process file upload",
        error.message
      );
    }
  }
);

/**
 * Extract metadata from file based on type
 * This is a placeholder - in production, you would use appropriate libraries
 * to extract metadata from different file types
 */
async function extractFileMetadata(
  fileName: string,
  mimeType: string,
  downloadURL: string
): Promise<{ pages?: number; author?: string; createdDate?: string } | undefined> {
  // For now, return undefined
  // In production, you would:
  // - For PDFs: Use a library to extract page count, author, etc.
  // - For documents: Extract metadata from Office files
  // - For images: Extract EXIF data (if supporting images here)

  // Example for future implementation:
  // if (mimeType === 'application/pdf') {
  //   const pdfData = await downloadFile(downloadURL);
  //   const metadata = await extractPDFMetadata(pdfData);
  //   return metadata;
  // }

  return undefined;
}

/**
 * Virus scanning placeholder
 * In production, you would integrate with a service like:
 * - ClamAV
 * - VirusTotal API
 * - Cloud-based scanning service
 */
// eslint-disable-next-line @typescript-eslint/no-unused-vars
async function scanFileForViruses(downloadURL: string): Promise<boolean> {
  // Placeholder - always returns true (clean)
  // In production:
  // const fileBuffer = await downloadFile(downloadURL);
  // const scanResult = await virusScanService.scan(fileBuffer);
  // return scanResult.isClean;

  console.log(`Virus scan placeholder for: ${downloadURL}`);
  return true;
}

/**
 * File cleanup trigger
 * Automatically delete files from Storage when messages are deleted
 */
export const cleanupDeletedFiles = functions.firestore
  .document("conversations/{conversationId}/messages/{messageId}")
  .onDelete(async (snapshot, context) => {
    const messageData = snapshot.data();

    // Check if message has file attachment
    if (
      messageData.type === "file" &&
      messageData.fileMetadata?.downloadURL
    ) {
      try {
        const downloadURL = messageData.fileMetadata.downloadURL;

        // Extract storage path from download URL
        const storage = admin.storage();
        const bucket = storage.bucket();

        // Parse the URL to get the file path
        // This is a simplified version - you may need more robust parsing
        const urlParts = downloadURL.split("/o/");
        if (urlParts.length > 1) {
          const encodedPath = urlParts[1].split("?")[0];
          const filePath = decodeURIComponent(encodedPath);

          // Delete file from Storage
          await bucket.file(filePath).delete();

          console.log(`Deleted file: ${filePath}`);
        }

        // If there's a thumbnail, delete it too
        if (messageData.fileMetadata.thumbnailURL) {
          const thumbnailURL = messageData.fileMetadata.thumbnailURL;
          const thumbnailParts = thumbnailURL.split("/o/");
          if (thumbnailParts.length > 1) {
            const encodedPath = thumbnailParts[1].split("?")[0];
            const thumbnailPath = decodeURIComponent(encodedPath);
            await bucket.file(thumbnailPath).delete();
            console.log(`Deleted thumbnail: ${thumbnailPath}`);
          }
        }
      } catch (error) {
        console.error("Error deleting file from Storage:", error);
        // Don't throw - we don't want to block message deletion
      }
    }
  });

/**
 * Scheduled cleanup for old files
 * Runs daily to clean up files older than 90 days
 */
export const scheduledFileCleanup = functions.pubsub
  .schedule("0 2 * * *") // Run at 2 AM every day
  .onRun(async (context) => {
    const db = admin.firestore();
    const storage = admin.storage();
    const bucket = storage.bucket();

    // Calculate cutoff date (90 days ago)
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 90);

    try {
      // Query all messages with files older than 90 days
      const oldMessagesSnapshot = await db
        .collectionGroup("messages")
        .where("type", "==", "file")
        .where(
          "fileMetadata.uploadedAt",
          "<",
          admin.firestore.Timestamp.fromDate(cutoffDate)
        )
        .get();

      console.log(`Found ${oldMessagesSnapshot.size} old file messages to clean up`);

      let deletedCount = 0;
      const batchSize = 500; // Firestore batch limit
      let batch = db.batch();
      let batchCount = 0;

      for (const doc of oldMessagesSnapshot.docs) {
        const messageData = doc.data();

        if (messageData.fileMetadata?.downloadURL) {
          try {
            // Delete file from Storage
            const downloadURL = messageData.fileMetadata.downloadURL;
            const urlParts = downloadURL.split("/o/");
            if (urlParts.length > 1) {
              const encodedPath = urlParts[1].split("?")[0];
              const filePath = decodeURIComponent(encodedPath);
              await bucket.file(filePath).delete();

              // Delete thumbnail if exists
              if (messageData.fileMetadata.thumbnailURL) {
                const thumbnailURL = messageData.fileMetadata.thumbnailURL;
                const thumbnailParts = thumbnailURL.split("/o/");
                if (thumbnailParts.length > 1) {
                  const encodedPath = thumbnailParts[1].split("?")[0];
                  const thumbnailPath = decodeURIComponent(encodedPath);
                  await bucket.file(thumbnailPath).delete();
                }
              }

              deletedCount++;
            }

            // Delete message document
            batch.delete(doc.ref);
            batchCount++;

            // Commit batch if we've reached the limit
            if (batchCount >= batchSize) {
              await batch.commit();
              batch = db.batch();
              batchCount = 0;
            }
          } catch (error) {
            console.error(`Error deleting file for message ${doc.id}:`, error);
          }
        }
      }

      // Commit any remaining deletions
      if (batchCount > 0) {
        await batch.commit();
      }

      console.log(`Cleanup complete. Deleted ${deletedCount} old files.`);

      return {
        success: true,
        deletedCount,
      };
    } catch (error) {
      console.error("Error in scheduled file cleanup:", error);
      throw error;
    }
  });

