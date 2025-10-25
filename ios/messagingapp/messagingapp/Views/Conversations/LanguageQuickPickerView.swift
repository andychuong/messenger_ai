//
//  LanguageQuickPickerView.swift
//  messagingapp
//
//  Quick language picker for auto-translation
//

import SwiftUI

struct LanguageQuickPickerView: View {
    let currentLanguage: String?
    let autoTranslateEnabled: Bool
    let onLanguageSelected: (String?) -> Void
    
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
        NavigationView {
            List {
                // Current status section
                Section {
                    HStack {
                        Image(systemName: "translate")
                            .foregroundColor(autoTranslateEnabled ? .blue : .gray)
                        Text("Auto-translation")
                            .font(.headline)
                        Spacer()
                        Text(autoTranslateEnabled ? "ON" : "OFF")
                            .font(.subheadline)
                            .foregroundColor(autoTranslateEnabled ? .blue : .secondary)
                    }
                    
                    if let currentLang = currentLanguage {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                            Text("Current language")
                                .font(.subheadline)
                            Spacer()
                            Text(currentLang)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Status")
                }
                
                // Quick actions
                Section {
                    if currentLanguage == nil {
                        Label("Select a language to enable auto-translation", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Quick Actions")
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
                        if filteredLanguages.isEmpty {
                            Text("No languages found")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(filteredLanguages) { language in
                                languageRow(language)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search languages")
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func languageRow(_ language: Language) -> some View {
        Button {
            onLanguageSelected(language.name)
            HapticManager.shared.selection()
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
                if currentLanguage == language.name {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

#Preview {
    LanguageQuickPickerView(
        currentLanguage: "Spanish",
        autoTranslateEnabled: true,
        onLanguageSelected: { _ in }
    )
}

