import SwiftUI

/// Overlay view to display translated text with toggle between original and translated
struct TranslationOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showOriginal = false
    
    let originalText: String
    let translatedText: String
    let targetLanguage: String
    let fromCache: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Cache indicator
                    if fromCache {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                            Text("Loaded from cache")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    }
                    
                    // Language info
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text("Translated to \(targetLanguage)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        // Toggle button
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showOriginal.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.2.squarepath")
                                    .font(.caption)
                                Text(showOriginal ? "Show Translation" : "Show Original")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Text content
                    VStack(alignment: .leading, spacing: 12) {
                        if showOriginal {
                            // Original text
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Original")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(originalText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                        } else {
                            // Translated text
                            VStack(alignment: .leading, spacing: 8) {
                                Text(targetLanguage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                Text(translatedText)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.3), value: showOriginal)
                    
                    Spacer()
                    
                    // Copy button
                    Button {
                        UIPasteboard.general.string = showOriginal ? originalText : translatedText
                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "doc.on.doc")
                            Text("Copy \(showOriginal ? "Original" : "Translation")")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .padding(.vertical)
            }
            .navigationTitle("Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TranslationOverlayView(
        originalText: "Hello, how are you doing today?",
        translatedText: "Hola, ¿cómo estás hoy?",
        targetLanguage: "Spanish",
        fromCache: false
    )
}

