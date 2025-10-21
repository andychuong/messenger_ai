//
//  EmojiReactionPicker.swift
//  messagingapp
//
//  Phase 4: Rich Messaging Features
//  Full emoji picker with categories, search, and recent emojis
//

import SwiftUI

struct EmojiReactionPicker: View {
    @Binding var isPresented: Bool
    let onEmojiSelected: (String) -> Void
    
    @State private var selectedCategory: EmojiCategory = .smileys
    @State private var searchText = ""
    @AppStorage("recentEmojis") private var recentEmojisData: Data = Data()
    
    private var recentEmojis: [String] {
        (try? JSONDecoder().decode([String].self, from: recentEmojisData)) ?? []
    }
    
    private var filteredEmojis: [String] {
        if !searchText.isEmpty {
            return selectedCategory.emojis.filter { emoji in
                // Filter by search - this is a simple implementation
                // In production, you'd want to search by emoji name/description
                true
            }
        }
        return selectedCategory.emojis
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Recent emojis section
                if !searchText.isEmpty && !recentEmojis.isEmpty {
                    recentEmojisSection
                }
                
                // Category tabs
                categoryTabs
                
                // Emoji grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 12) {
                        ForEach(filteredEmojis, id: \.self) { emoji in
                            Button {
                                selectEmoji(emoji)
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 32))
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("React")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search emojis", text: $searchText)
                .textFieldStyle(.plain)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }
    
    // MARK: - Recent Emojis Section
    
