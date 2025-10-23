import SwiftUI

/// Menu view for selecting a language for translation
struct TranslationMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TranslationViewModel
    @State private var searchText = ""
    
    let messageId: String
    let conversationId: String
    let onTranslate: (Language) -> Void
    
    init(
        messageId: String,
        conversationId: String,
        translationViewModel: TranslationViewModel,
        onTranslate: @escaping (Language) -> Void
    ) {
        self.messageId = messageId
        self.conversationId = conversationId
        self.onTranslate = onTranslate
        _viewModel = StateObject(wrappedValue: translationViewModel)
    }
    
    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.all
        } else {
            return Language.all.filter { language in
                language.name.localizedCaseInsensitiveContains(searchText) ||
                language.nativeName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Recent Languages
                if !viewModel.recentLanguages.isEmpty && searchText.isEmpty {
                    Section("Recent") {
                        ForEach(viewModel.recentLanguages) { language in
                            languageRow(language)
                        }
                    }
                }
                
                // Common Languages
                if searchText.isEmpty {
                    Section("Common Languages") {
                        ForEach(Language.common) { language in
                            languageRow(language)
                        }
                    }
                }
                
                // All Languages
                Section(searchText.isEmpty ? "All Languages" : "Search Results") {
                    ForEach(filteredLanguages) { language in
                        languageRow(language)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search languages")
            .navigationTitle("Translate to...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func languageRow(_ language: Language) -> some View {
        Button {
            selectLanguage(language)
        } label: {
            HStack {
                Text(language.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(language.nativeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Check mark for selected language
                if viewModel.selectedLanguage?.name == language.name {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.body.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func selectLanguage(_ language: Language) {
        viewModel.selectedLanguage = language
        onTranslate(language)
        dismiss()
    }
}

#Preview {
    TranslationMenuView(
        messageId: "message1",
        conversationId: "conv1",
        translationViewModel: TranslationViewModel(),
        onTranslate: { language in
            print("Selected: \(language.name)")
        }
    )
}

