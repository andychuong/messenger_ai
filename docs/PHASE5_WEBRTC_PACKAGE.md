# Adding WebRTC to Xcode Project

## Option 1: Swift Package Manager (Recommended)

### Step 1: Open Package Dependencies

In Xcode:
```
File → Add Package Dependencies...
```

### Step 2: Add WebRTC Package

**URL:** `https://github.com/stasel/WebRTC.git`

**Dependency Rule:** "Up to Next Major Version" `115.0.0 < 116.0.0`

Click "Add Package"

### Step 3: Select Target

- Select target: `messagingapp`
- Product: `WebRTC`
- Click "Add Package"

### Step 4: Verify Installation

In your project navigator, you should see:
```
Dependencies
  └── WebRTC
```

---

## Option 2: Manual Framework (Alternative)

If Swift Package Manager doesn't work:

### Step 1: Download Framework

Download WebRTC.xcframework from:
- [Google WebRTC Releases](https://github.com/stasel/WebRTC/releases)
- Choose latest stable release (e.g., `115.0.0`)

### Step 2: Add to Project

1. Drag `WebRTC.xcframework` into Xcode project
2. Check "Copy items if needed"
3. Add to target: `messagingapp`

### Step 3: Embed Framework

Project Settings → General → Frameworks, Libraries, and Embedded Content
- WebRTC.xcframework → Embed & Sign

---

## Verification

### Test Import

Create a test file:

```swift
import WebRTC

// If this compiles without errors, WebRTC is installed correctly
let config = RTCConfiguration()
print("WebRTC version: \(RTCPeerConnection.sdpSemantics)")
```

### Build Test

Try building the project (Cmd+B). If successful, WebRTC is properly integrated.

---

## Troubleshooting

### "No such module 'WebRTC'"

1. Clean build folder: Shift+Cmd+K
2. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Close and reopen Xcode
4. Build again (Cmd+B)

### "Missing or invalid signature"

- If using manual framework:
  - Verify framework is signed
  - Check "Embed & Sign" in project settings

### Version Conflicts

- Ensure minimum iOS version is 13.0+ (WebRTC requirement)
- Check deployment target in project settings

---

## Package Information

**Repository:** https://github.com/stasel/WebRTC  
**License:** BSD 3-Clause  
**Minimum iOS:** 13.0  
**Recommended Version:** 115.0.0+

---

**Document Version:** 1.0  
**For:** MessageAI Phase 5 WebRTC Setup

