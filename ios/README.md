# MessageAI iOS App

Swift/SwiftUI iOS application for MessageAI.

## Setup Instructions

### 1. Install Xcode

- Requires Xcode 15+
- macOS Sonoma or later

### 2. Create Xcode Project

Since Xcode projects cannot be created via command line tools easily, follow these steps:

1. Open Xcode
2. File → New → Project
3. Choose "iOS" → "App"
4. Fill in details:
   - **Product Name**: MessagingApp
   - **Team**: Your Apple Developer Team
   - **Organization Identifier**: com.yourname.messagingapp
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: SwiftData
5. Save to this `ios/` directory

### 3. Add Firebase SDK

1. In Xcode: File → Add Package Dependencies
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select version: 10.0.0 or later
4. Add packages:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage
   - FirebaseMessaging
   - FirebaseAnalytics (optional)

### 4. Configure Firebase

1. Download `GoogleService-Info.plist` from Firebase Console
2. Add to Xcode project (drag and drop into project navigator)
3. Ensure "Copy items if needed" is checked
4. Add to all targets

### 5. Add WebRTC (for calling)

Option 1 - Swift Package Manager:
```
https://github.com/webrtc-sdk/Specs
```

Option 2 - Manual installation (recommended for stability)

### 6. Configure Capabilities

In Xcode, select your target → Signing & Capabilities:

- [x] Push Notifications
- [x] Background Modes:
  - Audio, AirPlay, and Picture in Picture
  - Voice over IP
  - Background fetch
  - Remote notifications
- [x] Keychain Sharing
- [x] App Groups (for extensions)

### 7. Configure Info.plist

Add required privacy descriptions:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls and profile pictures.</string>

<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice calls and voice messages.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to send images in messages.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs permission to save images from messages.</string>

<key>NSContactsUsageDescription</key>
<string>This app needs contacts access to help you find friends.</string>
```

## Project Structure

Once you create the Xcode project, organize it like this:

```
MessagingApp/
├── App/
│   ├── MessagingAppApp.swift
│   └── AppDelegate.swift
├── Models/
│   ├── User.swift
│   ├── Message.swift
│   ├── Conversation.swift
│   └── ...
├── Views/
│   ├── Authentication/
│   ├── Conversations/
│   ├── Friends/
│   └── ...
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ChatViewModel.swift
│   └── ...
├── Services/
│   ├── AuthService.swift
│   ├── MessageService.swift
│   └── ...
├── Utilities/
│   └── Constants.swift
├── Resources/
│   ├── Assets.xcassets
│   └── GoogleService-Info.plist
└── Info.plist
```

## Build and Run

1. Select target device (simulator or physical iPhone)
2. Press Cmd+R or click Run button
3. App should launch

## Development

### Run Tests

```
Cmd+U
```

### Clean Build

```
Shift+Cmd+K
```

### Debug

- Set breakpoints by clicking line numbers
- Use `print()` for console logging
- View Debug console: View → Debug Area → Show Debug Area

## Troubleshooting

### Build Fails
- Clean build folder (Shift+Cmd+K)
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Restart Xcode

### Firebase Not Working
- Check `GoogleService-Info.plist` is added
- Verify bundle identifier matches Firebase project
- Check Firebase initialization in App file

### Signing Issues
- Select your development team in Signing & Capabilities
- Use automatic signing (recommended)
- Ensure bundle ID is unique

## Next Steps

1. Create the Xcode project following the instructions above
2. Set up project structure
3. Implement authentication (Phase 1)
4. Build messaging features (Phase 2-3)
5. Add AI features (Phase 4+)

See the main [APP_PLAN.md](../APP_PLAN.md) for detailed implementation steps.


