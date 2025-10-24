# Phase 11: Offline Support & Sync - Testing Guide

**Date:** October 24, 2025  
**Purpose:** Comprehensive testing guide for offline functionality and data synchronization

---

## Prerequisites

- iOS device or simulator running iOS 17.0+
- MessageAI app installed and logged in
- Two test accounts for sending/receiving messages
- Ability to toggle airplane mode or disable network

---

## Test Scenarios

### 1. Network Monitor Testing

#### Test 1.1: Connection Status Display
**Steps:**
1. Launch app while online
2. Verify no offline banner appears
3. Enable airplane mode
4. Verify orange "No Internet Connection" banner appears
5. Disable airplane mode
6. Verify banner disappears

**Expected Result:** ✅ Banner appears/disappears instantly when connection changes

#### Test 1.2: Connection Type Detection
**Steps:**
1. Connect to WiFi
2. Check console logs for "WiFi" connection type
3. Disable WiFi, enable cellular
4. Check console logs for "Cellular" connection type

**Expected Result:** ✅ Correct connection type detected and logged

---

### 2. Message Queue Testing

#### Test 2.1: Queue Messages While Offline
**Steps:**
1. Open a conversation
2. Enable airplane mode
3. Type and send 3 messages
4. Observe offline banner shows "3 messages queued"
5. Navigate away and return
6. Verify queued count persists

**Expected Result:** ✅ Messages queued locally, count accurate, persists across navigation

#### Test 2.2: Auto-Send When Online
**Steps:**
1. Queue 2 messages while offline (as in 2.1)
2. Disable airplane mode
3. Observe banner changes to "Sending queued messages..."
4. Wait for messages to send
5. Verify messages appear in conversation
6. Verify banner disappears

**Expected Result:** ✅ Queued messages automatically sent, banner shows progress, messages appear

#### Test 2.3: Queue Persistence Across App Restart
**Steps:**
1. Enable airplane mode
2. Send 3 messages (queued)
3. Force quit the app
4. Relaunch app (still in airplane mode)
5. Navigate to conversation
6. Verify offline banner shows "3 messages queued"
7. Disable airplane mode
8. Verify messages send automatically

**Expected Result:** ✅ Queue persists across app restarts, auto-sends on reconnect

#### Test 2.4: Mixed Message Types in Queue
**Steps:**
1. Enable airplane mode
2. Send text message
3. Send image message
4. Send voice message (if implemented)
5. Verify all show in queue count
6. Disable airplane mode
7. Verify all messages send in order

**Expected Result:** ✅ All message types queue and send correctly

---

### 3. Offline Persistence Testing

#### Test 3.1: Read Cached Conversations Offline
**Steps:**
1. Open app while online, browse conversations
2. Enable airplane mode
3. Navigate through conversation list
4. Open recent conversations
5. Scroll through messages

**Expected Result:** ✅ Cached conversations and messages accessible offline

#### Test 3.2: Write Operations While Offline
**Steps:**
1. Enable airplane mode
2. Send message (should queue)
3. React to message (may fail gracefully)
4. Try to edit message (may fail gracefully)
5. Check for appropriate error handling

**Expected Result:** ✅ Send operations queue, other operations fail gracefully with clear feedback

#### Test 3.3: Search Cached Data Offline
**Steps:**
1. Ensure recent conversations cached (browse while online)
2. Enable airplane mode
3. Use search functionality in conversations
4. Search for messages in conversation

**Expected Result:** ✅ Can search cached data, results returned from local cache

---

### 4. UI Offline Indicators Testing

#### Test 4.1: Offline Banner Display
**Steps:**
1. Enable airplane mode
2. Verify banner appears immediately
3. Check banner text: "No Internet Connection"
4. If messages queued, verify count displayed
5. Disable airplane mode
6. Verify banner changes to "Connection restored" briefly
7. Verify banner disappears after queue processed

**Expected Result:** ✅ Banner displays correct information at each stage

#### Test 4.2: Call Buttons Disabled
**Steps:**
1. Open direct conversation
2. Note call buttons enabled (blue)
3. Enable airplane mode
4. Verify call buttons grayed out
5. Try tapping disabled button (should do nothing)
6. Disable airplane mode
7. Verify call buttons re-enabled

**Expected Result:** ✅ Call buttons disabled when offline, re-enabled when online

#### Test 4.3: AI Assistant Offline Warning
**Steps:**
1. Navigate to AI Assistant tab
2. Enable airplane mode
3. Verify warning banner appears: "AI features require internet connection"
4. Type a message
5. Verify send button disabled (grayed)
6. Try to send (should show alert)
7. Disable airplane mode
8. Verify warning disappears, send button enabled

**Expected Result:** ✅ Clear warnings for AI features, send disabled, alert shown

