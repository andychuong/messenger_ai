//
//  FileService.swift
//  messagingapp
//
//  Phase 19: File Attachments
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import UniformTypeIdentifiers
import UIKit

enum FileServiceError: LocalizedError {
    case invalidFile
    case fileTooLarge(maxSize: Int64)
    case unsupportedFileType
    case uploadFailed(Error)
    case downloadFailed(Error)
    case encryptionFailed
    case thumbnailGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "The selected file is invalid"
        case .fileTooLarge(let maxSize):
            let mb = Double(maxSize) / (1024 * 1024)
            return "File is too large. Maximum size is \(String(format: "%.0f", mb)) MB"
        case .unsupportedFileType:
            return "This file type is not supported"
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .encryptionFailed:
            return "Failed to encrypt file"
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail"
        }
    }
}

class FileService {
    static let shared = FileService()
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private let encryptionService = EncryptionService.shared
    
    // Size limits
    private let freeTierMaxSize: Int64 = 10 * 1024 * 1024  // 10 MB
    private let premiumMaxSize: Int64 = 100 * 1024 * 1024  // 100 MB
    private let warningSize: Int64 = 5 * 1024 * 1024  // 5 MB
    
    private init() {}
    
    // MARK: - Upload
    
    /// Upload a file to Firebase Storage
    func uploadFile(
        _ fileURL: URL,
        to conversationId: String,
        encrypted: Bool,
        userId: String,
        onProgress: @escaping (Double) -> Void = { _ in }
    ) async throws -> FileMetadata {
        // Start accessing security-scoped resource
        let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Validate file
        try validateFile(fileURL)
        
        // Get file info
        let fileName = fileURL.lastPathComponent
        let fileSize = try getFileSize(fileURL)
        let mimeType = getMimeType(for: fileURL)
        
        // Check size limit
        let maxSize = freeTierMaxSize  // TODO: Check user tier
        if fileSize > maxSize {
            throw FileServiceError.fileTooLarge(maxSize: maxSize)
        }
        
        // Prepare file data
        var fileData = try Data(contentsOf: fileURL)
        var encryptionKeyId: String? = nil
        
        // Encrypt if needed
        if encrypted {
            do {
                fileData = try await encryptionService.encryptFile(fileData, conversationId: conversationId)
                encryptionKeyId = conversationId  // Use conversation ID as key ID
            } catch {
                throw FileServiceError.encryptionFailed
            }
        }
        
        // Determine storage path based on file category
        let category = FileCategory.from(mimeType: mimeType, extension: (fileName as NSString).pathExtension.lowercased())
        let storagePath = "conversations/\(conversationId)/files/\(category.rawValue)/\(UUID().uuidString)_\(fileName)"
        
        // Create storage reference
        let storageRef = storage.reference().child(storagePath)
        
        // Set metadata
        let metadata = StorageMetadata()
        // For encrypted files, use octet-stream; otherwise use original MIME type
        metadata.contentType = encrypted ? "application/octet-stream" : mimeType
        
        // Upload file
        let uploadMetadata: StorageMetadata
        let downloadURL: URL
        
        do {
            // Signal upload start
            onProgress(0.0)
            
            // Upload and wait for completion
            uploadMetadata = try await storageRef.putDataAsync(fileData, metadata: metadata)
            
            // Signal upload complete
            onProgress(1.0)
            
            // Small delay to ensure Firebase has processed the file
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Get download URL
            downloadURL = try await storageRef.downloadURL()
            
            // Generate thumbnail if possible
            var thumbnailURL: String? = nil
            if category == .document || category == .pdf {
                thumbnailURL = try? await generateThumbnail(for: fileURL, storagePath: storagePath)
            }
            
            // Extract additional metadata
            let additionalMetadata = extractMetadata(from: fileURL, category: category)
            
            // Create FileMetadata object
            let fileMetadata = FileMetadata(
                fileName: fileName,
                fileSize: fileSize,
                mimeType: mimeType,
                thumbnailURL: thumbnailURL,
                downloadURL: downloadURL.absoluteString,
                uploadedBy: userId,
                uploadedAt: Date(),
                isEncrypted: encrypted,
                encryptionKeyId: encryptionKeyId,
                metadata: additionalMetadata
            )
            
            return fileMetadata
            
        } catch {
            // Try to clean up the partially uploaded file
            try? await storageRef.delete()
            throw FileServiceError.uploadFailed(error)
        }
    }
    
