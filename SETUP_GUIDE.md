# MessageAI - Complete Setup Guide

Step-by-step guide to get your development environment ready.

## Prerequisites Checklist

- [ ] macOS (for iOS development)
- [ ] Xcode 15+ installed
- [ ] Node.js 18+ installed
- [ ] Firebase account created
- [ ] OpenAI API key obtained
- [ ] Git installed

---

## Part 1: Firebase Backend Setup

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add Project"
3. Name it "MessageAI" (or your preferred name)
4. Disable Google Analytics (optional for development)
5. Click "Create Project"

### Step 2: Enable Firebase Services

**Authentication:**
1. In Firebase Console, go to "Authentication"
2. Click "Get Started"
3. Enable "Email/Password" sign-in method

**Firestore Database:**
1. Go to "Firestore Database"
2. Click "Create Database"
3. Start in "Test Mode" (we'll deploy rules later)
4. Choose location closest to you

**Firebase Storage:**
1. Go to "Storage"
2. Click "Get Started"
3. Start in test mode
4. Use default storage location

**Cloud Messaging:**
1. Go to "Cloud Messaging"
2. Note your Server Key (for later)

### Step 3: Set Up Firebase CLI

```bash
# Install Firebase CLI globally
npm install -g firebase-tools

# Login to Firebase
firebase login

# Navigate to project directory
cd "/Users/andychuong/Documents/GauntletAI/Week 2/MessagingApp/firebase"

# Initialize Firebase (select your project)
firebase use --add

# Install function dependencies
cd functions
npm install
```

### Step 4: Configure Environment Variables

```bash
# In firebase/functions directory
cp env_example.txt .env

# Edit .env and add your API key
nano .env
```

**Required:**
- `OPENAI_API_KEY` - Get from https://platform.openai.com/api-keys

**That's it!** No other API keys needed. The app uses Firestore for vector storage (free).

### Step 5: Deploy Firebase Backend

```bash
# From firebase/ directory
cd "/Users/andychuong/Documents/GauntletAI/Week 2/MessagingApp/firebase"

# Deploy Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes,storage:rules

# Build and deploy Cloud Functions
firebase deploy --only functions

# Verify deployment
firebase functions:log
```

---

## Part 2: iOS App Setup

### Step 1: Download Firebase Config

1. In Firebase Console, click gear icon → "Project Settings"
2. Scroll to "Your apps"
3. Click iOS icon to add iOS app
4. Register app:
   - **Bundle ID**: `com.yourname.messagingapp` (choose unique ID)
   - **App nickname**: MessageAI
   - Skip App Store ID
5. Download `GoogleService-Info.plist`
6. Save it (you'll add to Xcode later)

### Step 2: Create Xcode Project

1. Open Xcode
2. File → New → Project
3. Select "iOS" → "App"
4. Configuration:
   - **Product Name**: MessagingApp
   - **Team**: Select your Apple Developer account
   - **Organization Identifier**: `com.yourname` (should match Firebase bundle ID)
   - **Bundle Identifier**: Should auto-fill to match what you registered
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: SwiftData
   - **Include Tests**: ✓ (checked)
5. **Save Location**: Navigate to and select:
   ```
   /Users/andychuong/Documents/GauntletAI/Week 2/MessagingApp/ios/
   ```
6. Click "Create"

### Step 3: Add GoogleService-Info.plist

1. In Xcode Project Navigator (left sidebar)
2. Right-click on "MessagingApp" folder
3. Select "Add Files to MessagingApp..."
4. Navigate to your downloaded `GoogleService-Info.plist`
5. Check "Copy items if needed"
6. Ensure "MessagingApp" target is checked
7. Click "Add"

### Step 4: Add Firebase SDK

1. In Xcode: File → Add Package Dependencies
2. Enter URL: `https://github.com/firebase/firebase-ios-sdk`
3. Dependency Rule: "Up to Next Major Version" → 10.0.0
4. Click "Add Package"
5. Select these products:
   - ✓ FirebaseAuth
   - ✓ FirebaseFirestore
   - ✓ FirebaseStorage
   - ✓ FirebaseMessaging
6. Click "Add Package"

### Step 5: Configure App Capabilities

1. Select your project in Project Navigator
2. Select "MessagingApp" target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability" and add:
   - **Push Notifications**
   - **Background Modes** (check):
     - Audio, AirPlay, and Picture in Picture
     - Voice over IP
     - Background fetch
     - Remote notifications

### Step 6: Update Info.plist

1. In Project Navigator, find `Info.plist`
2. Right-click → "Open As" → "Source Code"
3. Add before `</dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is needed for video calls and profile pictures.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for voice calls and voice messages.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is needed to send images.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Permission is needed to save images from messages.</string>
```

### Step 7: Test Build

1. Select iPhone simulator (top toolbar)
2. Press Cmd+B to build
3. If successful, press Cmd+R to run
4. You should see the default SwiftUI "Hello, World!" app

---

## Part 3: API Keys & External Services

### OpenAI API Setup

1. Go to https://platform.openai.com
2. Sign up / Log in
3. Go to API Keys section
4. Create new secret key
5. Copy and save securely
6. Add to `firebase/functions/.env`:
   ```
   OPENAI_API_KEY=sk-...your-key-here
   ```
7. Set up billing (pay-as-you-go)
8. Set usage limits (recommended: $10/month for development)

### Vector Storage: Using Firestore (FREE!)

**Good news:** You don't need Pinecone or any external vector database!

This project uses **Firestore** for storing embeddings:
- ✅ **Completely free** (within generous Firebase limits)
- ✅ **Already set up** with your Firebase project
- ✅ **No additional configuration needed**
- ✅ **Perfect for MVP and beyond**

The semantic search functionality is implemented using:
- OpenAI embeddings stored in Firestore
- In-memory cosine similarity calculation
- Efficient for thousands of messages per user

**See [VECTOR_STORE_OPTIONS.md](./VECTOR_STORE_OPTIONS.md) for details about alternatives if you need to scale later.**

---

## Part 4: Verify Setup

### Test Firebase Backend

**Option 1: Deploy and Test (Recommended)**
```bash
cd "/Users/andychuong/Documents/GauntletAI/Week 2/MessagingApp/firebase"
firebase deploy --only firestore,functions
```

**Option 2: Local Emulators (Requires Java)**

If you have Java installed:
```bash
# Start emulators
firebase emulators:start

# In browser, go to: http://localhost:4000
# You should see Firebase Emulator Suite UI
```

**Note:** Emulators require Java. If you don't have it, just deploy directly to Firebase. The free tier is generous enough for development and testing.

### Test iOS App

1. In Xcode, open `MessagingAppApp.swift`
2. Add Firebase initialization:

```swift
import SwiftUI
import FirebaseCore

@main
struct MessagingAppApp: App {
    init() {
        FirebaseApp.configure()
        print("✅ Firebase configured!")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

3. Run app (Cmd+R)
4. Check console for "✅ Firebase configured!" message

---

## Part 5: Project Organization

### Create Folder Structure in Xcode

1. In Xcode Project Navigator, right-click "MessagingApp"
2. New Group (folder) for each:
   - App
   - Models
   - Views
     - Authentication
     - Conversations
     - Friends
     - AI
   - ViewModels
   - Services
   - Utilities
   - Resources

3. Move existing files:
   - `MessagingAppApp.swift` → App folder
   - `ContentView.swift` → Views folder
   - `Assets.xcassets` → Resources folder

---

## Troubleshooting

### Firebase Deploy Fails

**Error**: "Permission denied"
```bash
firebase login --reauth
firebase use --add
```

**Error**: "Node version too old"
```bash
node --version  # Should be 18+
nvm install 18
nvm use 18
```

### Xcode Build Fails

**Error**: "No such module 'Firebase'"
- File → Packages → Reset Package Cache
- File → Packages → Resolve Package Versions
- Clean Build Folder (Shift+Cmd+K)

**Error**: "Signing requires a development team"
- Select your target
- Signing & Capabilities
- Select your Team in "Team" dropdown
- Enable "Automatically manage signing"

### iOS Simulator Issues

**Simulator won't boot:**
```bash
# Quit Simulator
# In Terminal:
killall Simulator
xcrun simctl erase all
# Restart Xcode
```

---

## Next Steps

Once setup is complete:

1. ✅ Firebase project created and configured
2. ✅ Cloud Functions deployed
3. ✅ iOS Xcode project created
4. ✅ Firebase SDK integrated
5. ✅ API keys configured

**You're ready to start development!**

Proceed to [APP_PLAN.md](./APP_PLAN.md) Phase 1: User Authentication

---

## Quick Reference

### Firebase Commands
```bash
firebase login                              # Login
firebase use PROJECT_ID                     # Select project
firebase deploy                             # Deploy everything
firebase deploy --only firestore,functions  # Deploy rules and functions
firebase deploy --only functions            # Deploy functions only
firebase functions:log                      # View function logs
firebase emulators:start                    # Run local emulators (requires Java)
```

### Useful Xcode Shortcuts
```
Cmd+B         - Build
Cmd+R         - Run
Cmd+.         - Stop
Cmd+Shift+K   - Clean Build
Cmd+U         - Run Tests
Cmd+/         - Comment/Uncomment
Cmd+Shift+F   - Find in Project
```

### Development URLs
- Firebase Console: https://console.firebase.google.com
- Firebase Emulator UI: http://localhost:4000 (if running emulators)
- OpenAI Platform: https://platform.openai.com
- Apple Developer: https://developer.apple.com

---

**Need Help?**
- Check troubleshooting section above
- Review Firebase docs: https://firebase.google.com/docs
- Review SwiftUI tutorials: https://developer.apple.com/tutorials/swiftui

Good luck building MessageAI! 🚀