---

### 5. Sync Service Testing

#### Test 5.1: Full Sync on App Launch
**Steps:**
1. Send messages to test account from another device
2. Force quit MessageAI app
3. Wait 30 seconds
4. Relaunch MessageAI
5. Watch console for sync logs
6. Verify new messages appear

**Expected Result:** ✅ Full sync runs on launch, new messages fetched

**Console Log Expected:**
```
🔄 SyncService: Starting full sync for user [userId]
🔄 SyncService: Syncing conversations
🔄 SyncService: Syncing messages
🔄 SyncService: Full sync completed successfully
```

#### Test 5.2: Incremental Sync
**Steps:**
1. Launch app, wait for initial sync
2. Note last sync time in console
3. Send messages from another device
4. Background app, wait 2 minutes
5. Return to app
6. Check console for incremental sync
7. Verify only recent changes fetched

**Expected Result:** ✅ Incremental sync runs, only new data fetched

**Console Log Expected:**
```
🔄 SyncService: Starting incremental sync since [timestamp]
🔄 SyncService: Syncing conversations since [timestamp]
🔄 SyncService: Fetched [N] updated conversations
```

#### Test 5.3: Sync on Connection Restore
**Steps:**
1. Enable airplane mode
2. Send messages from another device (to test account)
3. Wait 30 seconds
4. Disable airplane mode on test device
5. Watch console logs
6. Verify sync triggered automatically
7. Verify new messages appear

**Expected Result:** ✅ Sync triggered on connection restore, messages received

---

### 6. Background Sync Testing

#### Test 6.1: Background Task Registration
**Steps:**
1. Launch app
2. Check console logs for background task registration
3. Look for: "🔄 BackgroundSync: Registered background tasks"

**Expected Result:** ✅ Background tasks registered on launch

#### Test 6.2: Background Sync Scheduling
**Steps:**
1. Ensure app online and logged in
2. Background the app (home button)
3. Check console for: "🔄 BackgroundSync: Scheduled next background sync"
4. Check Xcode → Debug → Simulate Background Fetch
5. Verify sync runs in background

**Expected Result:** ✅ Background sync scheduled and can be triggered

> **Note:** Real background sync may take 15+ minutes and is controlled by iOS. Use Xcode simulation for testing.

---

### 7. Edge Cases & Error Handling

#### Test 7.1: Poor Connection Handling
**Steps:**
1. Use Network Link Conditioner (Xcode)
2. Set to "Very Bad Network" or "100% Loss"
3. Try sending message
4. Verify appropriate handling (queue or retry)
5. Restore good connection
6. Verify message sends

**Expected Result:** ✅ Graceful handling of poor connections

#### Test 7.2: Maximum Retry Limit
**Steps:**
1. Enable airplane mode
2. Queue a message
3. Manually trigger 5 failed send attempts (via code or mock)
4. Verify message removed from queue after 5 attempts
5. Check console for: "Message exceeded max retries, removing from queue"

**Expected Result:** ✅ Message removed after 5 failed attempts

#### Test 7.3: Large Queue Processing
**Steps:**
1. Enable airplane mode
2. Queue 20+ messages
3. Disable airplane mode
4. Verify all messages process in order
5. Monitor for any errors or timeouts

**Expected Result:** ✅ Large queues process successfully, in order

#### Test 7.4: Rapid Connection Changes
**Steps:**
1. Toggle airplane mode on/off rapidly (5-10 times)
2. Check for any crashes or stuck states
3. Verify app remains responsive
4. Check console for appropriate handling

**Expected Result:** ✅ App handles rapid connection changes gracefully

---

### 8. Performance Testing

#### Test 8.1: App Launch Time (Offline)
**Steps:**
1. Enable airplane mode
2. Force quit app
3. Relaunch app
4. Measure time to main screen
5. Compare with online launch time

**Expected Result:** ✅ Offline launch < 2 seconds (similar to online)

#### Test 8.2: Sync Performance
**Steps:**
1. Background app for 1+ hour (accumulate changes)
2. Return to app
3. Measure time for sync to complete
4. Note number of items synced

**Expected Result:** ✅ Sync completes in < 10 seconds for typical usage

#### Test 8.3: Queue Processing Time
**Steps:**
1. Queue 10 messages
2. Restore connection
3. Measure time to send all 10
4. Monitor UI responsiveness during processing

**Expected Result:** ✅ All messages sent in < 5 seconds, UI remains responsive

---

### 9. Multi-Device Sync Testing

#### Test 9.1: Message Sync Between Devices
**Steps:**
1. Login to same account on two devices
2. Send message from Device A
3. Verify appears on Device B within 5 seconds
4. Send message from Device B
5. Verify appears on Device A

**Expected Result:** ✅ Messages sync between devices in real-time

