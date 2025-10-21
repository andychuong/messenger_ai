# MessageAI - Intelligent Messaging App

An iOS messaging application with AI-powered features including translation, voice-to-text, and conversation intelligence.

## 🚀 Features

- **Secure Messaging**: End-to-end encrypted messaging with read receipts
- **Friends System**: Add friends by email, manage connections
- **Rich Media**: Send images, voice messages with AI transcription
- **Emoji Reactions**: Full iOS emoji keyboard like iMessage
- **Voice/Video Calls**: Real-time calling with WebRTC
- **Message Threading**: Organize conversations with threads
- **AI Translation**: Translate messages on-demand or via long-press
- **AI Assistant**: Ask questions about your conversations
- **Smart Search**: Semantic search powered by RAG
- **Action Items**: Automatically extract tasks from conversations
- **Voice-to-Text**: AI-powered transcription using Whisper

## 📁 Project Structure

```
MessagingApp/
├── ios/              # iOS app (Swift/SwiftUI)
├── firebase/         # Backend (Cloud Functions, Firestore)
├── APP_PLAN.md      # Detailed implementation plan
└── README.md        # This file
```

## 🛠 Tech Stack

### Frontend (iOS)
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Local Storage**: SwiftData
- **Minimum iOS**: 17.0
- **Architecture**: MVVM + Repository Pattern

### Backend (Firebase)
- **Authentication**: Firebase Auth
- **Database**: Cloud Firestore
- **Storage**: Firebase Storage
- **Functions**: Cloud Functions (Node.js/TypeScript)
- **Messaging**: Firebase Cloud Messaging

### AI Services
- **LLM**: OpenAI GPT-4o
- **Embeddings**: text-embedding-3-large
- **Voice-to-Text**: Whisper API
- **Vector Store**: Pinecone

## 📋 Prerequisites

### For iOS Development
- macOS with Xcode 15+
- iOS 17.0+ device or simulator
- Apple Developer account (for device testing)
- CocoaPods or Swift Package Manager

### For Firebase Backend
- Node.js 18+ and npm
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase account (free tier works for development)

### For AI Features
- OpenAI API key
- Pinecone account (optional, for vector search)

## 🚦 Getting Started

### 1. Clone the Repository

```bash
cd "/Users/andychuong/Documents/GauntletAI/Week 2/MessagingApp"
```

### 2. Set Up Firebase Backend

```bash
# Navigate to firebase directory
cd firebase

# Install dependencies
npm install

# Login to Firebase
firebase login

# Initialize Firebase project (if not already done)
firebase init

# Deploy Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes

# Deploy Cloud Functions
firebase deploy --only functions
```

### 3. Configure Environment Variables

Create `firebase/functions/.env` file:

```env
OPENAI_API_KEY=your_openai_api_key_here
PINECONE_API_KEY=your_pinecone_api_key_here
PINECONE_ENVIRONMENT=your_pinecone_environment
PINECONE_INDEX_NAME=messageai-embeddings
```

### 4. Set Up iOS App

```bash
# Navigate to ios directory
cd ../ios

# Open Xcode project
open MessagingApp.xcodeproj

# Or if using workspace
open MessagingApp.xcworkspace
```

**In Xcode:**
1. Add your `GoogleService-Info.plist` (download from Firebase Console)
2. Configure your bundle identifier
3. Set up signing & capabilities
4. Add Firebase SDK via Swift Package Manager
5. Build and run on simulator or device

### 5. Install Firebase SDK (Swift Package Manager)

In Xcode:
1. File → Add Package Dependencies
2. Add: `https://github.com/firebase/firebase-ios-sdk`
3. Select packages:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage
   - FirebaseMessaging

## 🔧 Configuration

### Firebase Console Setup

1. **Create Firebase Project**: https://console.firebase.google.com
2. **Enable Authentication**: Email/Password provider
3. **Create Firestore Database**: Start in test mode (update rules later)
4. **Enable Firebase Storage**: For image/media storage
5. **Add iOS App**: Download `GoogleService-Info.plist`
6. **Set up Cloud Messaging**: For push notifications
7. **Create Service Account**: For Cloud Functions admin access

