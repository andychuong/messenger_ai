# Phase 5: Voice/Video Calling - Setup Instructions

## 🚀 Quick Start Guide

### 1. Add WebRTC Framework

Phase 5 requires the WebRTC framework for peer-to-peer audio/video connections.

**Option A: Using Swift Package Manager (Recommended)**

1. Open the Xcode project:
   ```
   open ios/messagingapp/messagingapp.xcodeproj
   ```

2. In Xcode:
   - File → Add Package Dependencies...
   - Enter package URL: `https://github.com/stasel/WebRTC.git`
   - Version: Latest (or `115.0.0` for stability)
   - Click "Add Package"
   - Select target: `messagingapp`
   - Click "Add Package"

**Option B: Using CocoaPods**

If you prefer CocoaPods, add to your `Podfile`:
```ruby
pod 'GoogleWebRTC'
```

Then run:
```bash
pod install
```

### 2. Verify Project Configuration

**Check Info.plist includes permissions:**
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs access to your camera for video calls.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to your microphone for voice and video calls.</string>
```

**Check Background Modes are enabled:**
- Open project settings
- Select target → Signing & Capabilities
- Click "+ Capability" → Background Modes
- Enable:
  - ✅ Audio, AirPlay, and Picture in Picture
  - ✅ Voice over IP
  - ✅ Remote notifications

### 3. Deploy Cloud Functions

Deploy the call notification function:

```bash
cd firebase/functions
npm install  # If dependencies not already installed
npm run build
firebase deploy --only functions:sendCallNotification
```

Verify deployment:
```bash
firebase functions:log
```

### 4. Update Firestore Rules (Already Done)

The Firestore rules for calls are already in `firebase/firestore.rules`. Deploy them:

```bash
firebase deploy --only firestore:rules
```

### 5. Build and Test

**Important: Testing requires TWO physical devices**

1. **Build on Device A:**
   - Connect iPhone A via USB
   - Select device in Xcode
   - Build and Run (Cmd+R)
   - Sign in with User A account

2. **Build on Device B:**
   - Connect iPhone B via USB
   - Select device in Xcode
   - Build and Run (Cmd+R)
   - Sign in with User B account

3. **Test Basic Call:**
   - On Device A: Open chat with User B
   - Tap phone icon (🔊)
   - On Device B: Incoming call notification should appear
   - Tap "Accept"
   - Both should connect and hear each other
   - Tap red button to end call

### 6. Troubleshooting

**Build Errors:**

If you see "WebRTC module not found":
- Clean build folder: Shift+Cmd+K
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Rebuild project

**Call Not Connecting:**

1. Check both devices have internet
2. Verify Firestore rules: `firebase deploy --only firestore:rules`
3. Check Cloud Function logs: `firebase functions:log --limit 50`
4. Enable verbose logging in WebRTCService (add print statements)

**No Incoming Call Notification:**

1. Verify FCM tokens in Firestore:
   - Open Firebase Console → Firestore
   - Check `users` collection
   - Verify `fcmToken` field exists for both users

2. Check Cloud Function deployed:
   - Firebase Console → Functions
   - Look for `sendCallNotification`

3. Check notification permissions:
   - Settings → [Your App] → Notifications → Allow

**Permission Issues:**

If camera/microphone permissions not requested:
- Uninstall and reinstall app
- Check Info.plist has usage descriptions
- Grant permissions in Settings → [Your App]

### 7. Optional Enhancements

**Add TURN Servers (Better Connectivity):**

Edit `WebRTCService.swift`, update `iceServers`:

```swift
private let iceServers = [
    RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
    // Add TURN server for better connectivity
    RTCIceServer(
        urlStrings: ["turn:your-turn-server.com:3478"],
        username: "your-username",
        credential: "your-password"
    )
]
```

**Popular TURN Server Providers:**
- [Twilio STUN/TURN](https://www.twilio.com/stun-turn) - Free tier available
- [Xirsys](https://xirsys.com/) - Free tier available
- [Metered.ca](https://www.metered.ca/stun-turn) - Free tier available

**Enable Call History (Optional):**

Store completed calls and show in UI:
1. Create `CallHistoryView.swift`
2. List calls from Firestore where user is participant
3. Show duration, timestamp, call type
4. Tap to call back

### 8. Testing Checklist

Before considering Phase 5 complete:

- [ ] Audio call connects successfully
- [ ] Video call connects successfully
- [ ] Can mute/unmute during call
- [ ] Can toggle video during video call
- [ ] Can switch camera (front/rear)
- [ ] End call works from both sides
- [ ] Incoming call notification appears
- [ ] Accept/Decline buttons work
- [ ] Permissions requested correctly
- [ ] Works on both WiFi and cellular

See **PHASE5_TESTING_GUIDE.md** for comprehensive testing procedures.

---

## 📚 Next Steps

After Phase 5 testing is complete:

1. **Fix any bugs** found during testing
2. **Optional:** Add TURN servers for better connectivity
3. **Optional:** Implement call history view
4. **Proceed to Phase 6:** Security & Encryption
5. **Or Phase 7+:** AI Features (Translation, Assistant, RAG)

---

## 🆘 Need Help?

**Common Issues:**

- WebRTC not found → Re-add package in Xcode
- Call not connecting → Check Firestore rules and network
- No notification → Check FCM token and Cloud Function
- Permission errors → Check Info.plist descriptions

**Resources:**

- [WebRTC iOS Documentation](https://webrtc.github.io/webrtc-org/native-code/ios/)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [APNs Configuration](https://developer.apple.com/documentation/usernotifications)

---

**Setup Guide Version:** 1.0  
**Last Updated:** October 21, 2025  
**For:** MessageAI Phase 5 Implementation

