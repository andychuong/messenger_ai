//
//  EncryptedImageView.swift
//  messagingapp
//
//  Custom view for displaying encrypted images from Firebase Storage
//

import SwiftUI

/// Image cache for encrypted images
class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100 // Store up to 100 images
        cache.totalCostLimit = 1024 * 1024 * 100 // 100MB limit
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        print("⚠️ Memory warning received - clearing image cache")
        clear()
    }
    
    func get(_ key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct EncryptedImageView: View {
    let url: String
    let conversationId: String
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var loadTask: Task<Void, Never>?
    
    private let imageService = ImageService()
    private let imageCache = ImageCache.shared
    
    var body: some View {
        ZStack {
            if isLoading {
                loadingView
            } else if let error = loadError {
                errorView(error)
            } else if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: maxWidth, maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                errorView(nil)
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .onAppear {
            startLoadingImage()
        }
        .onDisappear {
            // Cancel the task if view disappears
            loadTask?.cancel()
            loadTask = nil
        }
        .id(url) // Force reload if URL changes
    }
    
    private var loadingView: some View {
        ZStack {
            Color(.systemGray6)
            ProgressView()
                .tint(.blue)
        }
        .frame(width: maxWidth, height: maxHeight)
        .cornerRadius(12)
    }
    
    private func errorView(_ error: Error?) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("Failed to load image")
                .font(.caption)
                .foregroundColor(.gray)
            if let error = error {
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: maxWidth, height: maxHeight)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func startLoadingImage() {
        // Cancel any existing task
        loadTask?.cancel()
        
        // Check cache first
        if let cachedImage = imageCache.get(url) {
            self.image = cachedImage
            self.isLoading = false
            print("✅ Loaded image from cache: \(url)")
            return
        }
        
        // Start new loading task
        loadTask = Task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Check if task was cancelled
        guard !Task.isCancelled else {
            print("⚠️ Image load cancelled: \(url)")
            return
        }
        
        do {
            // Download and decrypt the image
            let downloadedImage = try await imageService.downloadImage(
                from: url,
                conversationId: conversationId
            )
            
            // Check again if task was cancelled before updating state
            guard !Task.isCancelled else {
                print("⚠️ Image load cancelled after download: \(url)")
                return
            }
            
            // Cache the image
            imageCache.set(downloadedImage, forKey: url)
            
            await MainActor.run {
                self.image = downloadedImage
                self.isLoading = false
            }
            
            print("✅ Loaded and cached encrypted image: \(url)")
        } catch {
            // Check if task was cancelled
            guard !Task.isCancelled else {
                print("⚠️ Image load cancelled during error handling: \(url)")
                return
            }
            
            print("❌ Failed to load encrypted image: \(error.localizedDescription)")
            
            // Try legacy unencrypted download as fallback
            do {
                let downloadedImage = try await imageService.downloadImageLegacy(from: url)
                
                guard !Task.isCancelled else {
                    print("⚠️ Image load cancelled during legacy fallback: \(url)")
                    return
                }
                
                // Cache the image
                imageCache.set(downloadedImage, forKey: url)
                
                await MainActor.run {
                    self.image = downloadedImage
                    self.isLoading = false
                }
                print("✅ Loaded legacy unencrypted image: \(url)")
            } catch {
                guard !Task.isCancelled else {
                    print("⚠️ Image load cancelled during legacy error: \(url)")
                    return
                }
                
                print("❌ Failed to load legacy image: \(error.localizedDescription)")
                await MainActor.run {
                    self.loadError = error
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    EncryptedImageView(
        url: "https://example.com/image.enc",
        conversationId: "conv123",
        maxWidth: 250,
        maxHeight: 300
    )
    .padding()
}

