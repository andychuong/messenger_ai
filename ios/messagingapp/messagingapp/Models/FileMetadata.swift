//
//  FileMetadata.swift
//  messagingapp
//

import Foundation
import UniformTypeIdentifiers

struct FileMetadata: Codable, Hashable {
    var fileName: String
    var fileSize: Int64  // in bytes
    var mimeType: String
    var thumbnailURL: String?
    var downloadURL: String
    var uploadedBy: String
    var uploadedAt: Date
    var isEncrypted: Bool
    var encryptionKeyId: String?
    var metadata: AdditionalMetadata?
    
    enum CodingKeys: String, CodingKey {
        case fileName
        case fileSize
        case mimeType
        case thumbnailURL
        case downloadURL
        case uploadedBy
        case uploadedAt
        case isEncrypted
        case encryptionKeyId
        case metadata
    }
}

struct AdditionalMetadata: Codable, Hashable {
    var pages: Int?
    var author: String?
    var createdDate: String?
    
    enum CodingKeys: String, CodingKey {
        case pages
        case author
        case createdDate
    }
}

// Extension for FileMetadata helpers
extension FileMetadata {
    // Format file size for display
    func formattedFileSize() -> String {
        let bytes = Double(fileSize)
        
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
    
    // Get file extension
    var fileExtension: String {
        return (fileName as NSString).pathExtension.lowercased()
    }
    
    // Get file type category
    var fileCategory: FileCategory {
        return FileCategory.from(mimeType: mimeType, extension: fileExtension)
    }
    
    // Check if file is too large (for warnings)
    var isLargeFile: Bool {
        return fileSize > 5 * 1024 * 1024  // > 5 MB
    }
    
    // Check if file exceeds size limit
    func exceedsSizeLimit(maxSize: Int64 = 10 * 1024 * 1024) -> Bool {
        return fileSize > maxSize
    }
}

enum FileCategory: String {
    case document
    case spreadsheet
    case presentation
    case pdf
    case text
    case archive
    case code
    case other
    
    static func from(mimeType: String, extension fileExtension: String) -> FileCategory {
        // Check by MIME type
        if mimeType.hasPrefix("application/pdf") {
            return .pdf
        } else if mimeType.contains("document") || mimeType.contains("msword") {
            return .document
        } else if mimeType.contains("spreadsheet") || mimeType.contains("excel") {
            return .spreadsheet
        } else if mimeType.contains("presentation") || mimeType.contains("powerpoint") {
            return .presentation
        } else if mimeType.hasPrefix("text/") {
            return .text
        } else if mimeType.contains("zip") || mimeType.contains("archive") || mimeType.contains("compressed") {
            return .archive
        }
        
        // Check by file extension
        switch fileExtension {
        case "pdf":
            return .pdf
        case "doc", "docx", "pages", "odt":
            return .document
        case "xls", "xlsx", "numbers", "ods":
            return .spreadsheet
        case "ppt", "pptx", "key", "odp":
            return .presentation
        case "txt", "rtf", "md":
            return .text
        case "zip", "rar", "7z", "tar", "gz":
            return .archive
        case "swift", "js", "py", "java", "kt", "cpp", "c", "h", "m", "ts", "tsx", "jsx":
            return .code
        default:
            return .other
        }
    }
    
    // Get system icon name for file category
    var iconName: String {
        switch self {
        case .document:
            return "doc.text"
        case .spreadsheet:
            return "tablecells"
        case .presentation:
            return "rectangle.on.rectangle.angled"
        case .pdf:
            return "doc.richtext"
        case .text:
            return "doc.plaintext"
        case .archive:
            return "doc.zipper"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .other:
            return "doc"
        }
    }
    
    // Get color for file category
    var color: String {
        switch self {
        case .document:
            return "blue"
        case .spreadsheet:
            return "green"
        case .presentation:
            return "orange"
        case .pdf:
            return "red"
        case .text:
            return "gray"
        case .archive:
            return "purple"
        case .code:
            return "indigo"
        case .other:
            return "gray"
        }
    }
}

// Supported file types
struct SupportedFileTypes {
    static let documents: [UTType] = [
        .pdf,
        .plainText,
        .rtf,
        UTType(filenameExtension: "doc") ?? .data,
        UTType(filenameExtension: "docx") ?? .data,
        UTType(filenameExtension: "xls") ?? .data,
        UTType(filenameExtension: "xlsx") ?? .data,
        UTType(filenameExtension: "ppt") ?? .data,
        UTType(filenameExtension: "pptx") ?? .data,
        UTType(filenameExtension: "pages") ?? .data,
        UTType(filenameExtension: "numbers") ?? .data,
        UTType(filenameExtension: "key") ?? .data
    ]
    
    static let archives: [UTType] = [
        .zip,
        UTType(filenameExtension: "rar") ?? .data,
        UTType(filenameExtension: "7z") ?? .data
    ]
    
    static let text: [UTType] = [
        .plainText,
        .rtf,
        UTType(filenameExtension: "md") ?? .data,
        .json,
        .xml,
        .commaSeparatedText  // CSV has a built-in UTType
    ]
    
    static let code: [UTType] = [
        .swiftSource,
        .cSource,
        .cPlusPlusSource,
        .javaScript,
        UTType(filenameExtension: "py") ?? .data,  // Python files
        UTType(filenameExtension: "ts") ?? .data,
        UTType(filenameExtension: "tsx") ?? .data,
        UTType(filenameExtension: "jsx") ?? .data
    ]
    
    static var allSupported: [UTType] {
        return documents + archives + text + code
    }
}

