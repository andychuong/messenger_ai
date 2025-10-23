# MessageAI - Implementation Plan

## Executive Summary

**Platform:** iOS (Swift/SwiftUI)  
**Backend:** Firebase (Firestore, Authentication, Storage, Cloud Functions)  
**Vector Database:** Pinecone (for RAG and semantic search)  
**AI Integration:** GPT-4o, Pinecone-powered RAG pipelines for conversation intelligence  
**Core Features:** Secure messaging, voice/video calls, AI-powered translation & conversation analysis

### 🔍 Pinecone Integration Highlights
This implementation uses **Pinecone** as the vector database for all embedding storage and similarity search operations:

- **Embeddings:** OpenAI text-embedding-3-large (1536 dimensions) → stored in Pinecone
- **Search:** Semantic search via Pinecone's cosine similarity with metadata filtering
- **Namespaces:** User-based isolation for privacy and access control
- **Performance:** Sub-2s query response times for conversation intelligence
- **Scale:** Production-ready for 10k+ users with serverless architecture

**Why Pinecone?**
- Production-grade performance and reliability
- Managed service with minimal DevOps
- Advanced filtering and metadata support
- Horizontal scaling built-in
- Cost-effective serverless option

> **Note:** See [VECTOR_STORE_OPTIONS.md](./VECTOR_STORE_OPTIONS.md) for alternative vector databases if budget or hosting constraints exist. The architecture supports easy migration between vector stores.

---

## App Overview

### Core Messaging Features
- **User Authentication:** Create accounts, login/logout via Firebase Auth
- **Friends System:** Add friends by email address, manage friend list
- **Real-Time Messaging:** Send/receive text messages with delivery and read receipts
- **Rich Media:** Send images, voice messages with AI transcription
- **Message Interactions:**
  - React with full iOS emoji keyboard (like iMessage)
  - Edit messages (within time window)
  - Long-press for translation menu
  - Start threaded conversations
- **Voice/Video Calls:** Real-time calling with WebRTC
- **End-to-End Encryption:** Secure message content

### AI-Powered Features
- **AI Chat Assistant:** Dedicated interface to query conversations
  - "Summarize my conversation with John"
  - "What action items do I have?"
  - "Translate my last message to Spanish"
- **Voice-to-Text:** AI transcription of voice messages
- **Translation:** 
  - Long-press any message to translate
  - Request translation via AI assistant
- **RAG Pipeline:** Semantic search over conversation history
- **Conversation Intelligence:**
  - Extract action items
  - Detect decisions
  - Priority message flagging

---

## Architecture Overview

### Tech Stack

#### Frontend (iOS)
```
Language: Swift 5.9+
UI Framework: SwiftUI
Local Storage: SwiftData
Reactive Programming: Combine
Networking: URLSession + Firebase SDK
Real-Time: Firebase Firestore listeners + WebRTC
```

#### Backend (Firebase)
```
Authentication: Firebase Authentication
Database: Cloud Firestore
Storage: Firebase Storage (images, media)
Functions: Cloud Functions (Node.js/Python)
Messaging: Firebase Cloud Messaging (FCM)
Real-Time Calls: WebRTC with Firebase signaling
```