### Firestore Security Rules

Located in `firebase/firestore.rules` - deploy with:
```bash
firebase deploy --only firestore:rules
```

### OpenAI Setup

1. Create account at https://platform.openai.com
2. Generate API key
3. Add to `firebase/functions/.env`
4. Set up billing (pay-as-you-go)

### Pinecone Setup (Optional)

1. Create account at https://www.pinecone.io
2. Create index: `messageai-embeddings`
3. Dimensions: 1536 (for text-embedding-3-large)
4. Metric: cosine
5. Add credentials to `.env`

## 🧪 Testing

### Run iOS Tests
```bash
# In Xcode, press Cmd+U or:
xcodebuild test -scheme MessagingApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Test Cloud Functions Locally
```bash
cd firebase/functions
npm test

# Or use Firebase Emulator
firebase emulators:start
```

### Test on Physical Device
1. Connect iPhone via USB
2. Select device in Xcode
3. Build and run (Cmd+R)
4. Test with two devices for messaging/calling

## 📱 Development Workflow

### Phase 1: MVP (Week 1)
- [ ] User authentication
- [ ] Friends system
- [ ] Basic messaging
- [ ] Read receipts

### Phase 2: Rich Features (Week 2)
- [ ] Emoji reactions
- [ ] Image sharing
- [ ] Voice messages
- [ ] Message editing

### Phase 3: Calling (Week 3)
- [ ] WebRTC integration
- [ ] Audio calls
- [ ] Video calls

### Phase 4: Security (Week 4)
- [ ] End-to-end encryption
- [ ] Key management

### Phase 5: AI Features (Weeks 5-6)
- [ ] Translation
- [ ] Voice-to-text
- [ ] RAG pipeline
- [ ] AI assistant

See [APP_PLAN.md](./APP_PLAN.md) for detailed task list.

## 🏗 Architecture Overview

```
┌─────────────┐
│   iOS App   │
│ (Swift/UI)  │
└──────┬──────┘
       │
       ├──────────────┐
       │              │
┌──────▼──────┐  ┌───▼────────┐
│  Firebase   │  │   OpenAI   │
│  Backend    │  │  GPT-4o    │
│ (Firestore, │  │  Whisper   │
│  Functions) │  │ Embeddings │
└─────────────┘  └────────────┘
       │
┌──────▼──────┐
│  Pinecone   │
│  (Vectors)  │
└─────────────┘
```

## 🔐 Security Best Practices

- Never commit API keys or `GoogleService-Info.plist`
- Use Keychain for storing encryption keys
- Implement proper Firestore security rules
- Enable App Transport Security
- Use HTTPS for all API calls
- Implement rate limiting in Cloud Functions

## 📊 Performance Targets

- Message delivery: < 500ms
- AI response time: < 3s
- App cold start: < 2s
- Call connection: < 2s
- Message delivery reliability: 99.9%

## 🐛 Troubleshooting

### iOS Build Fails
- Clean build folder: Shift+Cmd+K
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Update pods: `pod update`

### Firebase Connection Issues
- Check `GoogleService-Info.plist` is added
- Verify Firebase initialization in AppDelegate
- Check Firestore rules allow your operations

### Cloud Functions Not Deploying
- Check Node.js version: `node --version` (should be 18+)
- Verify Firebase CLI: `firebase --version`
- Check for syntax errors: `npm run build`

## 📖 Documentation

- [APP_PLAN.md](./APP_PLAN.md) - Complete implementation plan
- [Firebase Documentation](https://firebase.google.com/docs)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [OpenAI API Docs](https://platform.openai.com/docs)

## 🤝 Contributing

This is a personal project for learning purposes. See APP_PLAN.md for development roadmap.

## 📝 License

Private project - All rights reserved.

## 👤 Author

Andy Chuong

---

**Project Status**: 🚧 In Development

**Last Updated**: October 20, 2025

