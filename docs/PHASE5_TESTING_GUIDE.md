# Phase 5: Voice/Video Calling - Testing Guide

**Phase:** 5 - Voice/Video Calling  
**Date Created:** October 21, 2025  
**Status:** Implementation Complete - Ready for Testing

---

## 📋 Overview

This guide provides comprehensive testing procedures for Phase 5 features including audio calls, video calls, WebRTC connectivity, call signaling, and call notifications.

---

## ⚠️ Prerequisites

### Before Testing
- [ ] Two physical iOS devices (calls cannot be tested properly in simulator)
- [ ] Both devices signed into different accounts
- [ ] Both users added as friends
- [ ] Microphone and camera permissions granted on both devices
- [ ] Good network connectivity (WiFi or strong cellular)
- [ ] Firebase Cloud Functions deployed with call notifications

### Setup Steps
1. Build and install app on Device A
2. Build and install app on Device B  
3. Sign in with User A on Device A
4. Sign in with User B on Device B
5. Add each other as friends
6. Navigate to a conversation between the two users

---

## 🧪 Test Scenarios

### 1. Audio Call Tests

#### 1.1 Basic Audio Call
**Steps:**
1. User A opens chat with User B
2. User A taps the phone icon (🔊) in top right
3. Verify: Call screen appears with "Connecting..." status
4. Verify: User B receives incoming call notification
5. User B sees incoming call screen with User A's name/photo
6. User B taps "Accept" (green button)
7. Verify: Both users connect to active call screen
8. Verify: Call duration timer starts
9. Verify: Both users can hear each other clearly
10. Either user taps red "End Call" button
11. Verify: Call ends for both users
12. Verify: Both return to chat view

**Expected Results:**
- ✅ Call connects within 3-5 seconds
- ✅ Audio is clear with minimal latency
- ✅ Call duration displays correctly
- ✅ Call ends cleanly for both parties

#### 1.2 Audio Call - Mute Functionality
**Steps:**
1. Start audio call between User A and B (follow 1.1)
2. User A taps mute button (🎤)
3. Verify: Microphone icon shows slash (🎤/)
4. User A speaks - User B should NOT hear
5. User A taps mute button again to unmute
6. Verify: Microphone icon returns to normal
7. User A speaks - User B should hear again
8. Repeat test with User B muting

**Expected Results:**
- ✅ Mute immediately stops audio transmission
- ✅ Unmute resumes audio transmission
- ✅ Mute icon updates correctly
- ✅ Both users can independently mute

#### 1.3 Audio Call - Speaker Toggle
**Steps:**
1. Start audio call
2. User A taps speaker button (🔊)
3. Verify: Audio plays through speaker (louder)
4. User A taps speaker button again
5. Verify: Audio returns to earpiece

**Expected Results:**
- ✅ Speaker toggle works smoothly
- ✅ No audio disruption during toggle
- ✅ Icon updates accordingly

#### 1.4 Audio Call - Decline
**Steps:**
1. User A initiates audio call
2. User B receives incoming call screen
3. User B taps "Decline" (red button)
4. Verify: User B returns to previous screen
5. Verify: User A sees "Call ended" or returns to chat
6. Verify: No call record marked as "answered"

**Expected Results:**
- ✅ Declined call ends immediately
- ✅ No connection established
- ✅ Both users can continue chatting

#### 1.5 Audio Call - Missed Call
**Steps:**
1. User A initiates audio call
2. User B does NOT answer (wait 30 seconds)
3. Verify: Call times out
4. Verify: Call marked as "missed" for User B
5. Optional: Check if notification badge appears

**Expected Results:**
- ✅ Call times out after reasonable period
- ✅ Caller can retry
- ✅ Missed call logged (if call history implemented)

---

### 2. Video Call Tests

#### 2.1 Basic Video Call
**Steps:**
1. User A opens chat with User B
2. User A taps the video icon (📹) in top right
3. Verify: Call screen appears showing local video preview
4. Verify: User B receives incoming video call notification
5. User B sees incoming call screen with "Video Call" text
6. User B taps "Accept"
7. Verify: Both users see each other's video
8. Verify: Local video appears in small PIP window
9. Verify: Remote video fills the screen
10. Verify: Call duration timer starts
11. Either user ends call
12. Verify: Camera stops, call ends cleanly

**Expected Results:**
- ✅ Video connects within 3-5 seconds
- ✅ Video quality is good (resolution, frame rate)
- ✅ Audio and video are synchronized
- ✅ PIP video displays correctly
- ✅ Call ends cleanly

#### 2.2 Video Call - Disable Video
**Steps:**
1. Start video call (follow 2.1)
2. User A taps video button (📹) to disable camera
3. Verify: User A's video feed stops on User B's screen
4. Verify: User B sees placeholder or avatar
5. User A taps video button again to enable
6. Verify: Video resumes on both sides

