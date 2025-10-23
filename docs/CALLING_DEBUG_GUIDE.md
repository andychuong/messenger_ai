# Calling Feature Debug Guide

## Issues Addressed

### 1. ✅ Accept Button Stuck Showing Spinner
**Problem:** When clicking Accept on an incoming call, the button shows a spinner indefinitely.

**Root Cause:** The `isAnswering` state variable was being used for TWO different purposes:
1. Controlling the ringing animation dots (toggling forever in `onAppear`)
2. Showing the progress spinner on the Accept button

This caused a conflict where the state was constantly toggling for the animation, preventing the button spinner from working correctly.

**Fix:** 
- Added separate `ringingAnimation` state for the animated dots
- Keep `isAnswering` exclusively for the Accept button spinner
- Updated `onAppear` to toggle `ringingAnimation` instead

**Files Changed:**
- `IncomingCallView.swift` - Added `@State private var ringingAnimation = false`

### 2. ✅ "Unknown" User Names
**Problem:** Both incoming and active call screens show "Unknown" instead of actual user names.

**Potential Causes:**
- User data not loading from Firestore
- Firestore decoder errors
- Wrong user IDs being used

**Fix:** Added comprehensive debug logging to identify the actual issue:
- Log when loading user data
- Log Firestore errors
- Log if document doesn't exist
- Log decoding errors
- Log successful loads

**Files Changed:**
- `IncomingCallView.swift` - Enhanced `loadCallerInfo()` with error logging
- `ActiveCallView.swift` - Enhanced `loadOtherUserInfo()` with error logging

### 3. ✅ Connection Stuck on "Connecting..."
**Problem:** WebRTC connection doesn't establish, stays in "Connecting..." state.

**Potential Causes:**
- SDP offer/answer not being exchanged properly
- ICE candidates not being processed
- Listener not catching updates
- Duplicate SDP answer processing

**Fix:** Added extensive logging throughout the call flow:
- Log each step of the WebRTC negotiation
- Track SDP offer creation
- Track SDP answer receipt
- Track ICE candidate exchange
- Prevent duplicate SDP answer processing

**Files Changed:**
- `CallService.swift` - Added logging to `startCall()` and `answerCall()`
- `SignalingService.swift` - Added logging to `listenForCallUpdates()`
- `CallViewModel.swift` - Added logging to `answerCall()`

## Debug Logging Added

### When Making a Call:
```
📞 Starting audio/video call from [callerId] to [recipientId]
🔧 Setting up WebRTC peer connection...
📝 Creating offer...
✅ Offer created, creating call in Firestore...
✅ Call created in Firestore with ID: [callId]
✅ Call started successfully
🎧 Setting up listener for call updates: [callId]
```

### When Receiving a Call:
```
📞 Loading caller info for: [callerId]
✅ Caller data loaded: [data]
✅ Caller decoded: [displayName]
```

### When Answering a Call:
```
📞 Answering call: [callId], type: audio/video
🔄 Calling CallService.answerCall...
📞 CallService.answerCall - ID: [callId], type: audio/video
🔧 Setting up peer connection (video: true/false)...
📝 Setting remote description (offer)...
✅ Remote description set, creating answer...
📤 Sending answer SDP to Firestore...
✅ Answer sent successfully, updating UI...
```

### When Receiving Answer (Caller Side):
```
📡 Call update received for [callId]
📥 Received SDP answer, length: [count]
✅ Remote description set successfully
```

### ICE Candidate Exchange:
```
📡 ICE candidate generated
🧊 Processing new ICE candidate
⏭️ Skipping duplicate ICE candidate
```

### Connection State:
```
📡 ICE connection state changed: connected/disconnected/failed
✅ WebRTC connected
⚠️ WebRTC disconnected
```

## How to Debug Calling Issues

### Step 1: Check Console Logs
Open Xcode console and filter for these emojis:
- 📞 - Call initiation/answer
- ✅ - Success messages
- ❌ - Error messages
- 📡 - WebRTC/Signaling events
- 🧊 - ICE candidates
- 📥 - SDP answer received
- 📤 - SDP answer sent

### Step 2: Identify Where It Fails

#### If "Unknown" Shows:
Look for logs like:
```
📞 Loading caller info for: [userId]
```

Then check if you see:
- ✅ Success: `✅ Caller data loaded` + `✅ Caller decoded: [name]`
- ❌ Error: `❌ Error loading caller info` or `❌ User document doesn't exist`
- ❌ Decode Error: `❌ Error decoding caller`

