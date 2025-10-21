# Phase 4 - Quick Testing Guide (15 Minutes)

This is a fast, essential test to verify all Phase 4 features are working. For comprehensive testing, see `PHASE4_TESTING_PLAN.md`.

---

## Setup (2 minutes)

1. **Login as User 1** (`user1@test.com`)
2. **Open conversation** with an existing friend
3. **Grant permissions** when prompted:
   - Microphone (for voice messages)
   - Photos (for image sharing)

---

## Quick Tests (13 minutes)

### ✅ Test 1: Emoji Reactions (2 min)
1. Send message: "Test message"
2. Long-press → Tap **"❤️ React"**
3. ✅ Verify: Heart appears below message
4. Long-press → **"More Reactions"** → Select any emoji
5. ✅ Verify: Full picker works, emoji appears

---

### ✅ Test 2: Message Editing (2 min)
1. Send message: "Original text"
2. Long-press → **"Edit"**
3. ✅ Verify: Edit mode UI appears (blue header)
4. Change to: "Edited text"
5. Tap checkmark
6. ✅ Verify: Message updates, "Edited" label appears

---

### ✅ Test 3: Image Sharing (3 min)
1. Clear text input
2. Tap **photo button (📷)**
3. ✅ Verify: Photo picker opens
4. Select an image
5. ✅ Verify: Image uploads and displays in chat

---

### ✅ Test 4: Voice Messages (4 min)
1. Clear text input
2. Tap **microphone button (🎤)**
3. ✅ Verify: Full-screen recorder opens
4. Grant microphone permission
5. Tap red mic → Speak for 3 seconds → Tap stop
6. ✅ Verify: Waveform animates, duration shows
7. Tap blue send button
8. ✅ Verify: Voice message appears with play button
9. Tap play button
10. ✅ Verify: Audio plays, progress bar animates

---

### ✅ Test 5: Threading (2 min)
1. Long-press any message → **"Reply in Thread"**
2. ✅ Verify: Thread view opens with parent message
3. Type: "Thread reply"
4. Send
5. ✅ Verify: Reply appears
6. Go back to main chat
7. ✅ Verify: "1 reply" badge appears on parent message

---

## Result

**All tests passed?** ✅ Phase 4 is working!

**Any failures?** See `PHASE4_TESTING_PLAN.md` for detailed testing and troubleshooting.

---

## Quick Demo Flow

Want to show off all features? Try this:

1. Send: "Check out these new features! 🎉"
2. React with 🔥 (via full picker)
3. Send an image
4. React to the image with ❤️
5. Send voice message: "Voice messages work too!"
6. Edit first message → add "They're awesome!"
7. Reply to first message in thread
8. Show the thread badge

**Time: 2 minutes | Impact: Impressive! 🚀**