**Expected Results:**
- ✅ Video toggles smoothly
- ✅ Audio continues during video toggle
- ✅ Icon updates correctly
- ✅ Placeholder shown when video disabled

#### 2.3 Video Call - Flip Camera
**Steps:**
1. Start video call
2. User A taps "Flip Camera" button (🔄)
3. Verify: Camera switches to rear camera
4. User B sees User A's rear camera view
5. User A taps "Flip Camera" again
6. Verify: Returns to front camera

**Expected Results:**
- ✅ Camera switch happens smoothly
- ✅ No video interruption during flip
- ✅ Both front and rear cameras work

#### 2.4 Video Call - Mute During Video
**Steps:**
1. Start video call
2. User A taps mute button
3. Verify: Video continues, audio stops
4. User B can see User A but not hear
5. User A unmutes
6. Verify: Audio resumes, video uninterrupted

**Expected Results:**
- ✅ Audio and video independent
- ✅ Mute works same as audio call
- ✅ Video quality unchanged during mute

#### 2.5 Video Call - Control Auto-Hide
**Steps:**
1. Start video call
2. Verify: Controls visible initially
3. Wait 3 seconds without interaction
4. Verify: Controls fade out
5. Tap anywhere on screen
6. Verify: Controls reappear
7. Wait 3 seconds again
8. Verify: Controls fade out again

**Expected Results:**
- ✅ Controls auto-hide after 3 seconds
- ✅ Tap reveals controls
- ✅ Controls stay visible during interaction
- ✅ Smooth fade animation

---

### 3. Call Signaling & Connectivity Tests

#### 3.1 Network Quality Test
**Steps:**
1. Start call on strong WiFi
2. During call, switch to cellular data
3. Verify: Call continues without dropping
4. Monitor audio/video quality
5. Switch back to WiFi
6. Verify: Quality improves if applicable

**Expected Results:**
- ✅ Call survives network switches
- ✅ Reconnection is automatic
- ✅ Quality adjusts to network

#### 3.2 Poor Network Conditions
**Steps:**
1. Enable "Network Link Conditioner" (if available)
2. Set to "Very Bad Network" or similar
3. Attempt to start call
4. Observe connection time and quality
5. Disable network conditioner
6. Verify: Quality improves

**Expected Results:**
- ✅ Call attempts to connect even on poor network
- ✅ Quality degrades gracefully
- ✅ No crashes or freezes
- ✅ Recovery when network improves

#### 3.3 Call Interruption - Phone Call
**Steps:**
1. Start audio/video call
2. Receive incoming cellular call on User A's device
3. Verify: App call handles interruption gracefully
4. Accept or reject cellular call
5. Return to app
6. Verify: Can resume or restart call

**Expected Results:**
- ✅ No crash during interruption
- ✅ User informed of interruption
- ✅ Can restart call after

#### 3.4 Call Interruption - App Background
**Steps:**
1. Start call between User A and B
2. User A presses home button (background app)
3. Verify: Call continues in background
4. User A returns to app
5. Verify: Call still active, controls responsive

**Expected Results:**
- ✅ Background mode enabled (audio continues)
- ✅ Call doesn't drop when backgrounded
- ✅ Smooth return to foreground

---

### 4. Permission Tests

#### 4.1 First-Time Microphone Permission
**Steps:**
1. Fresh install or reset permissions
2. User A taps audio call button
3. Verify: System permission dialog appears
4. User A denies permission
5. Verify: Error message shown
6. User A opens Settings → App → Allow microphone
7. Return to app and try call again
8. Verify: Call works now

**Expected Results:**
- ✅ Permission requested correctly
- ✅ Denied permission handled gracefully
- ✅ Clear error message shown
- ✅ Works after granting permission

#### 4.2 First-Time Camera Permission
**Steps:**
1. Fresh install or reset permissions
2. User A taps video call button
3. Verify: System permission dialog appears (microphone + camera)
4. User A denies camera permission
5. Verify: Error message shown
6. User A grants permission through Settings
7. Try video call again
8. Verify: Video call works

**Expected Results:**
- ✅ Both microphone and camera requested
- ✅ Denied camera handled gracefully
- ✅ Audio-only fallback option shown (optional)
- ✅ Works after granting permission

---

### 5. Notification Tests

#### 5.1 Foreground Call Notification
**Steps:**
1. User B has app open (foreground)
2. User A initiates call
3. Verify: Incoming call screen appears immediately
4. No push notification banner

**Expected Results:**
- ✅ Full-screen incoming call view
- ✅ Accept/Decline buttons functional
- ✅ Caller info displays correctly