**Common causes:**
- User document doesn't exist in Firestore
- User model decoding issues (check User.swift matches Firestore schema)
- Network/permissions issues

#### If Connection Fails:
Follow the log sequence and find where it stops:

**Normal flow:**
1. `📞 Starting call...` ✅
2. `🔧 Setting up WebRTC...` ✅
3. `📝 Creating offer...` ✅
4. `✅ Offer created...` ✅
5. `✅ Call created in Firestore...` ✅
6. `🎧 Setting up listener...` ✅
7. (On answer) `📤 Sending answer SDP...` ✅
8. `📥 Received SDP answer...` ✅
9. `📡 ICE candidate generated` (multiple) ✅
10. `🧊 Processing new ICE candidate` (multiple) ✅
11. `📡 ICE connection state changed: connected` ✅
12. `✅ WebRTC connected` ✅

**If it stops at any step**, that's where the issue is.

### Step 3: Common Issues & Solutions

#### Issue: SDP Answer Never Received
**Symptom:** Caller sees `✅ Call started` but never sees `📥 Received SDP answer`

**Causes:**
- Recipient didn't actually answer (check recipient logs)
- Firestore listener not set up (check for `🎧 Setting up listener`)
- Firestore rules blocking the update
- Network issues

**Solution:**
- Check Firestore console to see if call document has `sdpAnswer` field
- Check Firestore rules allow reading/writing calls collection
- Verify both users have network connection

#### Issue: ICE Candidates Not Exchanging
**Symptom:** Connection stuck after `✅ Remote description set` but no `✅ WebRTC connected`

**Causes:**
- ICE candidates not being sent to Firestore
- ICE candidates not being retrieved from Firestore
- Firestore arrayUnion not working
- Network/firewall blocking ICE gathering

**Solution:**
- Check console for `🧊 Processing new ICE candidate` messages
- Verify you see `📡 ICE candidate generated` on both sides
- Check Firestore document has `iceCandidates` array with entries
- Test on different network (some corporate networks block WebRTC)

#### Issue: "Unknown" User Name
**Symptom:** Incoming call or active call shows "Unknown" instead of user name

**Causes:**
- User document doesn't exist in Firestore
- User ID mismatch
- Firestore decoder error
- Missing displayName field

**Solution:**
- Check logs for `❌ User document doesn't exist for ID: [id]`
- Verify user ID is correct in Firestore
- Check User model fields match Firestore document structure
- Verify displayName field exists in user document

#### Issue: Permission Denied for Video Calls
**Symptom:** Video call fails or audio-only works

**Causes:**
- Camera/microphone permissions not granted
- Simulator doesn't support camera

**Solution:**
- Check logs for `⚠️ Video call requires permissions, requesting...`
- Grant permissions when prompted
- Test on physical device (video doesn't work in simulator)

### Step 4: Firestore Rules Check

Ensure your Firestore rules allow call operations:

```javascript
match /calls/{callId} {
  allow read, write: if request.auth != null;
  allow create: if request.auth != null;
  allow update: if request.auth != null;
}
```

### Step 5: Network Requirements

WebRTC requires:
- ✅ STUN server access (stun.l.google.com:19302)
- ✅ UDP ports for media (not blocked by firewall)
- ✅ Internet connectivity on both devices
- ✅ Firestore real-time listeners working

## Testing Checklist

With the new logging, test the following and check console:

### Test 1: User Name Display
- [ ] Make a call
- [ ] Check caller screen shows correct recipient name
- [ ] Check recipient screen shows correct caller name
- [ ] Look for ✅ or ❌ in user loading logs

### Test 2: Call Connection
- [ ] Make an audio call
- [ ] Click Accept
- [ ] Wait for connection
- [ ] Look for complete log sequence from offer → answer → ICE → connected
- [ ] Verify you see `✅ WebRTC connected`

### Test 3: Button States
- [ ] Click Accept on incoming call
- [ ] Button should show spinner briefly
- [ ] Screen should transition to ActiveCallView
- [ ] Spinner should not stuck indefinitely

### Test 4: Video Call
- [ ] Make a video call (on physical device)
- [ ] Accept call
- [ ] Verify video tracks appear
- [ ] Check for video-specific logs

## Next Steps After Testing

Once you run the app and attempt a call:

1. **Copy all console logs** from the moment you initiate the call until it fails
2. **Look for the last ✅ message** - that's the last successful step
3. **Look for any ❌ message** - that's the error
4. **Share the logs** so we can pinpoint the exact failure point

The extensive logging will reveal exactly where the call flow is breaking down.


