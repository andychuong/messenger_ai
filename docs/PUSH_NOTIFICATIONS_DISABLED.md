# Push Notifications - Temporarily Disabled

## 🔕 Current Status: DISABLED

Push notifications have been **temporarily disabled** to allow testing on physical devices without requiring:
- Apple Developer account push notification certificates
- APNs (Apple Push Notification service) setup
- Device provisioning for push capabilities

## 🎯 Why Disable?

When testing on a physical iPhone without proper APNs configuration, the app would:
- ❌ Request push notification permissions (and fail)
- ❌ Try to register for remote notifications (and fail)
- ❌ Attempt to get FCM tokens (and potentially crash or hang)

By disabling push notifications, you can:
- ✅ Build and run on physical devices immediately
- ✅ Test all app features (messaging, calls, etc.)
- ✅ Avoid APNs certificate errors
- ✅ Skip push notification permission dialogs

## 📝 What Was Changed

### Files Modified:

#### 1. `AppDelegate.swift`
```swift
// DISABLED FOR TESTING: Push notifications disabled
// UNUserNotificationCenter.current().delegate = self
// NotificationService.shared.configure()
```

**What was disabled:**
- Notification center delegate setup
- FCM configuration on app launch
- APNs token registration
- Notification handling (foreground & tap)

#### 2. `AuthService.swift`
```swift
private func setupNotifications(userId: String) async {
    // DISABLED FOR TESTING
    print("⚠️ Push notifications disabled - skipping setup")
}
```

**What was disabled:**
- Push notification permission request on login/signup
- FCM token saving to Firestore

#### 3. `NotificationService.swift`
```swift
func requestPermission() async -> Bool {
    // DISABLED FOR TESTING
    return false
}

func configure() {
    // DISABLED FOR TESTING
}

func getFCMToken() async {
    // DISABLED FOR TESTING
}
```

**What was disabled:**
- Permission request dialogs
- FCM token fetching
- Messaging delegate setup

## ✅ What Still Works

All app functionality works **without push notifications**:

### Messaging
- ✅ Send/receive messages (when app is open)
- ✅ Real-time message updates (Firestore listeners)
- ✅ Read receipts
- ✅ Emoji reactions
- ✅ Image sharing
- ✅ Voice messages

### Calls
- ✅ Initiate voice/video calls
- ✅ Receive calls (when app is open)
- ✅ WebRTC connection
- ✅ Audio/video transmission

### Other Features
- ✅ Friends system
- ✅ AI features (translation, assistant)
- ✅ Message threading
- ✅ Group chats
- ✅ User presence

## ⚠️ What Doesn't Work

### Without Push Notifications:
- ❌ **Background message notifications** - Users won't see new messages when app is closed
- ❌ **Call notifications** - Can't receive calls when app is in background
- ❌ **Message badges** - No badge count on app icon
- ❌ **Background wake-up** - App doesn't wake when messages arrive

### Workaround:
- Keep the app **open or in foreground** to receive messages and calls in real-time
- Firestore real-time listeners will update everything when the app is active

## 🔄 How to Re-Enable Push Notifications

When you're ready to set up push notifications properly:

### Step 1: Uncomment the Code

In **AppDelegate.swift**:
```swift
func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    
    // REMOVE the "DISABLED FOR TESTING" comments:
    UNUserNotificationCenter.current().delegate = self
    NotificationService.shared.configure()
    
    print("✅ AppDelegate: didFinishLaunchingWithOptions")
    return true
}

// Uncomment all notification methods
```

In **AuthService.swift**:
```swift
private func setupNotifications(userId: String) async {
    // REMOVE the "DISABLED FOR TESTING" comments:
    let granted = await NotificationService.shared.requestPermission()
    
    if granted {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await NotificationService.shared.saveTokenToFirestore(userId: userId)
    }
}
```

