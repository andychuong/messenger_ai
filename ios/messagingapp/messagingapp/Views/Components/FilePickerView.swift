//
//  FilePickerView.swift
//  messagingapp
//
//  Document picker integration for file attachments
//

import SwiftUI
import UniformTypeIdentifiers

struct FilePickerView: UIViewControllerRepresentable {
    @Binding var selectedFileURL: URL?
    @Binding var isPresented: Bool
    var onFilePicked: ((URL) -> Void)?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: SupportedFileTypes.allSupported,
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePickerView
        
        init(_ parent: FilePickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            parent.selectedFileURL = url
            parent.onFilePicked?(url)
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// File Selection Sheet with Preview
struct FileSelectionSheet: View {
    @Binding var isPresented: Bool
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var fileInfo: FileInfo?
    @State private var isValidating = false
    @State private var validationError: String?
    
    var onFileSelected: (URL) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let fileInfo = fileInfo {
                    // File Preview
                    filePreviewSection(fileInfo)
                } else {
                    // File picker button
                    emptyStateSection
                }
            }
            .navigationTitle("Attach File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                if fileInfo != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Send") {
                            if let url = selectedFileURL {
                                onFileSelected(url)
                                isPresented = false
                            }
                        }
                        .disabled(validationError != nil)
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                FilePickerView(
                    selectedFileURL: $selectedFileURL,
                    isPresented: $showingFilePicker,
                    onFilePicked: { url in
                        validateAndLoadFile(url)
                    }
                )
            }
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("Select a file to send")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("You can send documents, PDFs, spreadsheets, and more")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                showingFilePicker = true
            }) {
                Label("Browse Files", systemImage: "folder")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
    }
    
    private func filePreviewSection(_ info: FileInfo) -> some View {
        VStack(spacing: 20) {
            // File icon and info
            VStack(spacing: 16) {
                // File icon
                ZStack {
                    Circle()
                        .fill(categoryColor(for: info.category))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: info.category.iconName)
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                
                // File name
                Text(info.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // File size
                Text(info.formattedSize)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // File type
                Text(info.category.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(categoryColor(for: info.category).opacity(0.2))
                    .foregroundColor(categoryColor(for: info.category))
                    .cornerRadius(8)
            }
            .padding(.top, 32)
            
            if isValidating {
                ProgressView("Validating file...")
                    .padding()
            } else if let error = validationError {
                // Error message
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
            } else {
                // Size warning if file is large
                if info.isLarge {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("This is a large file (\(info.formattedSize)). It may take longer to send.")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Change file button
            Button(action: {
                selectedFileURL = nil
                fileInfo = nil
                validationError = nil
                showingFilePicker = true
            }) {
                Label("Choose Different File", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 32)
        }
    }
    
    private func validateAndLoadFile(_ url: URL) {
        isValidating = true
        validationError = nil
        
        Task {
            do {
                // Validate file
                try FileService.shared.validateFile(url)
                
                // Get file info
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                let fileName = url.lastPathComponent
                let fileExtension = url.pathExtension.lowercased()
                
                // Check size limit
                if FileService.shared.exceedsSizeLimit(fileSize) {
                    await MainActor.run {
                        validationError = "File is too large. Maximum size is 10 MB"
                        isValidating = false
                    }
                    return
                }
                
                // Create file info
                let category = FileCategory.from(
                    mimeType: getMimeType(for: url),
                    extension: fileExtension
                )
                
                let info = FileInfo(
                    name: fileName,
                    size: fileSize,
                    category: category,
                    isLarge: FileService.shared.isLargeFile(fileSize)
                )
                
                await MainActor.run {
                    fileInfo = info
                    isValidating = false
                }
                
            } catch {
                await MainActor.run {
                    validationError = error.localizedDescription
                    isValidating = false
                }
            }
        }
    }
    
    private func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension
        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
    
    private func categoryColor(for category: FileCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

struct FileInfo {
    let name: String
    let size: Int64
    let category: FileCategory
    let isLarge: Bool
    
    var formattedSize: String {
        let bytes = Double(size)
        
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            let kb = bytes / 1024
            return String(format: "%.1f KB", kb)
        } else if bytes < 1024 * 1024 * 1024 {
            let mb = bytes / (1024 * 1024)
            return String(format: "%.1f MB", mb)
        } else {
            let gb = bytes / (1024 * 1024 * 1024)
            return String(format: "%.1f GB", gb)
        }
    }
}

