# Phase 11: Offline Support - Quick Start Guide

**Quick reference for using and testing offline features**

---

## 🚀 Quick Demo (2 minutes)

### Test Offline Messaging
1. Open MessageAI app
2. Enable **Airplane Mode** on your device
3. Send a message in any conversation
4. Notice the **orange banner**: "No Internet Connection - 1 message queued"
5. Disable **Airplane Mode**
6. Watch the banner change to **"Sending queued messages..."**
7. Message sends automatically! ✨

---

## 📱 User-Facing Features

### Offline Banner
**What it shows:**
- 🔴 **Offline:** "No Internet Connection" + queued message count
- 🟢 **Reconnecting:** "Sending queued messages..." + progress
- ✅ **Done:** "Connection restored" (disappears after 2s)

**Where:** Top of screen, above all tabs

### Disabled Features When Offline
- ❌ **Voice/Video Calls** (buttons grayed out)
- ❌ **AI Assistant** (shows warning banner)
- ✅ **Messaging** (queues messages for sending)
- ✅ **Reading Messages** (from cache)
- ✅ **Navigation** (all views accessible)

---

## 🛠️ Developer Features

### Network Monitoring

**Access the monitor:**
```swift
@EnvironmentObject var networkMonitor: NetworkMonitor

// Check status
if networkMonitor.isConnected {
    // Online
} else {
    // Offline
}
```

**Connection info:**
```swift
networkMonitor.status          // .online, .offline, .unknown
networkMonitor.isConnected     // Bool
networkMonitor.isCellular      // Bool
networkMonitor.connectionType  // "WiFi", "Cellular", "No Connection"
```

### Message Queue

**Check queue status:**
```swift
let queueService = MessageQueueService.shared

// Get count
let count = queueService.queuedMessages.count

// Check if specific message queued
let isQueued = queueService.isMessageQueued(messageId: id)

// Manually trigger processing
await queueService.processQueue()
```

### Sync Service

**Trigger sync manually:**
```swift
let syncService = SyncService.shared

// Full sync
await syncService.performFullSync()

// Incremental sync
await syncService.performIncrementalSync()

// Check sync status
if syncService.isSyncing {
    print("Sync in progress")
}
```

---

## 🧪 Testing Commands

### Xcode Console

**Simulate offline:**
```bash
# Enable airplane mode programmatically (not available in simulator)
# Use device Settings > Airplane Mode
```

**Monitor logs:**
```bash
# Filter console for offline features
🌐  # Network Monitor logs
📤  # Message Queue logs
🔄  # Sync Service logs
```

### Xcode Debugging

**Simulate background fetch:**
1. Xcode → Debug menu
2. Simulate Background Fetch
3. Watch console for background sync logs

**Network conditions:**
1. Settings → Developer → Network Link Conditioner
2. Enable conditioning
3. Select profile (e.g., "100% Loss", "Very Bad Network")

---

## 📊 Key Metrics to Monitor

### Performance Targets
- **Queue message:** < 100ms
- **Process queue:** < 5s for 10 messages
- **Incremental sync:** < 10s
- **Full sync:** < 30s
- **App launch (offline):** < 2s

### Console Logs to Watch

**Successful offline message:**
```
📤 MessageQueue: Queued text message for conversation [id]
🌐 NetworkMonitor: Status changed from Offline to Online
📤 MessageQueue: Connection restored, processing queue
📤 MessageQueue: Successfully sent message [id]
```

**Successful sync:**
```
🔄 SyncService: Starting incremental sync since [timestamp]
🔄 SyncService: Fetched [N] updated conversations
🔄 SyncService: Synced messages for [N] conversations
🔄 SyncService: Incremental sync completed successfully
```

---

## 🐛 Common Issues & Fixes

### Issue: Banner doesn't appear when offline
**Fix:** Ensure NetworkMonitor is passed as environment object
```swift
MainTabView()
    .environmentObject(networkMonitor)
```

### Issue: Messages don't send when reconnected
**Check:**
1. Console for error messages
2. Queue has items: `MessageQueueService.shared.queuedMessages`
3. Network monitor shows online: `NetworkMonitor.shared.isConnected`

### Issue: Sync not running on app launch
**Check:**
1. User is authenticated
2. Console for sync logs
3. Network is available

### Issue: Background sync not working
**Check:**
1. Info.plist has `BGTaskSchedulerPermittedIdentifiers`
2. Background mode "processing" enabled
3. Use Xcode simulate background fetch for testing

---

## 📝 Code Examples

### Example 1: Check connectivity before action
```swift
@EnvironmentObject var networkMonitor: NetworkMonitor

func sendMessage() {
    guard networkMonitor.isConnected else {
        showAlert("No internet connection")
        return
    }
    
    // Send message
}
```

### Example 2: Observe network changes
```swift
class MyViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default
            .publisher(for: .networkStatusChanged)
            .sink { notification in
                if let isConnected = notification.userInfo?["isConnected"] as? Bool {
                    print("Network changed: \(isConnected)")
                }
            }
            .store(in: &cancellables)
    }
}
```

### Example 3: Queue custom message
```swift
// Text message
await MessageQueueService.shared.queueTextMessage(
    id: UUID().uuidString,
    conversationId: conversationId,
    text: "Hello",
    shouldEncrypt: true
)

// Image message
await MessageQueueService.shared.queueImageMessage(
    id: UUID().uuidString,
    conversationId: conversationId,
    imageURL: imageURL,
    caption: "Check this out"
)
```

---

## 🔍 Debugging Checklist

When testing offline features:

- [ ] Enable airplane mode
- [ ] Check banner appears
- [ ] Send message
- [ ] Check queue count increases
- [ ] Check console for queue log
- [ ] Disable airplane mode
- [ ] Check banner changes
- [ ] Verify message sends
- [ ] Check console for send success
- [ ] Verify banner disappears

---

## 📚 Related Documentation

- **Full Implementation:** `PHASE11_COMPLETE.md`
- **Testing Guide:** `PHASE11_TESTING_GUIDE.md`
- **App Plan:** `APP_PLAN.md` (Phase 11 section)

---

## 🎯 Next Steps

After testing Phase 11:

1. ✅ Test basic offline messaging
2. ✅ Test queue persistence (force quit app)
3. ✅ Test with poor network conditions
4. ✅ Test background sync (background app 15+ min)
5. ✅ Test all UI indicators
6. ✅ Review console logs for errors
7. ✅ Monitor performance metrics
8. 📝 Report any issues found

---

## 💡 Tips

- **Testing offline:** Use airplane mode, not just WiFi off
- **Background sync:** Requires physical device, may take 15+ minutes
- **Queue testing:** Force quit app to test persistence
- **Network conditions:** Use Network Link Conditioner for realistic testing
- **Logs:** Filter Xcode console by emoji (🌐 📤 🔄) for relevant logs

---

**Quick Start Version:** 1.0  
**Last Updated:** October 24, 2025  
**Status:** Ready for Testing ✅