In **NotificationService.swift**:
```swift
// Uncomment all the disabled methods:
// - requestPermission()
// - configure()
// - getFCMToken()
```

### Step 2: Configure APNs

1. **Apple Developer Account**
   - Log in to https://developer.apple.com
   - Go to Certificates, Identifiers & Profiles

2. **Create APNs Key**
   - Go to Keys
   - Create new key with APNs capability
   - Download the `.p8` file

3. **Upload to Firebase**
   - Go to Firebase Console → Project Settings
   - Go to Cloud Messaging tab
   - Upload APNs key (.p8 file)
   - Add Key ID and Team ID

4. **Update Entitlements**
   - In Xcode, ensure "Push Notifications" capability is enabled
   - Check that `messagingapp.entitlements` includes:
     ```xml
     <key>aps-environment</key>
     <string>development</string>
     ```

### Step 3: Test Push Notifications

```bash
# Test using Firebase Console
# OR use the test notification scripts in the repo:
firebase deploy --only functions
# Then send test notification via Cloud Functions
```

## 📖 References

- [Firebase Cloud Messaging Setup](./FCM_SETUP_COMPLETE.md)
- [Apple Push Notifications Guide](https://developer.apple.com/documentation/usernotifications)
- [Firebase FCM Docs](https://firebase.google.com/docs/cloud-messaging/ios/client)

## 🧪 Testing on Physical Device

### Before Running on Your iPhone:

1. **Connect your iPhone** via USB cable
2. **Trust the computer** (on iPhone when prompted)
3. **Select device in Xcode**:
   - Click on the device dropdown (top bar)
   - Select your connected iPhone
4. **Build and Run** (Cmd + R)

### What to Test:

#### Messaging
- [ ] Send messages between two accounts
- [ ] Receive messages in real-time (app must be open)
- [ ] Send images
- [ ] Send voice messages
- [ ] React with emojis

#### Voice/Video Calls
- [ ] Initiate audio call
- [ ] Receive audio call (app must be open)
- [ ] **Verify audio works** (this is the key test!)
- [ ] Initiate video call
- [ ] Receive video call
- [ ] **Verify video works** (camera feeds visible)
- [ ] Test mute/unmute
- [ ] Test camera flip
- [ ] Test speaker toggle

#### Other Features
- [ ] Add friends
- [ ] Use AI translation
- [ ] Use voice-to-text
- [ ] Create message threads
- [ ] Create group chats

## 📊 Comparison

| Feature | With Push Notifications | Without Push Notifications |
|---------|------------------------|---------------------------|
| Real-time messaging (app open) | ✅ Works | ✅ Works |
| Background notifications | ✅ Works | ❌ Doesn't work |
| Call while app open | ✅ Works | ✅ Works |
| Call while app closed | ✅ Works | ❌ Doesn't work |
| Badge count | ✅ Works | ❌ Doesn't work |
| Voice/Video quality | ✅ Same | ✅ Same |
| Device testing | Requires APNs setup | ✅ Works immediately |

## 🎯 Recommendation

**For Development/Testing:**
- ✅ Keep push notifications **disabled**
- Test all features with app in foreground
- Much easier to iterate quickly

**For Production/Real Use:**
- ✅ Re-enable push notifications
- Set up proper APNs certificates
- Users can receive notifications when app is closed

## 💡 Tips

1. **Keep app in foreground** during testing to receive real-time updates
2. **Use two physical devices** (or one physical + one simulator) for testing calls
3. **Check Xcode console** for the "⚠️ Push notifications disabled" messages to confirm it's working
4. **Firebase Cloud Functions** still work - they just can't send push notifications

## 🔗 Related Documentation

- [Calling Testing Guide](./CALLING_TESTING_GUIDE.md) - How to test calls on physical devices
- [Calling Fixes](./CALLING_FIXES.md) - Recent fixes to calling feature
- [Phase 5 Complete](./PHASE5_COMPLETE.md) - Voice/video calling implementation