#### 5.2 Background Call Notification
**Steps:**
1. User B backgrounds the app or locks device
2. User A initiates call
3. Verify: Push notification appears
4. Verify: Notification shows caller name and "Incoming Call"
5. User B taps notification
6. Verify: App opens to incoming call screen

**Expected Results:**
- ✅ Notification arrives within 1-2 seconds
- ✅ Notification content correct
- ✅ Tapping notification opens call screen
- ✅ Can accept or decline from notification (if actions implemented)

#### 5.3 Notification Sound & Vibration
**Steps:**
1. User B device on silent mode
2. User A calls User B
3. Verify: Device vibrates
4. User B device with sound on
5. User A calls again
6. Verify: Ringtone plays

**Expected Results:**
- ✅ Vibration works on silent
- ✅ Ringtone plays when sound enabled
- ✅ Notification respects device settings

---

### 6. Edge Cases & Error Handling

#### 6.1 Simultaneous Calls
**Steps:**
1. User A calls User B
2. While ringing, User B calls User A
3. Observe behavior

**Expected Results:**
- ✅ One call takes precedence (first initiated)
- ✅ Second call fails gracefully
- ✅ No crash or deadlock

#### 6.2 Call While Already in Call
**Steps:**
1. User A and User B in active call
2. User C calls User A
3. Verify: User A either doesn't receive or call waiting shown

**Expected Results:**
- ✅ Active call not interrupted
- ✅ Incoming call handled gracefully
- ✅ Option to end current and answer new (optional)

#### 6.3 Rapid Call Actions
**Steps:**
1. User A starts call
2. Immediately end call before connection
3. Verify: Call ends cleanly
4. Start another call immediately
5. Verify: Second call works

**Expected Results:**
- ✅ No lingering call state
- ✅ Immediate retry works
- ✅ No "already in call" errors

#### 6.4 Network Loss During Call
**Steps:**
1. Start call with good connection
2. Turn off WiFi and cellular data mid-call
3. Verify: Call disconnects
4. Verify: User notified of disconnection
5. Re-enable network
6. Verify: Can start new call

**Expected Results:**
- ✅ Graceful disconnection on network loss
- ✅ Clear error message
- ✅ Clean state after reconnection

#### 6.5 App Termination During Call
**Steps:**
1. Start active call
2. Force quit the app on one device
3. Verify: Other user sees call ended
4. Reopen app
5. Verify: App in clean state, can start new call

**Expected Results:**
- ✅ Other party notified of disconnect
- ✅ No zombie call state
- ✅ App recovers correctly

---

### 7. UI/UX Tests

#### 7.1 Call Screen Layout
**Steps:**
1. Start audio call
2. Verify all elements visible:
   - Call duration timer
   - Caller/recipient name
   - Mute button
   - Speaker button  
   - End call button
   - Connection status indicator
3. Start video call
4. Verify additional elements:
   - Remote video (full screen)
   - Local video (PIP)
   - Video toggle button
   - Flip camera button

**Expected Results:**
- ✅ All controls visible and accessible
- ✅ Icons clear and intuitive
- ✅ Layout adapts to screen size
- ✅ No overlapping elements

#### 7.2 Call Screen Rotation (if supported)
**Steps:**
1. Start video call in portrait
2. Rotate device to landscape
3. Verify: UI adapts correctly
4. Rotate back to portrait
5. Verify: Returns to portrait layout

**Expected Results:**
- ✅ Smooth rotation animation
- ✅ Video fills screen appropriately
- ✅ Controls remain accessible
- ✅ No visual glitches

#### 7.3 Incoming Call Appearance
**Steps:**
1. Receive incoming call
2. Verify:
   - Full-screen modal
   - Caller name clearly visible
   - Caller photo shown (if available)
   - "Incoming Call" or "Incoming Video Call" text
   - Large Accept button (green)
   - Large Decline button (red)
   - Call type icon (audio/video)

**Expected Results:**
- ✅ Attractive, clear UI
- ✅ Easy to read caller info
- ✅ Buttons large and accessible
- ✅ Colors match conventions (green=accept, red=decline)

---

### 8. Performance Tests

#### 8.1 Call Initiation Speed
**Steps:**
1. Tap call button
2. Measure time until ringing starts
3. Repeat 5 times
4. Calculate average

**Target:** < 2 seconds average

#### 8.2 Call Connection Speed
**Steps:**
1. Initiate call
2. Accept on other device
3. Measure time until audio/video starts
4. Repeat 5 times
5. Calculate average

**Target:** < 5 seconds average

#### 8.3 Battery Consumption
**Steps:**
1. Note battery level at start
2. Conduct 10-minute call
3. Note battery level at end
4. Calculate consumption rate

**Target:** < 10% battery per 10 minutes

#### 8.4 Memory Usage
**Steps:**
1. Open Xcode Instruments
2. Monitor memory during call
3. Check for memory leaks
4. End call
5. Verify memory released