#### Test 9.2: Read Receipt Sync
**Steps:**
1. Device A: Send message to Device B
2. Device B: Read the message
3. Device A: Verify read receipt appears (blue checkmarks)

**Expected Result:** ✅ Read receipts sync correctly

---

### 10. Integration Testing

#### Test 10.1: Offline → Send → AI Features
**Steps:**
1. Enable airplane mode
2. Queue several messages
3. Disable airplane mode, wait for send
4. Try AI features (translate, summarize)
5. Verify AI works with newly sent messages

**Expected Result:** ✅ AI features work after offline messages sent

#### Test 10.2: Call Integration
**Steps:**
1. Verify can start call while online
2. Enable airplane mode during call
3. Verify call drops gracefully
4. Verify call buttons disabled after disconnect

**Expected Result:** ✅ Call features integrate properly with offline detection

---

## Console Log Monitoring

### Key Logs to Watch

**Network Monitor:**
```
🌐 NetworkMonitor: Started monitoring network status
🌐 NetworkMonitor: Status changed from Online to Offline
🌐 NetworkMonitor: Status changed from Offline to Online
```

**Message Queue:**
```
📤 MessageQueue: Queued text message for conversation [id]
📤 MessageQueue: Connection restored, processing queue
📤 MessageQueue: Successfully sent message [id]
📤 MessageQueue: Message [id] exceeded max retries
```

**Sync Service:**
```
🔄 SyncService: Starting full sync for user [userId]
🔄 SyncService: Fetched [N] conversations
🔄 SyncService: Synced messages for [N] conversations
🔄 SyncService: Full sync completed successfully
```

**Background Sync:**
```
🔄 BackgroundSync: Registered background tasks
🔄 BackgroundSync: Scheduled next background sync
🔄 BackgroundSync: Starting background sync
🔄 BackgroundSync: Completed background sync
```

---

## Bug Report Template

If you encounter issues, use this template:

```markdown
### Bug Report: [Short Description]

**Date:** [Date]
**iOS Version:** [Version]
**Device:** [Device Model]

**Steps to Reproduce:**
1. 
2. 
3. 

**Expected Behavior:**

**Actual Behavior:**

**Console Logs:**
```
[Paste relevant logs]
```

**Screenshots:**
[Attach if applicable]

**Notes:**
```

---

## Test Results Checklist

Mark each test as you complete it:

### Network Monitor
- [ ] 1.1: Connection Status Display
- [ ] 1.2: Connection Type Detection

### Message Queue
- [ ] 2.1: Queue Messages While Offline
- [ ] 2.2: Auto-Send When Online
- [ ] 2.3: Queue Persistence Across App Restart
- [ ] 2.4: Mixed Message Types in Queue

### Offline Persistence
- [ ] 3.1: Read Cached Conversations Offline
- [ ] 3.2: Write Operations While Offline
- [ ] 3.3: Search Cached Data Offline

### UI Offline Indicators
- [ ] 4.1: Offline Banner Display
- [ ] 4.2: Call Buttons Disabled
- [ ] 4.3: AI Assistant Offline Warning

### Sync Service
- [ ] 5.1: Full Sync on App Launch
- [ ] 5.2: Incremental Sync
- [ ] 5.3: Sync on Connection Restore

### Background Sync
- [ ] 6.1: Background Task Registration
- [ ] 6.2: Background Sync Scheduling

### Edge Cases
- [ ] 7.1: Poor Connection Handling
- [ ] 7.2: Maximum Retry Limit
- [ ] 7.3: Large Queue Processing
- [ ] 7.4: Rapid Connection Changes

### Performance
- [ ] 8.1: App Launch Time (Offline)
- [ ] 8.2: Sync Performance
- [ ] 8.3: Queue Processing Time

### Multi-Device
- [ ] 9.1: Message Sync Between Devices
- [ ] 9.2: Read Receipt Sync

### Integration
- [ ] 10.1: Offline → Send → AI Features
- [ ] 10.2: Call Integration

---

## Success Criteria

Phase 11 is considered successful if:

✅ **All critical tests pass** (1.1, 2.1, 2.2, 4.1, 5.1)  
✅ **No crashes or data loss** during offline/online transitions  
✅ **Messages queue and send reliably** when connection restored  
✅ **UI provides clear feedback** about offline state  
✅ **Sync completes within acceptable time** (< 10 seconds typical)  
✅ **App remains responsive** during all operations  

---

## Notes

- Test on both WiFi and cellular connections
- Test with various network speeds (use Network Link Conditioner)
- Test on multiple iOS versions if possible
- Test with both new and existing user accounts
- Monitor battery usage during extensive testing

---

**Testing Status:** Ready for QA  
**Last Updated:** October 24, 2025

