# Phase 5: Voice/Video Calling - Quick Start

## 🎯 What You Need to Know

**Phase 5 adds voice and video calling to your messaging app using WebRTC!**

### ⚠️ Critical: Physical Devices Required

**You CANNOT test calls in the iOS Simulator**
- Need 2 physical iPhones
- iOS 17.0+
- Camera and microphone access
- Good WiFi or cellular connection

---

## 🚀 Quick Setup (3 Steps)

### Step 1: Add WebRTC Framework

Open Xcode:
```
File → Add Package Dependencies...
```

Enter URL:
```
https://github.com/stasel/WebRTC.git
```

Version: `115.0.0`

Click "Add Package" → Select target `messagingapp` → Done

**More details:** See `PHASE5_WEBRTC_PACKAGE.md`

### Step 2: Deploy Cloud Functions

```bash
cd firebase/functions
npm install
npm run build
firebase deploy --only functions:sendCallNotification
```

### Step 3: Build on Two Devices

1. Connect iPhone A via USB
2. Build and run in Xcode (Cmd+R)
3. Sign in with User A
4. Repeat with iPhone B and User B

---

## 🧪 Quick Test

### Test Audio Call

**Device A:**
1. Open chat with User B
2. Tap phone icon (🔊) in top right
3. Wait...

**Device B:**
1. Incoming call notification appears
2. Tap "Accept" (green button)
3. You should hear User A!

**Both Devices:**
- Speak and listen to test audio
- Tap red button to end call

### Test Video Call

Same as audio, but:
- Tap video icon (📹) instead
- Both should see each other's video
- Local video appears in small corner
- Remote video fills the screen

---

## 📱 Features

### What Works

✅ **Audio Calls**
- Crystal clear voice
- Mute/unmute
- Speaker/earpiece toggle

✅ **Video Calls**
- See and hear each other
- Enable/disable video
- Switch front/rear camera
- Picture-in-picture local video

✅ **Call Controls**
- Mute microphone
- Toggle video
- Flip camera
- End call

✅ **Notifications**
- Push notifications for incoming calls
- Shows caller name and photo
- Accept/Decline buttons

✅ **Permissions**
- Asks for camera permission
- Asks for microphone permission
- Handles denied permissions gracefully

---

## 📁 What Was Added

### New Files (9)
1. `Call.swift` - Call data model
2. `WebRTCService.swift` - WebRTC peer connections
3. `SignalingService.swift` - Firestore signaling
4. `CallService.swift` - Main call coordinator
5. `CallViewModel.swift` - Call UI state
6. `IncomingCallView.swift` - Incoming call screen
7. `ActiveCallView.swift` - Active call screen
8. `RTCVideoView.swift` - Video rendering
9. `callNotifications.ts` - Cloud Function for notifications

### Modified Files (4)
1. `ChatView.swift` - Added call buttons
2. `messagingappApp.swift` - Initialize CallService
3. `Info.plist` - Added permissions
4. `index.ts` - Export call function

### Documentation (5)
1. `PHASE5_COMPLETE.md` - Full implementation details
2. `PHASE5_TESTING_GUIDE.md` - Testing procedures
3. `PHASE5_SETUP_INSTRUCTIONS.md` - Setup guide
4. `PHASE5_WEBRTC_PACKAGE.md` - WebRTC installation
5. `PHASE5_SUMMARY.md` - Overview

---

## 🐛 Troubleshooting

### "No such module 'WebRTC'"

Clean build:
```bash
# In Terminal
rm -rf ~/Library/Developer/Xcode/DerivedData
```

Then in Xcode: Shift+Cmd+K, then Cmd+B

### Call doesn't connect

1. Check both devices have internet
2. Verify Cloud Function deployed:
   ```bash
   firebase functions:log --limit 10
   ```
3. Check Firestore rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

### No incoming call notification

1. Check FCM tokens in Firebase Console → Firestore → users
2. Grant notification permissions in Settings
3. Verify `CallService.startListening()` is called (it's in messagingappApp.swift)

### Permission denied

1. Check Info.plist has usage descriptions
2. Uninstall and reinstall app
3. Grant permissions in Settings → [Your App]

---

## 📖 Full Documentation

For comprehensive information:

- **Implementation Details:** `PHASE5_COMPLETE.md`
- **Testing Guide:** `PHASE5_TESTING_GUIDE.md`
- **Setup Instructions:** `PHASE5_SETUP_INSTRUCTIONS.md`
- **WebRTC Setup:** `PHASE5_WEBRTC_PACKAGE.md`
- **Summary:** `PHASE5_SUMMARY.md`

---

## ✅ Quick Checklist

Before testing:
- [ ] WebRTC framework added in Xcode
- [ ] Cloud Functions deployed
- [ ] App built on Device A
- [ ] App built on Device B
- [ ] Both users signed in
- [ ] Both users are friends
- [ ] Permissions granted on both devices

Testing:
- [ ] Audio call connects
- [ ] Video call connects
- [ ] Can mute/unmute
- [ ] Can toggle video
- [ ] Can switch camera
- [ ] End call works
- [ ] Incoming notification appears
- [ ] Accept/decline work

---

## 🎉 Success!

If calls connect and you can hear/see each other, **Phase 5 is working!**

---

## 🚀 What's Next?

After Phase 5:

**Option 1: Continue with planned phases**
- Phase 6: Security & Encryption
- Phase 7: AI Translation
- Phase 8: RAG & Conversation Intelligence
- Phase 9: AI Chat Assistant

**Option 2: Enhance calling**
- Add TURN servers for better connectivity
- Implement call history view
- Add CallKit for native iOS experience
- Support group calls (3+ people)

**Option 3: Polish & deploy**
- Test with real users
- Fix any bugs
- Optimize performance
- Prepare for App Store

---

## 📞 Need Help?

Check the comprehensive documentation:
- `PHASE5_COMPLETE.md` for implementation details
- `PHASE5_TESTING_GUIDE.md` for testing procedures
- `PHASE5_SETUP_INSTRUCTIONS.md` for troubleshooting

---

**Quick Start Version:** 1.0  
**Last Updated:** October 21, 2025  
**Phase 5 Status:** ✅ COMPLETE

