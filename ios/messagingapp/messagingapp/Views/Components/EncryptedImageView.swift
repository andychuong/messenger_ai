//
//  EncryptedImageView.swift
//  messagingapp
//
//  Custom view for displaying encrypted images from Firebase Storage
//

import SwiftUI

struct EncryptedImageView: View {
    let url: String
    let conversationId: String
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    private let imageService = ImageService()
    
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
        .task {
            await loadImage()
        }
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
    
    private func loadImage() async {
        do {
            // Download and decrypt the image
            let downloadedImage = try await imageService.downloadImage(
                from: url,
                conversationId: conversationId
            )
            
            await MainActor.run {
                self.image = downloadedImage
                self.isLoading = false
            }
        } catch {
            print("❌ Failed to load encrypted image: \(error.localizedDescription)")
            
            // Try legacy unencrypted download as fallback
            do {
                let downloadedImage = try await imageService.downloadImageLegacy(from: url)
                await MainActor.run {
                    self.image = downloadedImage
                    self.isLoading = false
                }
                print("✅ Loaded legacy unencrypted image")
            } catch {
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

