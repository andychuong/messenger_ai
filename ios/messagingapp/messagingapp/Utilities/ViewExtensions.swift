//
//  ViewExtensions.swift
//  messagingapp
//
//  SwiftUI View extensions and helpers
//

import SwiftUI

extension View {
    /// Hides the view while keeping it in the view hierarchy
    /// Useful for maintaining layout while making a view invisible
    @ViewBuilder
    func hidden(_ shouldHide: Bool = true) -> some View {
        if shouldHide {
            self.opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        } else {
            self
        }
    }
}

