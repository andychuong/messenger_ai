//
//  ImageService.swift
//  messagingapp
//
//  Phase 4: Rich Messaging Features
//  Image picking, compression, and Firebase Storage upload
//

import Foundation
import SwiftUI
import UIKit
import FirebaseStorage
import FirebaseAuth
import PhotosUI

class ImageService {
    
    private let storage = Storage.storage()
    private let messageService = MessageService()
    
    // MARK: - Pick Image
    
    /// Get PHPickerConfiguration for image selection
    static func getPickerConfiguration() -> PHPickerConfiguration {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        return config
    }
    
    // MARK: - Compress Image
    
    /// Compress image to reduce file size
    /// - Parameters:
    ///   - image: The UIImage to compress
    ///   - maxSizeKB: Maximum size in kilobytes (default 500KB)
    /// - Returns: Compressed image data
    func compressImage(_ image: UIImage, maxSizeKB: Int = 500) -> Data? {
        let maxBytes = maxSizeKB * 1024
        var compression: CGFloat = 0.9
        var imageData = image.jpegData(compressionQuality: compression)
        
        // Progressively reduce quality until under max size
        while let data = imageData, data.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        // If still too large, resize the image
        if let data = imageData, data.count > maxBytes {
            let newSize = calculateResizedSize(for: image.size, maxBytes: maxBytes)
            if let resizedImage = resizeImage(image, to: newSize) {
                imageData = resizedImage.jpegData(compressionQuality: 0.8)
            }
        }
        
        return imageData
    }
    
    /// Resize image to new size
    private func resizeImage(_ image: UIImage, to newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Calculate appropriate resize dimensions
    private func calculateResizedSize(for currentSize: CGSize, maxBytes: Int) -> CGSize {
        let ratio = currentSize.width / currentSize.height
        let maxDimension: CGFloat = 1024 // Max 1024px on longest side
        
        if currentSize.width > currentSize.height {
            let width = min(currentSize.width, maxDimension)
            return CGSize(width: width, height: width / ratio)
        } else {
            let height = min(currentSize.height, maxDimension)
            return CGSize(width: height * ratio, height: height)
        }
    }
    
    // MARK: - Upload to Firebase Storage
    
    /// Upload image to Firebase Storage
    /// - Parameters:
    ///   - imageData: Compressed image data
    ///   - conversationId: Conversation the image belongs to
    /// - Returns: Download URL of uploaded image
    func uploadImage(_ imageData: Data, conversationId: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw ImageServiceError.notAuthenticated
        }
        
        // Create unique filename
        let filename = "\(UUID().uuidString).jpg"
        let path = "images/\(conversationId)/\(filename)"
        
        // Create storage reference
        let storageRef = storage.reference().child(path)
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "uploadedBy": userId,
            "conversationId": conversationId,
            "uploadedAt": "\(Date().timeIntervalSince1970)"
        ]
        
        // Upload
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await storageRef.downloadURL()
        return downloadURL.absoluteString
    }
    
    // MARK: - Send Image Message
    
    /// Pick, compress, upload, and send image message
    /// - Parameters:
    ///   - image: The UIImage to send
    ///   - conversationId: Conversation to send image to
    ///   - caption: Optional text caption
    /// - Returns: Created message with image URL
    @discardableResult
    func sendImageMessage(
        image: UIImage,
        conversationId: String,
        caption: String? = nil
    ) async throws -> Message {
        // Compress image
        guard let imageData = compressImage(image) else {
            throw ImageServiceError.compressionFailed
        }
        
        // Upload to storage
        let imageURL = try await uploadImage(imageData, conversationId: conversationId)
        
        // Create message with image
        let message = try await messageService.sendImageMessage(
            conversationId: conversationId,
            imageURL: imageURL,
            caption: caption
        )
        
        return message
    }
    
    // MARK: - Download Image
    
    /// Download image from URL
    /// - Parameter urlString: Image URL
    /// - Returns: Downloaded UIImage
    func downloadImage(from urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString) else {
            throw ImageServiceError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw ImageServiceError.invalidImageData
        }
        
        return image
    }
    
    // MARK: - Delete Image
    
    /// Delete image from Firebase Storage
    /// - Parameter urlString: Image URL to delete
    func deleteImage(urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw ImageServiceError.invalidURL
        }
        
        // Extract path from URL
        let storageRef = try storage.reference(for: url)
        try await storageRef.delete()
    }
}

// MARK: - Image Service Error

enum ImageServiceError: LocalizedError {
    case notAuthenticated
    case compressionFailed
    case uploadFailed
    case invalidURL
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to upload images"
        case .compressionFailed:
            return "Failed to compress image"
        case .uploadFailed:
            return "Failed to upload image"
        case .invalidURL:
            return "Invalid image URL"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

// MARK: - Image Picker Representable

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        let config = ImageService.getPickerConfiguration()
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                return
            }
            
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    self?.parent.image = image as? UIImage
                }
            }
        }
    }
}

