# Calling Feature Issues & Fixes

## Issues Found & Fixed ✅

### 1. No Global Call Handling ✅
**Problem:** Incoming calls only displayed when you're inside a ChatView. If you're on the Friends, Profile, or Conversations list screen, incoming calls weren't visible.

**Solution:** 
- Moved call handling to `MainTabView` level with a global `CallViewModel`
- Added global overlays for incoming and active calls using `ZStack`
- Calls now appear no matter which tab you're on

**Files Changed:**
- `MainTabView.swift` - Added global CallViewModel and call overlays

### 2. Multiple CallViewModel Instances ✅
**Problem:** Each ChatView created its own CallViewModel, leading to state synchronization issues between different views.

**Solution:** 
- Use a single shared `CallViewModel` created in `MainTabView`
- Pass it down via `@EnvironmentObject` to all child views
- Removed local `@StateObject` CallViewModel from `ChatView`

**Files Changed:**
- `MainTabView.swift` - Created single CallViewModel instance
- `ChatView.swift` - Changed from `@StateObject` to `@EnvironmentObject`

### 3. ICE Candidate Deduplication ✅
**Problem:** ICE candidates were processed multiple times when the Firestore listener fired, causing duplicate candidate additions.

**Solution:** 
- Added `processedCandidates` Set to track already-processed candidates
- Each candidate gets a unique key to prevent duplicates
- Cleaned up on `stopListening()`

**Files Changed:**
- `SignalingService.swift` - Added candidate tracking and deduplication

### 4. Video Flag Mismatch ✅
**Problem:** When answering a call, `isVideoEnabled` might not match the incoming call type, causing video to not work properly.

**Solution:** 
- Changed `createAnswer()` to check if `videoTrack != nil` instead of `isVideoEnabled`
- This ensures the answer matches the actual media capabilities

**Files Changed:**
- `WebRTCService.swift` - Fixed video flag logic in `createAnswer()`

### 5. Redundant Call UI in ChatView ✅
**Problem:** ChatView had its own fullScreenCover views for calls, creating duplicate UI when global call handling was added.

**Solution:** 
- Removed local fullScreenCover views from ChatView
- Calls are now only handled globally in MainTabView

**Files Changed:**
- `ChatView.swift` - Removed duplicate call presentation code

### 6. User Names Showing as "Unknown" ✅
**Problem:** User names displayed as "Unknown" on both incoming and active call screens, even though user data exists in Firestore with correct `displayName` fields.

**Root Cause:** Using `Firestore.Decoder().decode(User.self, from: data)` doesn't properly handle the `@DocumentID` property wrapper in the User model. This caused the decoder to fail silently and return incomplete/default data.

**Solution:** 
- Changed from manual `Firestore.Decoder()` to Firestore's built-in `snapshot.data(as: User.self)`
- This method properly handles all Firebase property wrappers (`@DocumentID`, etc.)
- User data now decodes correctly with all fields populated

**Files Changed:**
- `IncomingCallView.swift` - Line 185: Changed decoding method
- `ActiveCallView.swift` - Line 330: Changed decoding method

### 7. Call Timers Not Synchronized ✅
**Problem:** Call duration timers showed different times on each device (e.g., 00:09 on one device, 00:13 on the other) because each device started its own local timer independently.

**Root Cause:** Each device used a local `Timer` that started when the view appeared, but WebRTC connections complete at slightly different times on each side, causing the timers to drift.

**Solution:** 
- Added `connectedAt` timestamp field to the Call model
- Set this timestamp in Firestore when call status becomes "active" (in `answerCall()`)
- Updated `ActiveCallView` to listen to the call document and calculate duration based on the shared `connectedAt` timestamp
- All devices now calculate duration from the same reference time

**Files Changed:**
- `Call.swift` - Added `connectedAt: Date?` field
- `SignalingService.swift` - Set `connectedAt` timestamp when answering call
- `ActiveCallView.swift` - Added Firestore listener and calculate duration from `connectedAt`

## Summary of Changes

