# MessageAI - Implementation Plan

## Executive Summary

**Platform:** iOS (Swift/SwiftUI)  
**Backend:** Firebase (Firestore, Authentication, Storage, Cloud Functions)  
**AI Integration:** GPT-4o, RAG Pipelines for conversation intelligence  
**Core Features:** Secure messaging, voice/video calls, AI-powered translation & conversation analysis

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
Embeddings: OpenAI text-embedding-3-large
Vector Store: Pinecone or Firestore with pgvector
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
  - embedding: array[1536] (or reference to Pinecone)
  - text: string (unencrypted snippet for search)
  - timestamp: timestamp

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
│   │   ├── RAGService.swift
│   │   └── EmbeddingService.swift
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
│           OpenAI Embeddings API (1536 dims)                  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                Vector Similarity Search                      │
│        Pinecone: Top 10 relevant messages by cosine          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Context Assembly                            │
│   Retrieve full messages + metadata from Firestore          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   LLM Generation                             │
│   GPT-4o: Answer question with retrieved context            │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                 Stream Response to User                      │
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
  - [ ] Install dependencies (firebase-admin, openai, etc.)
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

### Phase 5: Voice/Video Calling (Days 11-13)

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

### Phase 6: Security & Encryption (Days 14-15)

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

### Phase 7: AI Features - Translation (Days 16-17)

#### 7.1 Translation Service
- [ ] Create Cloud Function `translateMessage`
  - [ ] Accept message text + target language
  - [ ] Call OpenAI GPT-4o with translation prompt
  - [ ] Return translated text
  - [ ] Cache translations in Firestore
- [ ] Build `TranslationService.swift` (iOS)
  - [ ] Call translation Cloud Function
  - [ ] Cache translations locally
  - [ ] Handle errors gracefully
- [ ] Create `TranslationViewModel.swift`

#### 7.2 Translation UI
- [ ] Build `TranslationMenuView.swift`
  - [ ] List of languages
  - [ ] "Auto-detect" option
  - [ ] Recently used languages
  - [ ] Search languages
- [ ] Add long-press gesture to `MessageRow`
  - [ ] Show context menu
  - [ ] "Translate" option
  - [ ] Display translation in overlay/modal
- [ ] Display cached translations
  - [ ] Toggle between original and translated
  - [ ] Show "Translated from X" label
- [ ] Add loading indicator during translation
- [ ] Handle translation errors

### Phase 8: AI Features - RAG & Conversation Intelligence (Days 18-21)

#### 8.1 Embedding Pipeline
- [ ] Create Cloud Function `generateEmbedding`
  - [ ] Accept message text
  - [ ] Call OpenAI embeddings API (text-embedding-3-large)
  - [ ] Return embedding vector (1536 dimensions)
- [ ] Set up Pinecone account and index
  - [ ] Create index with 1536 dimensions
  - [ ] Set up namespace per user
- [ ] Create Cloud Function `indexMessage`
  - [ ] Triggered on new message
  - [ ] Generate embedding
  - [ ] Store in Pinecone with metadata
  - [ ] Alternative: Store in Firestore
- [ ] Handle encryption considerations
  - [ ] Store unencrypted snippet for indexing (with consent)
  - [ ] Or index on-device (limited scale)

#### 8.2 RAG Search Service
- [ ] Create Cloud Function `semanticSearch`
  - [ ] Accept query text
  - [ ] Generate query embedding
  - [ ] Search Pinecone for similar messages
  - [ ] Return top N results with scores
  - [ ] Fetch full messages from Firestore
- [ ] Build `RAGService.swift` (iOS)
  - [ ] Call semantic search function
  - [ ] Process results
  - [ ] Rank by relevance
- [ ] Create Cloud Function `answerQuestion`
  - [ ] Accept user question
  - [ ] Perform semantic search
  - [ ] Assemble context from results
  - [ ] Call GPT-4o with context + question
  - [ ] Stream response back

#### 8.3 Action Item Extraction
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

#### 8.4 Decision Tracking
- [ ] Create Cloud Function `detectDecision`
  - [ ] Analyze message for decisions
  - [ ] Extract: decision, who, rationale, date
  - [ ] Store in `/decisions` collection
- [ ] Build `DecisionLogView.swift`
  - [ ] Chronological list
  - [ ] Expandable cards
  - [ ] Search functionality
  - [ ] Link to original conversation

#### 8.5 Priority Message Detection
- [ ] Create Cloud Function `classifyPriority`
  - [ ] Real-time or batch processing
  - [ ] Check for: mentions, questions, deadlines
  - [ ] Return priority score + reason
  - [ ] Update message metadata
- [ ] Update `ConversationListView` to show priority indicator
  - [ ] Red badge for priority conversations
  - [ ] Filter/sort by priority
- [ ] Create "Priority Messages" inbox view

### Phase 9: AI Chat Assistant (Days 22-24)

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

### Phase 10: Push Notifications (Day 25)

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

### Phase 11: Offline Support & Sync (Day 26)

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

### Phase 12: Polish & UX Improvements (Days 27-28)

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

### Phase 13: Testing (Days 29-30)

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

#### 13.4 Security Testing
- [ ] Test encryption end-to-end
- [ ] Test key exchange
- [ ] Verify Firestore rules
- [ ] Test authentication edge cases
- [ ] Check for data leaks

### Phase 14: Deployment & Documentation (Days 31-32)

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
  - [ ] OpenAI API key
  - [ ] Pinecone API key
  - [ ] Firebase config
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
| **Total** | **32 days** | |

*Note: Timeline can be adjusted based on priorities. MVP (Phases 1-3) can be completed in 7-10 days.*

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
- OpenAI API (GPT-4o, Whisper, Embeddings)
- Pinecone (vector database) or alternative

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
1. **Embedding Generation:** Convert messages to vectors (text-embedding-3-large)
2. **Vector Storage:** Pinecone index with user namespaces
3. **Similarity Search:** Find relevant messages by semantic meaning
4. **Context Assembly:** Retrieve full messages with metadata
5. **LLM Generation:** Answer questions using retrieved context
6. **Caching:** Store embeddings and responses for efficiency

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

## Next Steps

1. **Review this plan** - Adjust timeline and priorities based on constraints
2. **Set up development environment** - Install Xcode, Firebase, get API keys
3. **Create Firebase project** - Set up backend infrastructure
4. **Start with Phase 1** - Build authentication foundation
5. **Iterate rapidly** - Build MVP first, then add AI features
6. **Test early and often** - Real devices, real users, real feedback
7. **Document as you go** - Save time during final documentation phase

---

## Notes

- This plan is comprehensive and can be adjusted based on your specific needs
- Focus on MVP first (Phases 1-3) to get a working messaging app
- AI features (Phases 7-9) can be added incrementally
- Consider parallel development where possible (e.g., UI while backend is being built)
- Regular testing throughout development is crucial for quality
- Don't underestimate time needed for polish and bug fixes

---

**Document Status:** Ready for Implementation  
**Last Updated:** October 20, 2025  
**Version:** 1.0