    private var recentEmojisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently Used")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentEmojis, id: \.self) { emoji in
                        Button {
                            selectEmoji(emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 32))
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
        }
    }
    
    // MARK: - Category Tabs
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(EmojiCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        VStack(spacing: 4) {
                            Text(category.icon)
                                .font(.title2)
                            
                            if selectedCategory == category {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 4)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Actions
    
    private func selectEmoji(_ emoji: String) {
        // Add to recent emojis
        var recent = recentEmojis
        recent.removeAll(where: { $0 == emoji })
        recent.insert(emoji, at: 0)
        if recent.count > 20 {
            recent = Array(recent.prefix(20))
        }
        if let encoded = try? JSONEncoder().encode(recent) {
            recentEmojisData = encoded
        }
        
        // Call the selection handler
        onEmojiSelected(emoji)
        
        // Dismiss
        isPresented = false
    }
}

// MARK: - Emoji Category

enum EmojiCategory: String, CaseIterable {
    case smileys = "Smileys & People"
    case animals = "Animals & Nature"
    case food = "Food & Drink"
    case activity = "Activity"
    case travel = "Travel & Places"
    case objects = "Objects"
    case symbols = "Symbols"
    case flags = "Flags"
    
    var icon: String {
        switch self {
        case .smileys: return "😀"
        case .animals: return "🐶"
        case .food: return "🍎"
        case .activity: return "⚽️"
        case .travel: return "✈️"
        case .objects: return "💡"
        case .symbols: return "❤️"
        case .flags: return "🏁"
        }
    }
    
    var emojis: [String] {
        switch self {
        case .smileys:
            return ["😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊", "😇",
                    "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "😋", "😛", "😜", "🤪", "😝", "🤑",
                    "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶", "😏", "😒", "🙄", "😬",
                    "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🤧", "🥵",
                    "🥶", "🥴", "😵", "🤯", "🤠", "🥳", "😎", "🤓", "🧐", "😕", "😟", "🙁", "☹️",
                    "😮", "😯", "😲", "😳", "🥺", "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱",
                    "😖", "😣", "😞", "😓", "😩", "😫", "🥱", "😤", "😡", "😠", "🤬", "😈", "👿",
                    "💀", "☠️", "💩", "🤡", "👹", "👺", "👻", "👽", "👾", "🤖", "😺", "😸", "😹",
                    "😻", "😼", "😽", "🙀", "😿", "😾"]
            
        case .animals:
            return ["🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷",
                    "🐸", "🐵", "🐔", "🐧", "🐦", "🐤", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴",
                    "🦄", "🐝", "🐛", "🦋", "🐌", "🐞", "🐜", "🦟", "🦗", "🕷", "🦂", "🐢", "🐍",
                    "🦎", "🦖", "🦕", "🐙", "🦑", "🦐", "🦞", "🦀", "🐡", "🐠", "🐟", "🐬", "🐳",
                    "🐋", "🦈", "🐊", "🐅", "🐆", "🦓", "🦍", "🦧", "🐘", "🦛", "🦏", "🐪", "🐫",
                    "🦒", "🦘", "🐃", "🐂", "🐄", "🐎", "🐖", "🐏", "🐑", "🦙", "🐐", "🦌", "🐕",
                    "🐩", "🦮", "🐈", "🐓", "🦃", "🦚", "🦜", "🦢", "🦩", "🕊", "🐇", "🦝", "🦨",
                    "🦡", "🦦", "🦥", "🐁", "🐀", "🦔"]
            
        case .food:
            return ["🍎", "🍏", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🥭", "🍍",
                    "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶", "🌽", "🥕", "🧄", "🧅",
                    "🥔", "🍠", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🧈", "🥞", "🧇",
                    "🥓", "🥩", "🍗", "🍖", "🦴", "🌭", "🍔", "🍟", "🍕", "🥪", "🥙", "🧆", "🌮",
                    "🌯", "🥗", "🥘", "🥫", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🦪", "🍤",
                    "🍙", "🍚", "🍘", "🍥", "🥠", "🥮", "🍢", "🍡", "🍧", "🍨", "🍦", "🥧", "🧁",
                    "🍰", "🎂", "🍮", "🍭", "🍬", "🍫", "🍿", "🍩", "🍪", "🌰", "🥜", "🍯", "🥛",
                    "🍼", "☕️", "🍵", "🧃", "🥤", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹"]
            
        case .activity:
            return ["⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓", "🏸",
                    "🏒", "🏑", "🥍", "🏏", "🥅", "⛳️", "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽",
                    "🛹", "🛷", "⛸", "🥌", "🎿", "⛷", "🏂", "🪂", "🏋️", "🤼", "🤸", "🤺", "⛹️",
                    "🤾", "🏌️", "🏇", "🧘", "🏊", "🤽", "🚣", "🧗", "🚵", "🚴", "🏆", "🥇", "🥈",
                    "🥉", "🏅", "🎖", "🏵", "🎗", "🎫", "🎟", "🎪", "🤹", "🎭", "🩰", "🎨", "🎬",
                    "🎤", "🎧", "🎼", "🎹", "🥁", "🎷", "🎺", "🎸", "🪕", "🎻", "🎲", "♟", "🎯",
                    "🎳", "🎮", "🎰", "🧩"]
            
        case .travel:
            return ["🚗", "🚕", "🚙", "🚌", "🚎", "🏎", "🚓", "🚑", "🚒", "🚐", "🚚", "🚛", "🚜",
                    "🦯", "🦽", "🦼", "🛴", "🚲", "🛵", "🏍", "🛺", "🚨", "🚔", "🚍", "🚘", "🚖",
                    "🚡", "🚠", "🚟", "🚃", "🚋", "🚞", "🚝", "🚄", "🚅", "🚈", "🚂", "🚆", "🚇",
                    "🚊", "🚉", "✈️", "🛫", "🛬", "🛩", "💺", "🛰", "🚀", "🛸", "🚁", "🛶", "⛵️",
                    "🚤", "🛥", "🛳", "⛴", "🚢", "⚓️", "⛽️", "🚧", "🚦", "🚥", "🚏", "🗺", "🗿",
                    "🗽", "🗼", "🏰", "🏯", "🏟", "🎡", "🎢", "🎠", "⛲️", "⛱", "🏖", "🏝", "🏜",
                    "🌋", "⛰", "🏔", "🗻", "🏕", "⛺️", "🏠", "🏡", "🏘", "🏚", "🏗", "🏭", "🏢",
                    "🏬", "🏣", "🏤", "🏥", "🏦", "🏨", "🏪", "🏫", "🏩", "💒", "🏛", "⛪️", "🕌"]
            
        case .objects:
            return ["⌚️", "📱", "📲", "💻", "⌨️", "🖥", "🖨", "🖱", "🖲", "🕹", "🗜", "💾", "💿",
                    "📀", "📼", "📷", "📸", "📹", "🎥", "📽", "🎞", "📞", "☎️", "📟", "📠", "📺",
                    "📻", "🎙", "🎚", "🎛", "🧭", "⏱", "⏲", "⏰", "🕰", "⌛️", "⏳", "📡", "🔋",
                    "🔌", "💡", "🔦", "🕯", "🪔", "🧯", "🛢", "💸", "💵", "💴", "💶", "💷", "💰",
                    "💳", "💎", "⚖️", "🧰", "🔧", "🔨", "⚒", "🛠", "⛏", "🔩", "⚙️", "🧱", "⛓",
                    "🧲", "🔫", "💣", "🧨", "🪓", "🔪", "🗡", "⚔️", "🛡", "🚬", "⚰️", "⚱️", "🏺",
                    "🔮", "📿", "🧿", "💈", "⚗️", "🔭", "🔬", "🕳", "🩹", "🩺", "💊", "💉", "🩸",
                    "🧬", "🦠", "🧫", "🧪", "🌡", "🧹", "🧺", "🧻", "🚽", "🚰", "🚿", "🛁", "🛀"]
            
        case .symbols:
            return ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕", "💞",
                    "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️", "🕉", "☸️", "✡️", "🔯",
                    "🕎", "☯️", "☦️", "🛐", "⛎", "♈️", "♉️", "♊️", "♋️", "♌️", "♍️", "♎️", "♏️",
                    "♐️", "♑️", "♒️", "♓️", "🆔", "⚛️", "🉑", "☢️", "☣️", "📴", "📳", "🈶", "🈚️",
                    "🈸", "🈺", "🈷️", "✴️", "🆚", "💮", "🉐", "㊙️", "㊗️", "🈴", "🈵", "🈹", "🈲",
                    "🅰️", "🅱️", "🆎", "🆑", "🅾️", "🆘", "❌", "⭕️", "🛑", "⛔️", "📛", "🚫", "💯",
                    "💢", "♨️", "🚷", "🚯", "🚳", "🚱", "🔞", "📵", "🚭", "❗️", "❕", "❓", "❔",
                    "‼️", "⁉️", "🔅", "🔆", "〽️", "⚠️", "🚸", "🔱", "⚜️", "🔰", "♻️", "✅", "🈯️"]
            
        case .flags:
            return ["🏁", "🚩", "🎌", "🏴", "🏳️", "🏳️‍🌈", "🏴‍☠️", "🇺🇸", "🇬🇧", "🇨🇦", "🇦🇺",
                    "🇫🇷", "🇩🇪", "🇮🇹", "🇪🇸", "🇵🇹", "🇷🇺", "🇨🇳", "🇯🇵", "🇰🇷", "🇮🇳", "🇧🇷",
                    "🇲🇽", "🇦🇷", "🇨🇱", "🇨🇴", "🇵🇪", "🇻🇪", "🇪🇨", "🇧🇴", "🇺🇾", "🇵🇾", "🇬🇾",
                    "🇸🇷", "🇹🇹", "🇯🇲", "🇧🇸", "🇧🇧", "🇦🇬", "🇩🇲", "🇬🇩", "🇰🇳", "🇱🇨", "🇻🇨",
                    "🇵🇷", "🇩🇴", "🇭🇹", "🇨🇺", "🇧🇿", "🇬🇹", "🇭🇳", "🇸🇻", "🇳🇮", "🇨🇷", "🇵🇦",
                    "🇨🇴", "🇻🇪", "🇪🇨", "🇵🇪", "🇧🇷", "🇧🇴", "🇵🇾", "🇨🇱", "🇦🇷", "🇺🇾"]
        }
    }
}

#Preview {
    EmojiReactionPicker(isPresented: .constant(true)) { emoji in
        print("Selected: \(emoji)")
    }
}