    // MARK: - Download
    
    /// Download a file from Firebase Storage
    func downloadFile(
        messageId: String,
        fileMetadata: FileMetadata,
        conversationId: String,
        onProgress: @escaping (Double) -> Void = { _ in }
    ) async throws -> URL {
        // Check if file is already cached
        if let cachedURL = getCachedFileURL(for: messageId, fileName: fileMetadata.fileName) {
            return cachedURL
        }
        
        // Create storage reference from download URL
        let storageRef = try storage.reference(forURL: fileMetadata.downloadURL)
        
        // Create temporary file URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let localURL = tempDirectory.appendingPathComponent("\(messageId)_\(fileMetadata.fileName)")
        
        // Download file
        let downloadTask = storageRef.write(toFile: localURL)
        
        // Monitor download progress
        downloadTask.observe(.progress) { snapshot in
            if let progress = snapshot.progress {
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                onProgress(percentComplete)
            }
        }
        
        // Wait for download to complete
        _ = try await downloadTask
        
        // Decrypt if needed
        if fileMetadata.isEncrypted {
            do {
                let encryptedData = try Data(contentsOf: localURL)
                let decryptedData = try await encryptionService.decryptFile(encryptedData, conversationId: conversationId)
                try decryptedData.write(to: localURL)
            } catch {
                throw FileServiceError.encryptionFailed
            }
        }
        
        // Cache file
        cacheFile(at: localURL, for: messageId, fileName: fileMetadata.fileName)
        
        return localURL
    }
    
    // MARK: - Validation
    
    /// Validate a file before upload
    func validateFile(_ fileURL: URL) throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw FileServiceError.invalidFile
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw FileServiceError.invalidFile
        }
        
        // Check file type
        let fileExtension = fileURL.pathExtension.lowercased()
        let mimeType = getMimeType(for: fileURL)
        
        // Validate against supported types
        let supportedExtensions = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", 
                                   "txt", "rtf", "md", "pages", "numbers", "key",
                                   "zip", "rar", "7z", "csv", "json", "xml",
                                   "swift", "js", "py", "java", "kt", "ts", "tsx", "jsx"]
        
        if !supportedExtensions.contains(fileExtension) && !mimeType.hasPrefix("application/") && !mimeType.hasPrefix("text/") {
            throw FileServiceError.unsupportedFileType
        }
    }
    
    // MARK: - Helpers
    
    private func getFileSize(_ fileURL: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func getMimeType(for fileURL: URL) -> String {
        let pathExtension = fileURL.pathExtension
        
        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        
        return "application/octet-stream"
    }
    
    private func extractMetadata(from fileURL: URL, category: FileCategory) -> AdditionalMetadata? {
        // For now, return nil. In a production app, you would use PDFKit or other frameworks
        // to extract metadata like page count, author, etc.
        return nil
    }
    
    private func generateThumbnail(for fileURL: URL, storagePath: String) async throws -> String? {
        // For now, return nil. In production, you would:
        // 1. Generate thumbnail using PDFKit or QuickLook
        // 2. Upload thumbnail to Storage
        // 3. Return thumbnail URL
        return nil
    }
    
    // MARK: - Caching
    
    private func getCachedFileURL(for messageId: String, fileName: String) -> URL? {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let fileURL = cacheDirectory.appendingPathComponent("files/\(messageId)_\(fileName)")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        return nil
    }
    
    private func cacheFile(at sourceURL: URL, for messageId: String, fileName: String) {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let filesDirectory = cacheDirectory.appendingPathComponent("files")
        
        // Create files directory if it doesn't exist
        try? FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
        
        let destinationURL = filesDirectory.appendingPathComponent("\(messageId)_\(fileName)")
        
        // Copy file to cache
        try? FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }
    
    /// Clear cached files older than 7 days
    func clearOldCache() {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let filesDirectory = cacheDirectory.appendingPathComponent("files")
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: filesDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        
        for fileURL in files {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < sevenDaysAgo {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    // MARK: - Size Checks
    
    func isLargeFile(_ fileSize: Int64) -> Bool {
        return fileSize > warningSize
    }
    
    func exceedsSizeLimit(_ fileSize: Int64, isPremium: Bool = false) -> Bool {
        let maxSize = isPremium ? premiumMaxSize : freeTierMaxSize
        return fileSize > maxSize
    }
    
    var supportedFileTypes: [UTType] {
        return SupportedFileTypes.allSupported
    }
}