#### AI Infrastructure
```
LLM: OpenAI GPT-4o (via Cloud Functions)
Embeddings: OpenAI text-embedding-3-large (1536 dimensions)
Vector Store: Pinecone (Serverless or Pod-based)
Voice-to-Text: Whisper API
Translation: GPT-4o with specialized prompts
```

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        iOS App (Swift)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   SwiftUI    │  │  SwiftData   │  │   Combine    │      │
│  │    Views     │  │ (Local Cache)│  │   Reactive   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────────────────────────────────────────┐      │
│  │              ViewModels (MVVM)                    │      │
│  └──────────────────────────────────────────────────┘      │
│  ┌──────────────────────────────────────────────────┐      │
│  │         Services & Repositories Layer             │      │
│  │  • AuthService    • MessageService                │      │
│  │  • CallService    • AIService                     │      │
│  │  • StorageService • EncryptionService             │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      Firebase Backend                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Firestore  │  │     Auth     │  │   Storage    │      │
│  │  (Real-Time) │  │ (User Mgmt)  │  │   (Media)    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────────────────────────────────────────┐      │
│  │            Cloud Functions (Node.js)              │      │
│  │  • Push Notifications  • AI Proxy                 │      │
│  │  • WebRTC Signaling   • Message Processing        │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    AI Infrastructure                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   OpenAI     │  │   Pinecone   │  │   Whisper    │      │
│  │   GPT-4o     │  │ Vector Store │  │     API      │      │
│  │ (Translation,│  │ (RAG Search) │  │(Voice-to-Text│      │
│  │  Assistant)  │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Data Models

#### Firestore Schema

```javascript
/users/{userId}
  - email: string
  - displayName: string
  - photoURL: string
  - fcmToken: string
  - publicKey: string (for E2EE)
  - lastSeen: timestamp
  - status: "online" | "offline" | "away"
  - createdAt: timestamp

/friendships/{friendshipId}
  - userId1: string
  - userId2: string
  - status: "pending" | "accepted" | "blocked"
  - requestedBy: string
  - requestedAt: timestamp
  - acceptedAt: timestamp

/conversations/{conversationId}
  - participants: [userId1, userId2]
  - participantDetails: {userId: {name, photo}}
  - type: "direct" | "group"
  - lastMessage: {text, senderId, timestamp}
  - lastMessageTime: timestamp
  - unreadCount: {userId: number}
  - encryptionKeyId: string

/conversations/{conversationId}/messages/{messageId}
  - senderId: string
  - text: string (encrypted)
  - timestamp: timestamp
  - status: "sending" | "sent" | "delivered" | "read"
  - readBy: [{userId, readAt}]
  - deliveredTo: [{userId, deliveredAt}]
  - reactions: {userId: emoji}
  - mediaURL: string (optional)
  - mediaType: "image" | "voice" | "video"
  - voiceTranscript: string (optional)
  - editedAt: timestamp (optional)
  - originalText: string (optional, for edit history)
  - replyTo: messageId (optional, for threads)
  - translations: {languageCode: translatedText}

/conversations/{conversationId}/threads/{threadId}
  - parentMessageId: string
  - participants: [userId]
  - messageCount: number
  - lastMessageTime: timestamp

/calls/{callId}
  - callerId: string
  - recipientId: string
  - type: "audio" | "video"
  - status: "ringing" | "active" | "ended" | "missed"
  - startedAt: timestamp
  - endedAt: timestamp
  - duration: number
  - sdpOffer: string
  - sdpAnswer: string
  - iceCandidates: array

/embeddings/{messageId}
  - conversationId: string
  - messageId: string
  - pineconeId: string (reference to Pinecone vector ID)
  - text: string (unencrypted snippet for search)
  - timestamp: timestamp
  - indexed: boolean (whether vector is in Pinecone)

/actionItems/{itemId}
  - conversationId: string
  - messageId: string
  - task: string
  - assignedTo: userId
  - createdBy: userId
  - dueDate: timestamp
  - status: "pending" | "completed"
  - extractedAt: timestamp

/decisions/{decisionId}
  - conversationId: string
  - messageId: string
  - decision: string
  - participants: [userId]
  - rationale: string
  - date: timestamp
```

### iOS Project Structure

```
MessagingApp/
├── App/
│   ├── MessagingAppApp.swift
│   └── AppDelegate.swift
│
├── Models/
│   ├── User.swift
│   ├── Conversation.swift
│   ├── Message.swift
│   ├── Friendship.swift
│   ├── Call.swift
│   ├── ActionItem.swift
│   └── AIContext.swift
│
├── ViewModels/
│   ├── Authentication/
│   │   ├── LoginViewModel.swift
│   │   └── SignUpViewModel.swift
│   ├── Friends/
│   │   └── FriendsListViewModel.swift
│   ├── Conversations/
│   │   ├── ConversationListViewModel.swift
│   │   └── ChatViewModel.swift
│   ├── Calls/
│   │   └── CallViewModel.swift
│   └── AI/
│       ├── AIAssistantViewModel.swift
│       └── TranslationViewModel.swift
│
├── Views/
│   ├── Authentication/
│   │   ├── LoginView.swift
│   │   ├── SignUpView.swift
│   │   └── ProfileSetupView.swift
│   ├── Friends/
│   │   ├── FriendsListView.swift
│   │   ├── AddFriendView.swift
│   │   └── FriendRequestsView.swift
│   ├── Conversations/
│   │   ├── ConversationListView.swift
│   │   ├── ChatView.swift
│   │   ├── MessageRow.swift
│   │   ├── MessageInputBar.swift
│   │   ├── EmojiReactionPicker.swift
│   │   ├── TranslationMenuView.swift
│   │   └── ThreadView.swift
│   ├── Calls/
│   │   ├── IncomingCallView.swift
│   │   ├── ActiveCallView.swift
│   │   └── CallHistoryView.swift
│   ├── AI/
│   │   ├── AIAssistantView.swift
│   │   ├── AIConversationView.swift
│   │   └── ActionItemsView.swift
│   └── Shared/
│       ├── ImagePickerView.swift
│       ├── VoiceRecorderView.swift
│       └── LoadingView.swift
│
├── Services/
│   ├── Authentication/
│   │   └── AuthService.swift
│   ├── Friends/
│   │   └── FriendshipService.swift
│   ├── Messaging/
│   │   ├── MessageService.swift
│   │   ├── ConversationService.swift
│   │   └── RealtimeListenerService.swift
│   ├── Media/
│   │   ├── ImageService.swift
│   │   ├── VoiceRecordingService.swift
│   │   └── StorageService.swift
│   ├── Calls/
│   │   ├── CallService.swift
│   │   ├── WebRTCService.swift
│   │   └── SignalingService.swift
│   ├── AI/
│   │   ├── AIService.swift
│   │   ├── TranslationService.swift
│   │   ├── VoiceToTextService.swift
│   │   ├── RAGService.swift (Pinecone search client)
│   │   ├── EmbeddingService.swift (OpenAI embeddings)
│   │   └── ConversationIntelligenceService.swift
│   ├── Security/
│   │   ├── EncryptionService.swift
│   │   └── KeychainService.swift
│   ├── LocalStorage/
│   │   └── LocalStorageService.swift
│   └── Notifications/
│       └── PushNotificationService.swift
│
├── Utilities/
│   ├── NetworkMonitor.swift
│   ├── Constants.swift
│   ├── Extensions/
│   │   ├── Date+Extensions.swift
│   │   ├── String+Extensions.swift
│   │   └── View+Extensions.swift
│   └── Helpers/
│       ├── AudioManager.swift
│       └── HapticManager.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── GoogleService-Info.plist
│   └── Info.plist
│
└── Tests/
    ├── UnitTests/
    └── UITests/
```

### Security Architecture

#### End-to-End Encryption Flow

```
1. Key Generation (per conversation)
   - Each conversation gets unique AES-256 key
   - Keys stored in device Keychain
   - Public key exchange via Firestore

2. Message Encryption (Client-Side)
   - Encrypt message text with AES-256-GCM
   - Store encrypted text in Firestore
   - Metadata (timestamps, status) unencrypted

3. AI Processing Consideration
   - For AI features (translation, RAG), temporarily decrypt client-side
   - Send to Cloud Function with user consent
   - Never store unencrypted content on server
   - Option to disable AI for privacy-sensitive conversations

4. Media Encryption
   - Encrypt images/voice before upload
   - Store encryption key in message metadata
   - Decrypt on recipient device
```

### AI Features Architecture

#### RAG Pipeline for Conversation Search

```
┌─────────────────────────────────────────────────────────────┐
│                     User Query                               │
│              "What did Sarah say about the project?"         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Query Embedding                             │
│     OpenAI text-embedding-3-large (1536 dimensions)          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            Pinecone Vector Similarity Search                 │
│    Query: Top-K (10) by cosine similarity                    │
│    Filter: conversationId, userId (namespace)                │
│    Response: Vector IDs + scores + metadata                  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Context Assembly                            │
│   1. Get message IDs from Pinecone results                   │
│   2. Retrieve full encrypted messages from Firestore        │
│   3. Decrypt messages client-side (with user consent)        │
│   4. Rank by relevance score + recency                       │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   LLM Generation                             │
│   GPT-4o: Answer question with retrieved context            │
│   Include: Message text, sender, timestamp, conversation    │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                 Stream Response to User                      │
│             Display citations/sources from search            │
└─────────────────────────────────────────────────────────────┘
```

#### AI Assistant Commands

```swift
// User Interface Commands
"Summarize my last 50 messages with John"
"What action items do I have?"
"Translate my last message to Spanish"
"Find all messages about the launch date"
"What did we decide about the database?"
"Show me priority messages from this week"
"Extract all decisions from this conversation"
```

#### Translation Feature

```
Long-Press Menu:
┌─────────────────────────┐
│ Translate to Spanish    │
│ Translate to French     │
│ Translate to German     │
│ Translate to Chinese    │
│ Translate to Japanese   │
│ More Languages...       │
└─────────────────────────┘

Implementation:
1. Detect long-press gesture
2. Show translation menu
3. Send message text + target language to Cloud Function
4. GPT-4o translates with context awareness
5. Cache translation in message document
6. Display translated text in overlay
```

---

## Task List

### Phase 1: Project Setup & Authentication (Days 1-2)

#### 1.1 Project Initialization
- [ ] Create new iOS project in Xcode (Swift, SwiftUI)
- [ ] Set up Git repository with .gitignore
- [ ] Configure project structure (folders, groups)
- [ ] Add Firebase SDK via Swift Package Manager
  - [ ] FirebaseAuth
  - [ ] FirebaseFirestore
  - [ ] FirebaseStorage
  - [ ] FirebaseMessaging
- [ ] Download and add `GoogleService-Info.plist`
- [ ] Configure Firebase in AppDelegate
- [ ] Set up SwiftData models
- [ ] Add WebRTC framework (via SPM or manual)

#### 1.2 Firebase Backend Setup
- [ ] Create Firebase project
- [ ] Enable Authentication (Email/Password)
- [ ] Create Firestore database
- [ ] Set up Firebase Storage
- [ ] Configure Firestore security rules (initial)
- [ ] Set up Firebase Cloud Functions project
  - [ ] Initialize Node.js project
  - [ ] Install dependencies:
    - [ ] `firebase-admin` - Firebase SDK
    - [ ] `openai` - OpenAI API client
    - [ ] `@pinecone-database/pinecone` - Pinecone vector database client
    - [ ] Other utilities as needed
  - [ ] Configure environment variables (`.env` file):
    ```bash
    OPENAI_API_KEY=sk-...
    PINECONE_API_KEY=...
    PINECONE_ENVIRONMENT=us-east1-gcp
    PINECONE_INDEX_NAME=messaging-app-vectors
    ```
  - [ ] Set Firebase Functions config:
    ```bash
    firebase functions:config:set openai.key="sk-..."
    firebase functions:config:set pinecone.key="..."
    firebase functions:config:set pinecone.environment="us-east1-gcp"
    firebase functions:config:set pinecone.index="messaging-app-vectors"
    ```
  - [ ] Deploy starter functions
- [ ] Enable Firebase Cloud Messaging

#### 1.3 User Authentication
- [ ] Create `User` model (SwiftData)
- [ ] Build `AuthService.swift`
  - [ ] Sign up with email/password
  - [ ] Login with email/password
  - [ ] Logout
  - [ ] Password reset
  - [ ] Session persistence
- [ ] Build `LoginView.swift`
  - [ ] Email/password input fields
  - [ ] Login button with loading state
  - [ ] "Forgot Password" link
  - [ ] Navigation to SignUp
- [ ] Build `SignUpView.swift`
  - [ ] Email, password, confirm password fields
  - [ ] Display name input
  - [ ] Profile photo picker (optional)
  - [ ] Sign up button with validation
- [ ] Build `ProfileSetupView.swift`
  - [ ] Set display name
  - [ ] Upload profile picture
  - [ ] Save to Firestore `/users/{userId}`
- [ ] Create `LoginViewModel.swift`
- [ ] Create `SignUpViewModel.swift`
- [ ] Implement authentication state management
- [ ] Add error handling and validation

### Phase 2: Friends System (Days 3-4)

#### 2.1 Friend Management
- [ ] Create `Friendship` model
- [ ] Build `FriendshipService.swift`
  - [ ] Send friend request by email
  - [ ] Accept friend request
  - [ ] Decline friend request
  - [ ] Remove friend
  - [ ] Block user
  - [ ] Fetch friends list
  - [ ] Search users by email
- [ ] Create Firestore cloud function `sendFriendRequest`
  - [ ] Validate email exists
  - [ ] Create friendship document
  - [ ] Send push notification
- [ ] Create Firestore cloud function `acceptFriendRequest`

#### 2.2 Friends UI
- [ ] Build `FriendsListView.swift`
  - [ ] List of accepted friends
  - [ ] Online status indicators
  - [ ] Search bar
  - [ ] "Add Friend" button
- [ ] Build `AddFriendView.swift`
  - [ ] Email input field
  - [ ] Search button
  - [ ] Display search result
  - [ ] Send request button
- [ ] Build `FriendRequestsView.swift`
  - [ ] List pending incoming requests
  - [ ] Accept/Decline buttons
  - [ ] Empty state
- [ ] Create `FriendsListViewModel.swift`
- [ ] Set up real-time listener for friend requests
- [ ] Add haptic feedback for actions

### Phase 3: Core Messaging (Days 5-7)

#### 3.1 Conversation Management
- [ ] Create `Conversation` model (SwiftData)
- [ ] Create `Message` model (SwiftData)
- [ ] Build `ConversationService.swift`
  - [ ] Create new conversation
  - [ ] Fetch user's conversations
  - [ ] Delete conversation
  - [ ] Update last message
  - [ ] Mark conversation as read
- [ ] Build `MessageService.swift`
  - [ ] Send text message
  - [ ] Fetch messages (paginated)
  - [ ] Mark message as delivered
  - [ ] Mark message as read
  - [ ] Delete message
  - [ ] Edit message (within 15 min)
  - [ ] Real-time message listener
- [ ] Implement local storage with SwiftData
  - [ ] Save messages locally
  - [ ] Sync with Firestore
  - [ ] Handle offline mode
  - [ ] Conflict resolution (server wins)

#### 3.2 Conversation List UI
- [ ] Build `ConversationListView.swift`
  - [ ] List of conversations
  - [ ] Last message preview
  - [ ] Timestamp
  - [ ] Unread badge
  - [ ] Profile picture
  - [ ] Online status indicator
  - [ ] Swipe actions (delete, mute)
  - [ ] Pull to refresh
  - [ ] Navigation to ChatView
- [ ] Create `ConversationListViewModel.swift`
  - [ ] Load conversations
  - [ ] Real-time updates
  - [ ] Handle unread counts
  - [ ] Sort by most recent

#### 3.3 Chat Interface
- [ ] Build `ChatView.swift`
  - [ ] Message list (ScrollViewReader for auto-scroll)
  - [ ] Navigation bar (back, title, call buttons)
  - [ ] Message input bar at bottom
  - [ ] Load more messages on scroll (pagination)
  - [ ] Typing indicators
  - [ ] Date separators
- [ ] Build `MessageRow.swift`
  - [ ] Sent vs received message styling
  - [ ] Message bubble
  - [ ] Timestamp
  - [ ] Delivery/read status indicators (checkmarks)
  - [ ] Profile picture (received messages)
  - [ ] Long-press gesture recognizer
  - [ ] Reaction display
  - [ ] Edit indicator
  - [ ] Reply/thread indicator
- [ ] Build `MessageInputBar.swift`
  - [ ] Text field with multi-line support
  - [ ] Send button
  - [ ] Image picker button
  - [ ] Voice record button
  - [ ] Emoji button
  - [ ] "Editing" state indicator
- [ ] Create `ChatViewModel.swift`
  - [ ] Load messages with pagination
  - [ ] Send message
  - [ ] Real-time listener
  - [ ] Handle connection state
  - [ ] Optimistic UI updates
  - [ ] Retry failed messages

#### 3.4 Read Receipts & Delivery Status
- [ ] Implement message status updates
  - [ ] "Sending" (local optimistic)
  - [ ] "Sent" (uploaded to Firestore)
  - [ ] "Delivered" (recipient device received)
  - [ ] "Read" (recipient viewed message)
- [ ] Create status indicators UI
  - [ ] Single gray checkmark (sent)
  - [ ] Double gray checkmark (delivered)
  - [ ] Double blue checkmark (read)
- [ ] Update message status on recipient actions
- [ ] Batch status updates for efficiency
- [ ] Add privacy setting to disable read receipts (future)

### Phase 4: Rich Messaging Features (Days 8-10)

#### 4.1 Emoji Reactions
- [ ] Build `EmojiReactionPicker.swift`
  - [ ] Full iOS emoji keyboard
  - [ ] Recently used emojis
  - [ ] Emoji search
  - [ ] Categories (Smileys, Animals, Food, etc.)
- [ ] Implement reaction logic in `MessageService`
  - [ ] Add reaction to message
  - [ ] Remove reaction
  - [ ] Update Firestore reactions map
  - [ ] Real-time reaction updates
- [ ] Display reactions on `MessageRow`
  - [ ] Reaction bubbles below message
  - [ ] Count for each emoji
  - [ ] Highlight user's reaction
  - [ ] Tap to add same reaction
  - [ ] Long-press to see who reacted
- [ ] Add haptic feedback on reaction

#### 4.2 Message Editing
- [ ] Implement edit functionality
  - [ ] Check if within edit window (15 minutes)
  - [ ] Update message text in Firestore
  - [ ] Store edit timestamp
  - [ ] Optional: Store edit history
- [ ] Update UI to show edited messages
  - [ ] "Edited" label
  - [ ] Tap to view original (optional)
- [ ] Handle edit in `ChatViewModel`
- [ ] Add edit option to long-press menu

#### 4.3 Image Sharing
- [ ] Build `ImageService.swift`
  - [ ] Pick image from photo library
  - [ ] Compress image
  - [ ] Upload to Firebase Storage
  - [ ] Generate download URL
  - [ ] Create message with image
  - [ ] Download and cache images
- [ ] Update `MessageRow` to display images
  - [ ] Async image loading
  - [ ] Loading placeholder
  - [ ] Tap to view full screen
  - [ ] Long-press options (save, share)
- [ ] Build full-screen image viewer
- [ ] Add image picker to `MessageInputBar`
- [ ] Show upload progress indicator

#### 4.4 Voice Messages with AI Transcription
- [ ] Build `VoiceRecordingService.swift`
  - [ ] Request microphone permission
  - [ ] Record audio (AVAudioRecorder)
  - [ ] Stop recording
  - [ ] Play audio (AVAudioPlayer)
  - [ ] Save audio file locally
  - [ ] Upload to Firebase Storage
- [ ] Build `VoiceRecorderView.swift`
  - [ ] Record button (hold to record)
  - [ ] Waveform visualization
  - [ ] Timer
  - [ ] Cancel and send options
- [ ] Integrate OpenAI Whisper API for transcription
  - [ ] Create Cloud Function `transcribeVoice`
  - [ ] Upload audio to Whisper
  - [ ] Return transcript
  - [ ] Store transcript in message document
- [ ] Update `MessageRow` for voice messages
  - [ ] Play button
  - [ ] Duration display
  - [ ] Playback progress
  - [ ] Show transcript below (toggle)
- [ ] Create `VoiceToTextService.swift` in iOS app

#### 4.5 Message Threading
- [ ] Create `Thread` model
- [ ] Implement thread creation
  - [ ] Reply to message creates thread
  - [ ] Store parent message reference
  - [ ] Create thread document in Firestore
- [ ] Build `ThreadView.swift`
  - [ ] Show parent message at top
  - [ ] List of replies
  - [ ] Reply input
  - [ ] Navigate back to main chat
- [ ] Update `MessageRow` to show thread indicator
  - [ ] "N replies" label
  - [ ] Tap to open thread
- [ ] Update `ChatViewModel` to handle threads

### Phase 4.5: Group Chat (Days 10.5-11.5)

#### 4.5.1 Group Chat Data & Services
- [ ] Update `ConversationService.swift` for groups
  - [ ] `createGroupConversation(memberIds:groupName:)` - Create new group
  - [ ] `addMembersToGroup(conversationId:userIds:)` - Add members
  - [ ] `removeMemberFromGroup(conversationId:userId:)` - Remove member
  - [ ] `leaveGroup(conversationId:)` - Leave group
  - [ ] `updateGroupName(conversationId:name:)` - Rename group
  - [ ] `updateGroupPhoto(conversationId:imageURL:)` - Set group avatar
  - [ ] `fetchGroupMembers(conversationId:)` - Get all members
- [ ] Update `MessageService.swift` for groups
  - [ ] Handle multi-participant message delivery
  - [ ] Group-aware read receipts (show count, not names)
  - [ ] System messages (member joined/left, name changed)

#### 4.5.2 Create Group UI
- [ ] Build `CreateGroupView.swift`
  - [ ] "Create Group" button in NewMessageView
  - [ ] Multi-select friend picker
  - [ ] Selected members display (chips)
  - [ ] Group name input (optional)
  - [ ] Group photo picker (optional)
  - [ ] "Create" button with validation
  - [ ] Loading state during creation
- [ ] Create `GroupMemberSelectionView.swift`
  - [ ] List of friends with checkboxes
  - [ ] Search bar
  - [ ] "Select All" / "Deselect All"
  - [ ] Selected count indicator
  - [ ] Minimum 2 members validation

#### 4.5.3 Group Info & Management
- [ ] Build `GroupInfoView.swift`
  - [ ] Group photo and name at top
  - [ ] "Edit" button for admins
  - [ ] List of all members with roles
  - [ ] "Add Members" button
  - [ ] "Leave Group" button (red)
  - [ ] Media/Links/Docs tabs (future)
- [ ] Build `EditGroupView.swift`
  - [ ] Edit group name
  - [ ] Change group photo
  - [ ] Member management
  - [ ] "Save" button
- [ ] Build `AddGroupMembersView.swift`
  - [ ] Friend selection (existing members excluded)
  - [ ] "Add" button
  - [ ] Show who added whom in chat

#### 4.5.4 Update Chat Interface for Groups
- [ ] Update `ChatView.swift`
  - [ ] Show group name in navigation title
  - [ ] Show member count subtitle ("10 members")
  - [ ] Tap title to open GroupInfoView
  - [ ] Disable 1-on-1 call buttons (or add group call later)
- [ ] Update `ConversationListView.swift`
  - [ ] Show group avatar (or member avatars)
  - [ ] Show last sender name in preview
  - [ ] "Group" indicator if needed
- [ ] Update `MessageRow.swift`
  - [ ] Show sender name for ALL messages in groups
  - [ ] Group message bubble styling
  - [ ] Read receipts: show count ("Read by 5")

#### 4.5.5 Group-Specific Features
- [ ] System messages
  - [ ] "Alice added Bob to the group"
  - [ ] "Charlie left the group"
  - [ ] "Alice changed the group name"
  - [ ] Display as centered, gray text
- [ ] Group notifications
  - [ ] Update Cloud Function for group messages
  - [ ] Notification: "Alice in Study Group: Hey everyone!"
  - [ ] Mute group option (future)
- [ ] Group roles (optional MVP)
  - [ ] Creator is admin by default
  - [ ] Admins can add/remove members
  - [ ] Admins can change group info
  - [ ] Members can only leave

#### 4.5.6 Firestore Rules for Groups
- [ ] Update security rules
  - [ ] Only members can read group messages
  - [ ] Only members can send messages
  - [ ] Only admins can modify group
  - [ ] Anyone can leave group

### Phase 5: Voice/Video Calling (Days 12-14)

**Note:** Voice/Video calling starts with 1-on-1 calls. Group calling can be added later.

#### 5.1 WebRTC Setup
- [ ] Add WebRTC framework to project
- [ ] Build `WebRTCService.swift`
  - [ ] Initialize peer connection
  - [ ] Create offer (caller)
  - [ ] Create answer (callee)
  - [ ] Set local/remote descriptions
  - [ ] Handle ICE candidates
  - [ ] Manage audio/video tracks
  - [ ] Mute/unmute audio
  - [ ] Enable/disable video
  - [ ] End call

#### 5.2 Call Signaling
- [ ] Build `SignalingService.swift`
  - [ ] Send call offer via Firestore
  - [ ] Listen for incoming calls
  - [ ] Send SDP answer
  - [ ] Exchange ICE candidates
  - [ ] Handle call states (ringing, active, ended)
- [ ] Create Cloud Function `notifyIncomingCall`
  - [ ] Send push notification for calls
  - [ ] Include caller info
  - [ ] VoIP notification for background

#### 5.3 Call UI
- [ ] Build `IncomingCallView.swift`
  - [ ] Full-screen modal
  - [ ] Caller info (name, photo)
  - [ ] Accept button (green)
  - [ ] Decline button (red)
  - [ ] Call type (audio/video)
- [ ] Build `ActiveCallView.swift`
  - [ ] Video preview (if video call)
  - [ ] Remote video stream
  - [ ] Local video (pip)
  - [ ] Call duration timer
  - [ ] Mute button
  - [ ] Speaker/Bluetooth toggle
  - [ ] Video toggle (for video calls)
  - [ ] End call button
  - [ ] Participant info
- [ ] Create `CallViewModel.swift`
  - [ ] Initiate call
  - [ ] Accept call
  - [ ] Decline call
  - [ ] End call
  - [ ] Manage call state
  - [ ] Handle audio routing
- [ ] Add call buttons to ChatView navigation bar
  - [ ] Audio call button
  - [ ] Video call button
- [ ] Handle background state for calls
- [ ] Request camera/microphone permissions

#### 5.4 Call History (Optional)
- [ ] Store call records in Firestore
- [ ] Build `CallHistoryView.swift`
  - [ ] List of past calls
  - [ ] Call type, duration, timestamp
  - [ ] Missed call indicator
  - [ ] Tap to call back

### Phase 6: Security & Encryption (Days 15-16)

#### 6.1 End-to-End Encryption
- [ ] Build `EncryptionService.swift`
  - [ ] Generate AES-256 key per conversation
  - [ ] Encrypt message text before sending
  - [ ] Decrypt received messages
  - [ ] Secure key exchange (Diffie-Hellman)
  - [ ] Store keys in Keychain
- [ ] Build `KeychainService.swift`
  - [ ] Save encryption keys
  - [ ] Retrieve encryption keys
  - [ ] Delete keys on logout
- [ ] Implement public key cryptography
  - [ ] Generate RSA key pair per user
  - [ ] Store public key in Firestore
  - [ ] Use for initial key exchange
- [ ] Update `MessageService` to encrypt/decrypt
  - [ ] Encrypt before Firestore write
  - [ ] Decrypt after Firestore read
  - [ ] Handle key rotation
- [ ] Encrypt images before upload
  - [ ] Encrypt file data
  - [ ] Store key in message metadata
  - [ ] Decrypt on download

#### 6.2 Security Enhancements
- [ ] Implement Firestore security rules
  - [ ] Users can only read own data
  - [ ] Participants-only access to conversations
  - [ ] Validate message structure
  - [ ] Rate limiting
- [ ] Add input sanitization
- [ ] Implement secure credential storage
- [ ] Add certificate pinning (optional)
- [ ] Enable App Transport Security
- [ ] Obfuscate API keys in Cloud Functions

### Phase 7: AI Features - Translation (Days 17-18) ✅ COMPLETE

#### 7.1 Translation Service
- [x] Create Cloud Function `translateMessage`
  - [x] Accept message text + target language
  - [x] Call OpenAI GPT-4o with translation prompt
  - [x] Return translated text
  - [x] Cache translations in Firestore
- [x] Build `TranslationService.swift` (iOS)
  - [x] Call translation Cloud Function
  - [x] Cache translations locally
  - [x] Handle errors gracefully
- [x] Create `TranslationViewModel.swift`

#### 7.2 Translation UI
- [x] Build `TranslationMenuView.swift`
  - [x] List of languages
  - [x] Recently used languages
  - [x] Search languages
- [x] Add long-press gesture to `MessageRow`
  - [x] Show context menu
  - [x] "Translate" option
  - [x] Display translation in overlay/modal
- [x] Display cached translations
  - [x] Toggle between original and translated
  - [x] Show "Translated to X" label
- [x] Add loading indicator during translation
- [x] Handle translation errors
- [x] Build `TranslationOverlayView.swift` (bonus feature)
  - [x] Beautiful overlay with toggle
  - [x] Copy functionality
  - [x] Cache indicator
  - [x] Smooth animations

### Phase 8: AI Features - RAG & Conversation Intelligence (Days 19-22)

#### 8.1 Pinecone Setup & Configuration
- [ ] Create Pinecone account at https://www.pinecone.io
  - [ ] Sign up for account (Starter plan or higher)
  - [ ] Generate API key from console
  - [ ] Note your environment (e.g., `us-east1-gcp`)
- [ ] Create Pinecone index
  - [ ] Name: `messaging-app-vectors` or `{project-name}-{env}`
  - [ ] Dimensions: 1536 (matches text-embedding-3-large)
  - [ ] Metric: `cosine` (for similarity search)
  - [ ] Index type: Serverless (recommended) or Pod-based
  - [ ] Region: Choose closest to Firebase Functions region
- [ ] Set up Pinecone namespaces strategy
  - [ ] Option A: Namespace per user (e.g., `user_{userId}`)
  - [ ] Option B: Namespace per conversation (e.g., `conv_{conversationId}`)
  - [ ] Option C: Single namespace with metadata filters
- [ ] Install Pinecone SDK in Cloud Functions
  - [ ] `npm install @pinecone-database/pinecone`
  - [ ] Configure client with API key
  - [ ] Test connection and index access

#### 8.2 Embedding Generation Pipeline
- [ ] Create Cloud Function `generateEmbedding`
  - [ ] Accept message text (decrypted, with user consent)
  - [ ] Call OpenAI embeddings API (text-embedding-3-large)
  - [ ] Return embedding vector (1536 dimensions)
  - [ ] Cache embedding to avoid regeneration
  - [ ] Handle rate limits and errors
- [ ] Create Cloud Function `indexMessage`
  - [ ] Triggered on new message creation (Firestore trigger)
  - [ ] Extract message text (decrypt if needed)
  - [ ] Generate embedding using OpenAI
  - [ ] Store in Pinecone with metadata:
    ```javascript
    {
      id: messageId,
      values: embedding,  // 1536-dim vector
      metadata: {
        conversationId: string,
        senderId: string,
        timestamp: number,
        messagePreview: string (first 100 chars),
        type: "text" | "voice" | "image"
      }
    }
    ```
  - [ ] Update Firestore `/embeddings/{messageId}` with pineconeId
  - [ ] Handle failures with retry logic
- [ ] Handle encryption considerations
  - [ ] User consent required for AI indexing
  - [ ] Store unencrypted snippet in Pinecone metadata (first 100 chars)
  - [ ] Add per-conversation AI opt-in/opt-out setting
  - [ ] Skip indexing for "private" conversations
  - [ ] Clear user vectors on account deletion (GDPR compliance)

#### 8.3 Pinecone RAG Search Service
- [ ] Create Cloud Function `semanticSearchPinecone`
  - [ ] Accept parameters: `query` (text), `userId`, `conversationId` (optional), `topK` (default 10)
  - [ ] Generate query embedding via OpenAI
  - [ ] Initialize Pinecone client
  - [ ] Query Pinecone index:
    ```javascript
    const results = await index.query({
      vector: queryEmbedding,
      topK: 10,
      includeMetadata: true,
      filter: {
        conversationId: conversationId,  // optional filter
        senderId: { $ne: "system" }       // exclude system messages
      },
      namespace: `user_${userId}`  // user-specific namespace
    });
    ```
  - [ ] Process results: extract message IDs and scores
  - [ ] Fetch full messages from Firestore (batch read)
  - [ ] Decrypt messages if needed
  - [ ] Combine Pinecone scores with recency boost
  - [ ] Return ranked results with metadata
- [ ] Build `RAGService.swift` (iOS)
  - [ ] `semanticSearch(query:conversationId:)` method
  - [ ] Call Cloud Function with auth token
  - [ ] Parse and display results
  - [ ] Cache search results locally
  - [ ] Handle errors gracefully
- [ ] Create Cloud Function `answerQuestionWithRAG`
  - [ ] Accept user question + optional context (conversationId)
  - [ ] Perform semantic search via Pinecone
  - [ ] Assemble context from top results (up to 10 messages)
  - [ ] Build GPT-4o prompt with context:
    ```
    System: You are a helpful assistant...
    Context: [Retrieved messages with metadata]
    Question: [User's question]
    ```
  - [ ] Call GPT-4o API with streaming
  - [ ] Stream response back to client
  - [ ] Include citations (message IDs + timestamps)

#### 8.4 Action Item Extraction
- [ ] Create Cloud Function `extractActionItems`
  - [ ] Triggered on new message (or on-demand)
  - [ ] Use GPT-4o function calling
  - [ ] Extract: task, assignee, deadline
  - [ ] Store in `/actionItems` collection
- [ ] Create `ActionItem` model
- [ ] Build UI for action items
  - [ ] `ActionItemsView.swift`
  - [ ] List of action items
  - [ ] Filter by: All, Assigned to Me, By Person
  - [ ] Checkboxes to mark complete
  - [ ] Link back to message

#### 8.5 Decision Tracking
- [ ] Create Cloud Function `detectDecision`
  - [ ] Analyze message for decisions
  - [ ] Extract: decision, who, rationale, date
  - [ ] Store in `/decisions` collection
- [ ] Build `DecisionLogView.swift`
  - [ ] Chronological list
  - [ ] Expandable cards
  - [ ] Search functionality
  - [ ] Link to original conversation

#### 8.6 Priority Message Detection
- [ ] Create Cloud Function `classifyPriority`
  - [ ] Real-time or batch processing
  - [ ] Check for: mentions, questions, deadlines
  - [ ] Return priority score + reason
  - [ ] Update message metadata
- [ ] Update `ConversationListView` to show priority indicator
  - [ ] Red badge for priority conversations
  - [ ] Filter/sort by priority
- [ ] Create "Priority Messages" inbox view

#### 8.7 Pinecone Data Management & Cleanup
- [ ] Create Cloud Function `deleteUserVectors`
  - [ ] Triggered on user account deletion
  - [ ] Delete all vectors in user's namespace
  - [ ] Cleanup Firestore embeddings collection
  - [ ] Log deletion for compliance audit
- [ ] Create Cloud Function `deleteConversationVectors`
  - [ ] Triggered when conversation is deleted
  - [ ] Query Pinecone for conversation vectors
  - [ ] Batch delete matching vectors
  - [ ] Update Firestore embeddings status
- [ ] Implement data retention policies
  - [ ] Optional: Auto-delete vectors older than X months
  - [ ] User-configurable retention settings
  - [ ] Compliance with data protection regulations
- [ ] Build admin/debug utilities
  - [ ] Script to reindex all messages for a user
  - [ ] Script to verify embedding consistency
  - [ ] Dashboard to monitor Pinecone usage/costs
  - [ ] Bulk migration tools if needed

### Phase 9: AI Chat Assistant (Days 23-25)

#### 9.1 AI Assistant Backend
- [ ] Create Cloud Function `chatWithAssistant`
  - [ ] Maintain conversation context
  - [ ] Handle commands:
    - [ ] "Summarize conversation with [name]"
    - [ ] "What action items do I have?"
    - [ ] "Translate my last message to [language]"
    - [ ] "Find messages about [topic]"
    - [ ] "What did we decide about [topic]?"
    - [ ] "Show priority messages"
  - [ ] Route to appropriate function
  - [ ] Use RAG for context retrieval
  - [ ] Stream response with GPT-4o
- [ ] Implement function calling for commands
  - [ ] Define tools: search, summarize, translate, extract
  - [ ] GPT-4o decides which tool to use
  - [ ] Execute tool and return result

#### 9.2 AI Assistant UI
- [ ] Build `AIAssistantView.swift`
  - [ ] Dedicated tab or button
  - [ ] Chat-like interface
  - [ ] Message history with AI
  - [ ] Input bar for queries
  - [ ] Suggested action buttons
  - [ ] Streaming response display
- [ ] Build `AIConversationView.swift`
  - [ ] Similar to ChatView but for AI
  - [ ] Different styling (indicate it's AI)
  - [ ] Show loading states
  - [ ] Display sources/citations
- [ ] Create `AIAssistantViewModel.swift`
  - [ ] Send user query
  - [ ] Receive and display AI response
  - [ ] Manage conversation history
  - [ ] Handle streaming
  - [ ] Execute follow-up actions
- [ ] Add quick actions:
  - [ ] "Summarize this conversation" button in ChatView
  - [ ] "What are my action items?" in home
  - [ ] "Translate" shortcut in message menu

#### 9.3 Context Management
- [ ] Store AI conversation history
  - [ ] Local or Firestore
  - [ ] Associate with user
  - [ ] Clear conversation option
- [ ] Manage context window
  - [ ] Include relevant conversation metadata
  - [ ] Recent messages
  - [ ] User preferences
- [ ] Handle multi-turn conversations
  - [ ] Maintain state between queries
  - [ ] Reference previous answers

### Phase 10: Push Notifications (Day 26)

#### 10.1 Push Notification Setup
- [ ] Configure APNs in Apple Developer account
  - [ ] Create APNs key
  - [ ] Upload to Firebase Console
- [ ] Request notification permissions in app
  - [ ] Show permission prompt
  - [ ] Handle authorization status
- [ ] Build `PushNotificationService.swift`
  - [ ] Register for remote notifications
  - [ ] Store FCM token in Firestore
  - [ ] Handle token refresh
  - [ ] Process incoming notifications

#### 10.2 Notification Triggers
- [ ] Create Cloud Function `sendMessageNotification`
  - [ ] Trigger on new message
  - [ ] Check if recipient online
  - [ ] Construct notification payload
  - [ ] Send via FCM to recipient's token
  - [ ] Include: sender name, message preview, conversation ID
- [ ] Create Cloud Function `sendCallNotification`
  - [ ] VoIP notification type
  - [ ] Include caller info
- [ ] Create Cloud Function `sendFriendRequestNotification`

#### 10.3 Notification Handling
- [ ] Handle foreground notifications
  - [ ] Show banner
  - [ ] Update UI in real-time
  - [ ] Play sound
- [ ] Handle background notifications
  - [ ] Update badge count
  - [ ] Wake app if needed
- [ ] Handle notification tap
  - [ ] Deep link to conversation
  - [ ] Open friend request view
  - [ ] Accept/join call
- [ ] Implement notification categories
  - [ ] Quick reply from notification
  - [ ] Mark as read action
  - [ ] Accept/decline call actions

### Phase 11: Offline Support & Sync (Day 27)

#### 11.1 Offline Messaging
- [ ] Implement message queue
  - [ ] Store unsent messages locally
  - [ ] Retry when connection restored
  - [ ] Show "queued" status
- [ ] Build `NetworkMonitor.swift`
  - [ ] Monitor connection status
  - [ ] Notify services of changes
  - [ ] Display offline indicator
- [ ] Enable Firestore offline persistence
  - [ ] Configure cache size
  - [ ] Handle cache eviction
- [ ] Update UI for offline state
  - [ ] Disable calling features
  - [ ] Show "offline" banner
  - [ ] Queue AI requests

#### 11.2 Data Synchronization
- [ ] Implement sync on app launch
  - [ ] Fetch latest messages
  - [ ] Update conversations
  - [ ] Sync read receipts
- [ ] Handle sync conflicts
  - [ ] Server always wins
  - [ ] Merge strategies for complex types
- [ ] Background sync
  - [ ] Use Background Tasks framework
  - [ ] Sync messages periodically
  - [ ] Respect battery and data settings
- [ ] Optimize sync performance
  - [ ] Only fetch updates since last sync
  - [ ] Batch operations
  - [ ] Prioritize active conversations

### Phase 12: Polish & UX Improvements (Days 28-29)

#### 12.1 UI/UX Polish
- [ ] Design app icon
- [ ] Add launch screen
- [ ] Implement dark mode
  - [ ] Update color scheme
  - [ ] Test all views in dark mode
- [ ] Add loading states everywhere
  - [ ] Skeleton screens
  - [ ] Progress indicators
  - [ ] Pull-to-refresh
- [ ] Implement empty states
  - [ ] No conversations
  - [ ] No friends
  - [ ] No messages
  - [ ] No action items
- [ ] Add haptic feedback
  - [ ] Button taps
  - [ ] Message sent
  - [ ] Reactions added
  - [ ] Call actions
- [ ] Sound effects
  - [ ] Message sent/received
  - [ ] Call ringing
  - [ ] Notifications
- [ ] Animations
  - [ ] Message appear/disappear
  - [ ] Reaction animations
  - [ ] View transitions
  - [ ] Loading animations

#### 12.2 Accessibility
- [ ] VoiceOver support
  - [ ] Label all UI elements
  - [ ] Logical navigation order
  - [ ] Announce state changes
- [ ] Dynamic Type support
  - [ ] Scalable fonts
  - [ ] Layout adjusts to text size
- [ ] Color contrast
  - [ ] Ensure WCAG AA compliance
  - [ ] Test with grayscale
- [ ] Reduce motion option
  - [ ] Respect system setting
  - [ ] Alternative to animations

#### 12.3 Error Handling
- [ ] User-friendly error messages
- [ ] Retry mechanisms
- [ ] Graceful degradation
- [ ] Network error handling
- [ ] Validation feedback
- [ ] Crash recovery

#### 12.4 Performance Optimization
- [ ] Profile with Instruments
  - [ ] Identify memory leaks
  - [ ] Optimize slow operations
  - [ ] Reduce main thread blocking
- [ ] Optimize image loading
  - [ ] Implement image caching
  - [ ] Lazy loading
  - [ ] Compression
- [ ] Optimize Firestore queries
  - [ ] Add indexes
  - [ ] Limit query size
  - [ ] Use pagination
- [ ] Reduce battery usage
  - [ ] Optimize location updates
  - [ ] Efficient sync strategy
  - [ ] Background task management

### Phase 13: Testing (Days 30-31)

#### 13.1 Unit Tests
- [ ] Test ViewModels
  - [ ] Mock services
  - [ ] Test business logic
  - [ ] Edge cases
- [ ] Test Services
  - [ ] Authentication flows
  - [ ] Message sending/receiving
  - [ ] Encryption/decryption
  - [ ] API calls
- [ ] Test Utilities
  - [ ] Extensions
  - [ ] Helpers
  - [ ] Formatters

#### 13.2 UI Tests
- [ ] Test authentication flow
  - [ ] Sign up
  - [ ] Login
  - [ ] Logout
- [ ] Test messaging flow
  - [ ] Send message
  - [ ] Receive message
  - [ ] React to message
  - [ ] Edit message
- [ ] Test friend management
- [ ] Test AI assistant
- [ ] Test translation feature

#### 13.3 Integration Testing
- [ ] Test with real Firebase
- [ ] Test on multiple devices
  - [ ] iPhone (various models)
  - [ ] iPad
  - [ ] Different iOS versions
- [ ] Test offline scenarios
- [ ] Test poor network conditions
- [ ] Test background/foreground transitions
- [ ] Test push notifications
- [ ] Test calling (audio & video)
- [ ] Test Pinecone integration
  - [ ] Message embedding generation and indexing
  - [ ] Semantic search accuracy
  - [ ] Query performance (latency < 2s)
  - [ ] Namespace isolation (users can't see others' data)
  - [ ] Metadata filtering (conversation, date range)
  - [ ] Vector deletion on message/user deletion
  - [ ] Error handling (rate limits, timeouts)
  - [ ] Cost monitoring and optimization

#### 13.4 Security Testing
- [ ] Test encryption end-to-end
- [ ] Test key exchange
- [ ] Verify Firestore rules
- [ ] Test authentication edge cases
- [ ] Check for data leaks

### Phase 14: Deployment & Documentation (Days 32-33)

#### 14.1 App Store Preparation
- [ ] Create App Store Connect listing
- [ ] Prepare app screenshots
- [ ] Write app description
- [ ] Set up privacy policy
- [ ] Configure app permissions justifications
- [ ] Create promotional materials
- [ ] Set pricing and availability

#### 14.2 Beta Testing
- [ ] Deploy to TestFlight
- [ ] Invite beta testers
- [ ] Collect feedback
- [ ] Fix critical bugs
- [ ] Iterate based on feedback

#### 14.3 Documentation
- [ ] Write README.md
  - [ ] Project overview
  - [ ] Features list
  - [ ] Screenshots
  - [ ] Setup instructions
  - [ ] Architecture overview
- [ ] Document Firebase setup
  - [ ] Cloud Functions deployment
  - [ ] Security rules configuration
  - [ ] Environment variables
- [ ] Document API keys setup
  - [ ] OpenAI API key (https://platform.openai.com/api-keys)
    - [ ] Required for: GPT-4o, Whisper, text-embedding-3-large
    - [ ] Billing setup required
  - [ ] Pinecone API key (https://www.pinecone.io)
    - [ ] Create account and project
    - [ ] Generate API key from console
    - [ ] Note environment/region
    - [ ] Create index with proper configuration
  - [ ] Firebase config
    - [ ] GoogleService-Info.plist for iOS
    - [ ] Service account key for Cloud Functions
    - [ ] Functions config for API keys
- [ ] Code documentation
  - [ ] Add comments to complex functions
  - [ ] Document service interfaces
  - [ ] Create architecture diagrams
- [ ] Create user guide (optional)

#### 14.4 Final Checks
- [ ] Review all features against requirements
- [ ] Test on physical devices (not just simulator)
- [ ] Verify all AI features working
- [ ] Check analytics setup
- [ ] Review privacy policy
- [ ] Final code review
- [ ] Merge to main branch
- [ ] Tag release version

---

## Estimated Timeline

**Total Duration:** ~6-8 weeks (assuming full-time work)

| Phase | Days | Description |
|-------|------|-------------|
| 1 | 2 | Project setup & authentication |
| 2 | 2 | Friends system |
| 3 | 3 | Core messaging |
| 4 | 3 | Rich messaging features |
| 4.5 | 1 | **Group chat** |
| 5 | 3 | Voice/video calling |
| 6 | 2 | Security & encryption |
| 7 | 2 | Translation AI |
| 8 | 4 | RAG & conversation intelligence |
| 9 | 3 | AI chat assistant |
| 10 | 1 | Push notifications |
| 11 | 1 | Offline support |
| 12 | 2 | Polish & UX |
| 13 | 2 | Testing |
| 14 | 2 | Deployment & docs |
| **Total** | **33 days** | |

*Note: Timeline can be adjusted based on priorities. MVP (Phases 1-4.5) can be completed in 8-12 days and includes full messaging with groups.*

---

## Key Dependencies & Tools

### iOS Development
- Xcode 15+
- Swift 5.9+
- iOS 17.0+ target
- CocoaPods or Swift Package Manager

### Firebase Services
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Cloud Functions for Firebase
- Firebase Cloud Messaging
- Firebase Extensions (optional)

### AI & ML Services
- OpenAI API (GPT-4o, Whisper, text-embedding-3-large)
- Pinecone (vector database for embeddings storage and similarity search)

### WebRTC
- WebRTC framework for iOS
- STUN/TURN servers (Twilio, Xirsys, or self-hosted)

### Additional Tools
- Git for version control
- Postman for API testing
- Firebase Emulator Suite for local testing
- TestFlight for beta distribution

---

## AI Integration Details

### OpenAI GPT-4o Use Cases
1. **Translation:** Context-aware message translation
2. **Summarization:** Conversation thread summaries
3. **Action Items:** Extract tasks from conversations
4. **Decision Tracking:** Identify and log decisions
5. **Priority Detection:** Classify message urgency
6. **AI Assistant:** Natural language queries about conversations
7. **Function Calling:** Route assistant commands to appropriate functions

### RAG Pipeline Components
1. **Embedding Generation:** Convert messages to vectors (OpenAI text-embedding-3-large, 1536 dimensions)
2. **Vector Storage:** Pinecone serverless index with user-specific namespaces
3. **Similarity Search:** Pinecone cosine similarity search with metadata filtering
4. **Context Assembly:** Retrieve full encrypted messages from Firestore using Pinecone result IDs
5. **LLM Generation:** GPT-4o answers questions using retrieved context with citations
6. **Caching:** Store embeddings in Pinecone + reference in Firestore for efficiency
7. **Metadata Filtering:** Filter by conversation, user, timestamp, message type in Pinecone queries

### Pinecone Implementation Details

#### Index Configuration
```javascript
{
  name: "messaging-app-vectors",
  dimension: 1536,
  metric: "cosine",
  spec: {
    serverless: {
      cloud: "gcp",
      region: "us-east1"
    }
  }
}
```

#### Namespace Strategy
- **User-based namespaces:** `user_{userId}` - All messages accessible to a user
- **Benefits:** Easy access control, simplified queries, better privacy isolation
- **Drawbacks:** May need cross-namespace queries for shared conversations

#### Vector Metadata Schema
```javascript
{
  messageId: "msg_123",           // Firestore document ID
  conversationId: "conv_456",     // For filtering
  senderId: "user_789",           // Message author
  recipientId: "user_012",        // For DMs
  timestamp: 1698345600000,       // Unix timestamp
  messageType: "text",            // text | voice | image
  preview: "Hey, let's meet...",  // First 100 chars (searchable)
  language: "en"                  // Detected language
}
```

#### Querying Best Practices
1. **Always include namespace** - Ensures user data isolation
2. **Use metadata filters** - Reduce search space before vector similarity
3. **Limit topK** - Start with 10, adjust based on use case
4. **Include metadata in response** - Avoid extra Firestore reads
5. **Handle empty results** - Graceful fallback when no matches found
6. **Batch upserts** - When indexing multiple messages (up to 100 per batch)

#### Cost Optimization
- **Serverless pricing:** Pay per read/write operation
- **Batch operations:** Reduce API calls by grouping upserts
- **Selective indexing:** Skip system messages, very short messages
- **TTL/Deletion:** Remove old vectors if not needed (GDPR compliance)
- **Monitor usage:** Track read/write units in Pinecone dashboard

#### Error Handling
- **Rate limits:** Implement exponential backoff and retry logic
- **Timeout errors:** Set reasonable timeout (5-10s for queries)
- **Index not ready:** Wait for index to be ready after creation
- **Namespace not found:** Create namespace on first insert
- **Vector dimension mismatch:** Validate embedding size before upsert

### Privacy Considerations
- Opt-in for AI features (user consent)
- Clear disclosure when messages sent to AI
- Option to disable AI per conversation
- No permanent storage of unencrypted content on server
- Client-side encryption before AI processing (where possible)

---

## Success Metrics

### Technical Metrics
- [ ] Message delivery within 500ms (online users)
- [ ] 99.9% message delivery reliability
- [ ] Zero data loss during offline scenarios
- [ ] AI response time < 3 seconds
- [ ] Call connection time < 2 seconds
- [ ] App cold start < 2 seconds

### User Experience Metrics
- [ ] Users can catch up on conversations 80% faster with AI summaries
- [ ] 100% action item capture rate
- [ ] Information retrieval 3x faster with semantic search
- [ ] Translation accuracy > 95%
- [ ] Call quality rating > 4/5 stars

---

## Risk Management

### Technical Risks
| Risk | Mitigation |
|------|------------|
| WebRTC complexity | Use proven library, allocate extra time |
| E2E encryption performance | Implement incrementally, profile early |
| AI API costs | Implement caching, rate limiting, user quotas |
| Firestore at scale | Design efficient queries, use indexes |
| Offline sync conflicts | Server-wins strategy, clear user communication |

### Product Risks
| Risk | Mitigation |
|------|------------|
| Feature scope creep | Strict MVP definition, prioritize P0 features |
| AI accuracy issues | Iterative prompt engineering, user feedback |
| Privacy concerns | Clear communication, opt-in, privacy policy |
| User adoption | Beta testing, gather feedback early |

---

## Pinecone Code Examples

### Example 1: Initialize Pinecone Client (Cloud Function)

```typescript
// firebase/functions/src/utils/pinecone.ts
import { Pinecone } from '@pinecone-database/pinecone';

let pineconeClient: Pinecone | null = null;

export async function getPineconeClient(): Promise<Pinecone> {
  if (!pineconeClient) {
    pineconeClient = new Pinecone({
      apiKey: functions.config().pinecone.key,
      environment: functions.config().pinecone.environment,
    });
  }
  return pineconeClient;
}

export async function getPineconeIndex() {
  const client = await getPineconeClient();
  return client.index(functions.config().pinecone.index);
}
```

### Example 2: Index Message with Embedding

```typescript
// firebase/functions/src/ai/indexMessage.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { getPineconeIndex } from '../utils/pinecone';
import { generateEmbedding } from './embeddings';

export const indexMessage = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const { conversationId, messageId } = context.params;
    
    // Skip if message is not text or user opted out
    if (messageData.type !== 'text' || messageData.skipAI) {
      return;
    }

    try {
      // Generate embedding
      const embedding = await generateEmbedding(messageData.text);
      
      // Get Pinecone index
      const index = await getPineconeIndex();
      
      // Upsert vector to Pinecone with metadata
      await index.namespace(`user_${messageData.senderId}`).upsert([{
        id: messageId,
        values: embedding,
        metadata: {
          conversationId,
          senderId: messageData.senderId,
          timestamp: messageData.timestamp.toMillis(),
          messageType: 'text',
          preview: messageData.text.substring(0, 100),
        },
      }]);
      
      // Update Firestore with indexing status
      await admin.firestore()
        .collection('embeddings')
        .doc(messageId)
        .set({
          conversationId,
          messageId,
          pineconeId: messageId,
          indexed: true,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      console.log(`Indexed message ${messageId} to Pinecone`);
    } catch (error) {
      console.error('Error indexing message:', error);
      // Log error but don't fail the message creation
    }
  });
```

### Example 3: Semantic Search with Pinecone

```typescript
// firebase/functions/src/ai/semanticSearch.ts
import * as functions from 'firebase-functions';
import { getPineconeIndex } from '../utils/pinecone';
import { generateEmbedding } from './embeddings';

export const semanticSearch = functions.https.onCall(async (data, context) => {
  // Ensure user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const { query, conversationId, topK = 10 } = data;
  const userId = context.auth.uid;
  
  try {
    // Generate query embedding
    const queryEmbedding = await generateEmbedding(query);
    
    // Query Pinecone
    const index = await getPineconeIndex();
    const queryRequest: any = {
      vector: queryEmbedding,
      topK,
      includeMetadata: true,
    };
    
    // Add conversation filter if specified
    if (conversationId) {
      queryRequest.filter = { conversationId };
    }
    
    const results = await index.namespace(`user_${userId}`).query(queryRequest);
    
    // Extract message IDs and scores
    const matches = results.matches.map((match: any) => ({
      messageId: match.id,
      score: match.score,
      metadata: match.metadata,
    }));
    
    return {
      success: true,
      results: matches,
      query,
    };
  } catch (error) {
    console.error('Semantic search error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to perform search');
  }
});
```

### Example 4: RAG Query (iOS Swift)

```swift
// ios/messagingapp/messagingapp/Services/RAGService.swift
import Foundation
import FirebaseFunctions

class RAGService {
    private let functions = Functions.functions()
    
    func semanticSearch(query: String, conversationId: String? = nil) async throws -> [SearchResult] {
        let callable = functions.httpsCallable("semanticSearch")
        
        var parameters: [String: Any] = [
            "query": query,
            "topK": 10
        ]
        
        if let conversationId = conversationId {
            parameters["conversationId"] = conversationId
        }
        
        let result = try await callable.call(parameters)
        
        guard let data = result.data as? [String: Any],
              let results = data["results"] as? [[String: Any]] else {
            throw RAGError.invalidResponse
        }
        
        return results.compactMap { SearchResult(from: $0) }
    }
    
    func answerQuestion(_ question: String, conversationId: String? = nil) async throws -> String {
        let callable = functions.httpsCallable("answerQuestionWithRAG")
        
        let parameters: [String: Any] = [
            "question": question,
            "conversationId": conversationId as Any
        ]
        
        let result = try await callable.call(parameters)
        
        guard let data = result.data as? [String: Any],
              let answer = data["answer"] as? String else {
            throw RAGError.invalidResponse
        }
        
        return answer
    }
}

struct SearchResult {
    let messageId: String
    let score: Double
    let preview: String
    let timestamp: Date
    
    init?(from dict: [String: Any]) {
        guard let messageId = dict["messageId"] as? String,
              let score = dict["score"] as? Double,
              let metadata = dict["metadata"] as? [String: Any],
              let preview = metadata["preview"] as? String,
              let timestamp = metadata["timestamp"] as? TimeInterval else {
            return nil
        }
        
        self.messageId = messageId
        self.score = score
        self.preview = preview
        self.timestamp = Date(timeIntervalSince1970: timestamp / 1000)
    }
}
```

---

## Next Steps

1. **Review this plan** - Adjust timeline and priorities based on constraints
2. **Set up development environment** - Install Xcode, Firebase, get API keys
3. **Create Firebase project** - Set up backend infrastructure
4. **Set up Pinecone account** (for Phase 8+):
   - Create account at https://www.pinecone.io
   - Create index: `messaging-app-vectors` (1536 dims, cosine metric)
   - Generate and save API key
   - Note environment/region for Cloud Functions config
5. **Obtain API keys**:
   - OpenAI API key (https://platform.openai.com)
   - Pinecone API key (from step 4)
   - Configure Firebase Functions environment variables
6. **Start with Phase 1** - Build authentication foundation
7. **Iterate rapidly** - Build MVP first (Phases 1-4.5), then add AI features (Phases 7-9)
8. **Test early and often** - Real devices, real users, real feedback
9. **Document as you go** - Save time during final documentation phase
10. **Monitor costs** - Track OpenAI and Pinecone usage, optimize as needed

---

## Notes

- This plan is comprehensive and can be adjusted based on your specific needs
- Focus on MVP first (Phases 1-3) to get a working messaging app
- AI features (Phases 7-9) can be added incrementally
- Consider parallel development where possible (e.g., UI while backend is being built)
- Regular testing throughout development is crucial for quality
- Don't underestimate time needed for polish and bug fixes

### Pinecone Vector Database Notes
- **Cost:** Pinecone pricing starts with a serverless free tier, then pay-as-you-go
  - Serverless: ~$0.096 per million read units, ~$0.12 per million write units
  - Consider starting with serverless, upgrade to pod-based for predictable costs at scale
- **Alternatives:** If budget is constrained, consider:
  - Chroma DB (free, open-source, self-hosted)
  - Qdrant (1GB free tier, or self-hosted)
  - Firestore-only approach (less performant but free)
  - See [VECTOR_STORE_OPTIONS.md](./VECTOR_STORE_OPTIONS.md) for comparison
- **When to use Pinecone:**
  - You need production-grade performance and reliability
  - You're building for scale (10k+ users)
  - You have budget for managed services (~$25-100/month)
  - You want minimal DevOps overhead
- **Migration path:** Easy to switch between vector stores by updating Cloud Functions

---

**Document Status:** Ready for Implementation  
**Last Updated:** October 23, 2025  
**Version:** 1.2 - Reimplemented with Pinecone Vector Database

**Change Log:**
- v1.2 (Oct 23, 2025): Reimplemented vector storage to use Pinecone exclusively
  - Added detailed Pinecone setup and configuration steps
  - Expanded Phase 8 with Pinecone-specific implementation details
  - Added Pinecone metadata schema and best practices
  - Updated environment setup with Pinecone API keys
  - Added cost optimization and error handling strategies
- v1.1 (Oct 21, 2025): Added Phase 4.5: Group Chat
- v1.0: Initial implementation plan


