//
//  FilePreviewView.swift
//  messagingapp
//
//  Phase 19: File Attachments - Quick Look file preview
//

import SwiftUI
import QuickLook

struct FilePreviewView: UIViewControllerRepresentable {
    let fileURL: URL
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let parent: FilePreviewView
        
        init(_ parent: FilePreviewView) {
            self.parent = parent
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.fileURL as NSURL
        }
        
        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            parent.isPresented = false
        }
    }
}

// File Preview Sheet with Download Progress
struct FilePreviewSheet: View {
    let messageId: String
    let fileMetadata: FileMetadata
    let conversationId: String
    @Binding var isPresented: Bool
    
    @State private var fileURL: URL?
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var downloadError: String?
    @State private var showingPreview = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isDownloading {
                    downloadingView
                } else if let error = downloadError {
                    errorView(error)
                } else if fileURL != nil {
                    fileReadyView
                } else {
                    downloadPromptView
                }
            }
            .navigationTitle("File Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                
                if fileURL != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(action: shareFile) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            Button(action: saveFile) {
                                Label("Save to Files", systemImage: "arrow.down.doc")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPreview) {
                if let url = fileURL {
                    FilePreviewView(fileURL: url, isPresented: $showingPreview)
                }
            }
        }
        .onAppear {
            downloadFile()
        }
    }
    
    private var downloadPromptView: some View {
        VStack(spacing: 24) {
            // File icon
            ZStack {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 80, height: 80)
                
                Image(systemName: fileMetadata.fileCategory.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            
            // File info
            Text(fileMetadata.fileName)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(fileMetadata.formattedFileSize())
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Download button
            Button(action: downloadFile) {
                Label("Download File", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
    
    private var downloadingView: some View {
        VStack(spacing: 24) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: downloadProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: downloadProgress)
                
                Text("\(Int(downloadProgress * 100))%")
                    .font(.headline)
            }
            
            Text("Downloading...")
                .font(.headline)
            
            Text(fileMetadata.fileName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            Text("Download Failed")
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                downloadError = nil
                downloadFile()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var fileReadyView: some View {
        VStack(spacing: 24) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
            
            Text("File Ready")
                .font(.headline)
            
            Text(fileMetadata.fileName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Preview button
            Button(action: {
                showingPreview = true
            }) {
                Label("Open Preview", systemImage: "eye.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
    
    private var categoryColor: Color {
        switch fileMetadata.fileCategory.color {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "indigo": return .indigo
        default: return .gray
        }
    }
    
    private func downloadFile() {
        isDownloading = true
        downloadProgress = 0.0
        
        Task {
            do {
                let url = try await FileService.shared.downloadFile(
                    messageId: messageId,
                    fileMetadata: fileMetadata,
                    conversationId: conversationId,
                    onProgress: { progress in
                        Task { @MainActor in
                            downloadProgress = progress
                        }
                    }
                )
                
                await MainActor.run {
                    fileURL = url
                    isDownloading = false
                }
                
            } catch {
                await MainActor.run {
                    downloadError = error.localizedDescription
                    isDownloading = false
                }
            }
        }
    }
    
    private func shareFile() {
        guard let url = fileURL else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func saveFile() {
        guard let url = fileURL else { return }
        
        // Present document picker to save file
        let picker = UIDocumentPickerViewController(forExporting: [url])
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(picker, animated: true)
        }
    }
}

