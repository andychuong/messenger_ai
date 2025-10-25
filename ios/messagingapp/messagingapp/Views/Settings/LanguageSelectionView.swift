//
//  LanguageSelectionView.swift
//  messagingapp
//
//  Language selection view for translation preferences
//

import SwiftUI

struct LanguageSelectionView: View {
    @Binding var selectedLanguage: String?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.all
        }
        return Language.all.filter { language in
            language.name.localizedCaseInsensitiveContains(searchText) ||
            language.nativeName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List {
            // None option
            Section {
                Button {
                    selectedLanguage = nil
                    HapticManager.shared.selection()
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedLanguage == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Common languages
            if searchText.isEmpty {
                Section("Common Languages") {
                    ForEach(Language.common) { language in
                        languageRow(language)
                    }
                }
                
                Section("All Languages") {
                    ForEach(Language.all.filter { !Language.common.contains($0) }) { language in
                        languageRow(language)
                    }
                }
            } else {
                // Search results
                Section {
                    ForEach(filteredLanguages) { language in
                        languageRow(language)
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search languages")
        .navigationTitle("Preferred Language")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func languageRow(_ language: Language) -> some View {
        Button {
            selectedLanguage = language.name
            HapticManager.shared.selection()
            dismiss()
        } label: {
            HStack {
                Text(language.emoji)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .foregroundColor(.primary)
                    Text(language.nativeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if selectedLanguage == language.name {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LanguageSelectionView(selectedLanguage: .constant("Spanish"))
    }
}

