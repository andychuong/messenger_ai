//
//  ColorGenerator.swift
//  messagingapp
//
//  Generates consistent colors for users based on their ID
//

import SwiftUI

struct ColorGenerator {
    /// Predefined color palette for user avatars
    private static let colorPalette: [Color] = [
        Color(red: 0.2, green: 0.6, blue: 0.86),  // Blue
        Color(red: 0.3, green: 0.69, blue: 0.31), // Green
        Color(red: 1.0, green: 0.6, blue: 0.0),   // Orange
        Color(red: 0.61, green: 0.15, blue: 0.69),// Purple
        Color(red: 0.91, green: 0.12, blue: 0.39),// Pink
        Color(red: 0.0, green: 0.74, blue: 0.83), // Cyan
        Color(red: 1.0, green: 0.34, blue: 0.13), // Deep Orange
        Color(red: 0.4, green: 0.23, blue: 0.72), // Deep Purple
        Color(red: 0.98, green: 0.75, blue: 0.18),// Amber
        Color(red: 0.0, green: 0.59, blue: 0.53), // Teal
    ]
    
    /// Generate a consistent color for a user based on their ID
    /// - Parameter userId: User ID to generate color for
    /// - Returns: A color from the palette
    static func color(for userId: String) -> Color {
        // Use deterministic hash of userId to get consistent color
        // hashValue is not stable across app launches, so we create our own
        let hash = userId.utf8.reduce(0) { result, byte in
            (result &+ Int(byte) &* 31) & 0x7FFFFFFF
        }
        let index = hash % colorPalette.count
        return colorPalette[index]
    }
    
    /// Generate initials from a name
    /// - Parameter name: Full name
    /// - Returns: Up to 2 character initials
    static func initials(from name: String) -> String {
        let components = name.split(separator: " ")
        
        if components.count >= 2 {
            // First name + Last name
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        } else if let first = components.first {
            // Just first initial
            return String(first.prefix(1)).uppercased()
        }
        
        return "?"
    }
}