**Expected Results:**
- ✅ No memory leaks
- ✅ Reasonable memory usage (< 200 MB)
- ✅ Memory released after call

---

### 9. Accessibility Tests

#### 9.1 VoiceOver Support
**Steps:**
1. Enable VoiceOver
2. Navigate to chat
3. Find call buttons with VoiceOver
4. Verify: Buttons labeled correctly ("Audio call", "Video call")
5. Receive incoming call
6. Verify: Accept/Decline buttons accessible

**Expected Results:**
- ✅ All buttons have accessibility labels
- ✅ VoiceOver announces actions
- ✅ Can navigate and activate with VoiceOver

#### 9.2 Dynamic Type Support
**Steps:**
1. Settings → Accessibility → Larger Text
2. Set to largest size
3. Open app and view call screens
4. Verify: Text scales appropriately

**Expected Results:**
- ✅ Text readable at all sizes
- ✅ Layout doesn't break
- ✅ Buttons remain tappable

---

## 🐛 Common Issues & Troubleshooting

### Issue: Call Doesn't Connect
**Symptoms:** Ringing indefinitely, no audio/video
**Possible Causes:**
- Network connectivity problems
- Firestore rules blocking call document
- ICE candidate exchange failing
- WebRTC configuration incorrect

**Debug Steps:**
1. Check console logs for WebRTC errors
2. Verify Firestore call document created
3. Check network connectivity on both devices
4. Verify ICE servers accessible

### Issue: No Incoming Call Notification
**Symptoms:** Caller sees ringing, recipient doesn't get notified
**Possible Causes:**
- FCM token not registered
- Cloud Function not deployed
- Notification permissions denied
- App not listening for calls

**Debug Steps:**
1. Check FCM token in user document
2. Verify Cloud Function deployed: `firebase deploy --only functions:sendCallNotification`
3. Check notification permissions
4. Verify CallService.startListening() called

### Issue: Audio/Video Quality Poor
**Symptoms:** Choppy audio, low-res video, lag
**Possible Causes:**
- Poor network connection
- Bandwidth limitations
- Device performance issues
- WebRTC codec issues

**Debug Steps:**
1. Test on strong WiFi
2. Check device specs
3. Monitor network stats in WebRTC
4. Try on different devices

### Issue: Call Drops Frequently
**Symptoms:** Call disconnects after 10-30 seconds
**Possible Causes:**
- ICE connection failing
- Network instability  
- Background mode not working
- Memory issues

**Debug Steps:**
1. Check ICE connection state in logs
2. Monitor network during call
3. Verify background modes enabled in Info.plist
4. Check for memory leaks

---

## ✅ Test Completion Checklist

### Core Functionality
- [ ] Audio calls connect successfully
- [ ] Video calls connect successfully
- [ ] Mute/unmute works
- [ ] Video enable/disable works
- [ ] Flip camera works
- [ ] End call works from both sides
- [ ] Accept call works
- [ ] Decline call works

### Notifications
- [ ] Foreground call screen appears
- [ ] Background call notification arrives
- [ ] Notification sound/vibration works
- [ ] Tapping notification opens call

### Permissions
- [ ] Microphone permission requested
- [ ] Camera permission requested
- [ ] Denied permissions handled gracefully
- [ ] Works after granting permissions

### Edge Cases
- [ ] Network switch during call handled
- [ ] Poor network conditions handled
- [ ] App backgrounding handled
- [ ] App termination handled
- [ ] Simultaneous calls handled

### Performance
- [ ] Call initiation < 2 seconds
- [ ] Call connection < 5 seconds
- [ ] No memory leaks
- [ ] Battery usage reasonable

### UI/UX
- [ ] All UI elements visible
- [ ] Controls intuitive
- [ ] Incoming call screen clear
- [ ] Active call screen functional
- [ ] Accessibility supported

---

## 📝 Bug Report Template

If you find issues during testing, please document them:

```
**Bug Title:** [Brief description]

**Severity:** Critical / High / Medium / Low

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Behavior:**


**Actual Behavior:**


**Device Info:**
- Device Model: 
- iOS Version: 
- App Version: 

**Screenshots/Logs:**
[Attach if available]

**Additional Notes:**

```

---

## 🚀 Next Steps After Testing

1. **Fix Critical Bugs:** Any crashes or call failures
2. **Optimize Performance:** If metrics don't meet targets
3. **Improve UX:** Based on user feedback
4. **Optional Enhancements:**
   - Call history view
   - Group calls (3+ participants)
   - Screen sharing
   - Call recording (with consent)
   - Noise cancellation
   - Virtual backgrounds

---

**Document Version:** 1.0  
**Last Updated:** October 21, 2025  
**Prepared By:** AI Assistant  
**For:** MessageAI Phase 5 Implementation

