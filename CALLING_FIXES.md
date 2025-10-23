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

## Testing Checklist

- [ ] Incoming call shows on any tab (Conversations, Friends, AI, Profile)
- [ ] Audio calls connect successfully
- [ ] Video calls connect successfully
- [ ] ICE candidates are exchanged properly
- [ ] Video track appears on both sides for video calls
- [ ] Mute/unmute works
- [ ] Video toggle works
- [ ] Camera flip works
- [ ] Call can be declined
- [ ] Call can be ended
- [ ] No duplicate incoming call dialogs
- [ ] Call state persists across tab switches

## Known Limitations

1. **No call history** - Calls are not saved to a history log
2. **No missed call notifications** - Users don't see missed calls after declining or timeout
3. **No call reconnection** - If connection drops, call ends
4. **Simulator limitations** - Video won't work in simulator, only on physical devices

## Next Steps

Consider adding:
- Call history tracking
- Missed call badges
- Call reconnection logic
- Better error handling for network issues
- Call quality indicators
- Speaker/headphone toggling