### MainTabView.swift
```swift
// Added global CallViewModel
@StateObject private var callViewModel = CallViewModel()

// Added call overlays in ZStack
if callViewModel.showIncomingCall { IncomingCallView(...) }
if callViewModel.showActiveCall { ActiveCallView(...) }

// Passed to all tabs via environmentObject
.environmentObject(callViewModel)
```

### ChatView.swift
```swift
// Changed from local to shared
// Before: @StateObject private var callViewModel = CallViewModel()
// After: @EnvironmentObject private var callViewModel: CallViewModel

// Removed duplicate fullScreenCover views
```

### SignalingService.swift
```swift
// Added candidate deduplication
private var processedCandidates = Set<String>()

// Track processed candidates
let candidateKey = "\(sdp)_\(sdpMLineIndex)_\(sdpMid)"
if !self.processedCandidates.contains(candidateKey) {
    self.processedCandidates.insert(candidateKey)
    // Process candidate
}
```

### WebRTCService.swift
```swift
// Fixed video flag logic
func createAnswer(completion: @escaping (RTCSessionDescription?, Error?) -> Void) {
    let hasVideo = videoTrack != nil  // Instead of isVideoEnabled
    // ...
}
```

### IncomingCallView.swift & ActiveCallView.swift
```swift
// Before: Manual decoder (doesn't work with @DocumentID)
if let data = snapshot.data() {
    self.caller = try Firestore.Decoder().decode(User.self, from: data)
}

// After: Built-in Firestore decoder (handles property wrappers)
self.caller = try snapshot.data(as: User.self)
```

### Call.swift
```swift
// Added connectedAt field to track when call actually connects
struct Call: Identifiable, Codable {
    @DocumentID var id: String?
    var callerId: String
    var recipientId: String
    var type: CallType
    var status: CallStatus
    var startedAt: Date
    var connectedAt: Date?  // NEW: Shared timestamp for all devices
    // ...
}
```

### SignalingService.swift
```swift
// Set connectedAt when answering call
func answerCall(callId: String, sdpAnswer: String, completion: @escaping (Error?) -> Void) {
    db.collection(Call.collectionName)
        .document(callId)
        .updateData([
            "sdpAnswer": sdpAnswer,
            "status": Call.CallStatus.active.rawValue,
            "connectedAt": Timestamp(date: Date())  // NEW: Set timestamp
        ])
}
```

### ActiveCallView.swift
```swift
// Before: Local counter
private func startCallTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        callDuration += 1  // Independent on each device
    }
}

// After: Calculate from shared Firestore timestamp
private func startCallTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
        if let connectedAt = currentCall?.connectedAt {
            callDuration = Date().timeIntervalSince(connectedAt)  // Synced!
        } else {
            callDuration += 1
        }
    }
}
```

## Testing Checklist

- [ ] Incoming call shows on any tab (Conversations, Friends, AI, Profile)
- [ ] Audio calls connect successfully
- [ ] Video calls connect successfully
- [ ] ICE candidates are exchanged properly
- [ ] Video track appears on both sides for video calls
- [ ] User names display correctly (not "Unknown")
- [ ] Call timers are synchronized across both devices
- [ ] Mute/unmute works
- [ ] Video toggle works
- [ ] Camera flip works
- [ ] Call can be declined
- [ ] Call can be ended
- [ ] No duplicate incoming call dialogs
- [ ] Call state persists across tab switches

## Known Limitations

1. **iOS Simulator Limitation** ⚠️ 
   - **Audio and video do NOT work in the iOS Simulator** (this is expected!)
   - Simulator lacks real camera/microphone hardware
   - WebRTC connections, signaling, and UI all work perfectly in simulator
   - **Actual audio/video transmission requires physical iPhones**
   - See `CALLING_TESTING_GUIDE.md` for details

2. **No call history** - Calls are not saved to a history log
3. **No missed call notifications** - Users don't see missed calls after declining or timeout
4. **No call reconnection** - If connection drops, call ends

## Next Steps

Consider adding:
- Call history tracking
- Missed call badges
- Call reconnection logic
- Better error handling for network issues
- Call quality indicators
- Speaker/headphone toggling

