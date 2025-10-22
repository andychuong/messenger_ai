# Phase 4: Rich Messaging Features - Testing Plan

## Overview

This document provides a comprehensive testing plan for all Phase 4 features. Follow this step-by-step guide to verify that emoji reactions, message editing, image sharing, voice messages, and message threading work correctly.

---

## Prerequisites

### Setup Requirements

1. **Two Test Accounts** (from Phase 1-2):
   - User 1: `user1@test.com` (Alice)
   - User 2: `user2@test.com` (Bob)
   - Both should already be friends

2. **Testing Environment**:
   - Option A: Two iOS Simulators running simultaneously
   - Option B: One simulator + one physical device
   - Option C: Two physical devices

3. **Firebase Setup**:
   - Firestore database accessible
   - Firebase Storage enabled
   - Cloud Functions deployed (for voice transcription)

4. **Permissions**:
   - Microphone permission (for voice messages)
   - Photo library permission (for image sharing)

---

## Testing Schedule

| Feature | Priority | Time | Status |
|---------|----------|------|--------|
| Emoji Reactions | P0 | 15 min | ⬜ |
| Message Editing | P0 | 10 min | ⬜ |
| Image Sharing | P0 | 15 min | ⬜ |
| Voice Messages | P0 | 20 min | ⬜ |
| Message Threading | P0 | 15 min | ⬜ |
| Integration Tests | P1 | 10 min | ⬜ |
| **Total** | | **~85 min** | |

---

## Test 1: Emoji Reactions (15 minutes)

### 1.1 Quick Reactions from Context Menu

**User 1 (Alice):**
1. Open conversation with Bob
2. Send a text message: "Hey Bob! 👋"
3. Long-press the message you just sent
4. Verify context menu appears with options:
   - ❤️ React
   - 👍 React
   - 😂 React
   - More Reactions
5. Tap **"❤️ React"**
6. ✅ **Expected**: Heart emoji appears below the message

**User 2 (Bob):**
1. Open conversation with Alice
2. Find Alice's message "Hey Bob! 👋"
3. ✅ **Expected**: See ❤️ reaction below the message (real-time)
4. Long-press the same message
5. Tap **"👍 React"**
6. ✅ **Expected**: Both ❤️ and 👍 appear below message

**User 1 (Alice):**
1. Look at your message
2. ✅ **Expected**: See both ❤️ and 👍 reactions with count
3. Long-press the message again
4. Tap **"❤️ React"** again
5. ✅ **Expected**: Your ❤️ reaction is removed (toggle off)

**Pass Criteria:**
- ✅ Context menu shows quick reaction options
- ✅ Reactions appear below messages immediately
- ✅ Multiple users can react to same message
- ✅ Reaction counts display correctly
- ✅ Tapping same reaction removes it

---

### 1.2 Full Emoji Picker

**User 1 (Alice):**
1. Long-press any message
2. Select **"More Reactions"**
3. ✅ **Expected**: Full-screen emoji picker appears
4. Verify the following elements:
   - Title: "React"
   - Cancel button (top-left)
   - Search bar at top
   - 8 category tabs below search
   - Grid of emojis (8 columns)

5. **Test Categories**: Tap each category icon and verify emojis change:
   - 😀 Smileys & People
   - 🐶 Animals & Nature
   - 🍎 Food & Drink
   - ⚽️ Activity
   - ✈️ Travel & Places
   - 💡 Objects
   - ❤️ Symbols
   - 🏁 Flags

6. Select an emoji from "Food & Drink": **🍕**
7. ✅ **Expected**: 
   - Picker dismisses
   - 🍕 appears on the message
   - Message displays with reaction

8. Send a new message: "Testing more reactions!"
9. Long-press → "More Reactions"
10. Select **🎉** from Smileys
11. ✅ **Expected**: 🎉 appears on message

**User 2 (Bob):**
1. Long-press one of Alice's messages with a reaction
2. Select "More Reactions"
3. Choose a different emoji: **🔥**
4. ✅ **Expected**: Both emojis appear with counts

**Test Recently Used:**
1. Open emoji picker again
2. ✅ **Expected**: "Recently Used" section appears at top
3. ✅ **Expected**: Shows 🍕, 🎉, 🔥 (most recent emojis used)

**Pass Criteria:**
- ✅ Full emoji picker opens correctly
- ✅ All 8 categories load with emojis
- ✅ Emoji selection works
- ✅ Picker auto-dismisses after selection
- ✅ Recently used section appears and updates
- ✅ Multiple reactions display with counts

---

## Test 2: Message Editing (10 minutes)

### 2.1 Basic Message Editing

**User 1 (Alice):**
1. Send a message: "The meeting is at 3PM"
2. Long-press the message
3. ✅ **Expected**: Context menu shows **"Edit"** option
4. Tap **"Edit"**
5. ✅ **Expected**: 
   - Input bar changes to edit mode
   - Blue header appears above input showing "Edit Message"
   - Original text appears: "The meeting is at 3PM"
   - X button to cancel
   - Checkmark send button (instead of arrow)

6. Modify text to: "The meeting is at 3:30PM"
7. Tap the **checkmark button**
8. ✅ **Expected**:
   - Message updates in chat
   - "Edited" label appears below message
   - Edit mode closes
   - Input bar returns to normal

**User 2 (Bob):**
1. Look at Alice's message
2. ✅ **Expected**: 
   - See updated text "The meeting is at 3:30PM"
   - See "Edited" label below message

**Pass Criteria:**
- ✅ Edit option appears for own messages
- ✅ Edit mode UI displays correctly
- ✅ Can modify text and save
- ✅ "Edited" indicator appears
- ✅ Changes sync in real-time

---

### 2.2 Edit Time Window (15 minutes)

**User 1 (Alice):**
1. Send a new message: "Test edit window"
2. Immediately long-press the message
3. ✅ **Expected**: "Edit" option is available
4. Tap "Edit" then tap X to cancel
5. Wait **16 minutes** (or adjust system time)
6. Long-press the same message again
7. ✅ **Expected**: "Edit" option is **NOT available** (disabled)

**Note:** To test quickly without waiting:
- You can temporarily modify the `canBeEdited()` function in `Message.swift` to use 1 minute instead of 15
- Or use simulator time manipulation

**Pass Criteria:**
- ✅ Edit available within 15-minute window
- ✅ Edit disabled after 15 minutes
- ✅ Can cancel edit without changes

---

### 2.3 Edit Mode Cancel

**User 1 (Alice):**
1. Send message: "Original text"
2. Long-press → "Edit"
3. Change text to: "Modified text"
4. Tap the **X button** (cancel)
5. ✅ **Expected**:
   - Edit mode closes
   - Message remains unchanged: "Original text"
   - Input bar clears

**Pass Criteria:**
- ✅ Cancel button exits edit mode
- ✅ Original message unchanged
- ✅ No "Edited" label appears

---

## Test 3: Image Sharing (15 minutes)

### 3.1 Send Image

**Setup**: Have a few test images in your simulator/device photo library

**User 1 (Alice):**
1. Open conversation with Bob
2. Clear the text input field (if any text)
3. ✅ **Expected**: Photo button (📷) appears in input bar
4. Tap the **photo button**
5. ✅ **Expected**: 
   - Photo picker opens
   - Shows device photo library
   - Can select images

6. Select an image from library
7. ✅ **Expected**:
   - Picker dismisses
   - Image starts uploading (loading spinner may appear)
   - Image appears in chat with rounded corners
   - Message bubble contains the image

8. ✅ **Verify Image Display**:
   - Max width: ~250px
   - Max height: ~300px
   - Rounded corners (12pt radius)
   - Appears on right side (sent by you)

**User 2 (Bob):**
1. Open conversation with Alice
2. ✅ **Expected**:
   - Alice's image appears automatically (real-time)
   - Image displays on left side (received message)
   - Can see the full image

**Pass Criteria:**
- ✅ Photo picker opens correctly
- ✅ Image uploads successfully
- ✅ Image displays in chat bubble
- ✅ Proper sizing and styling
- ✅ Real-time delivery to recipient

---

### 3.2 Image Loading States

**User 1 (Alice):**
1. Take a screenshot or find a large image
2. Send it via photo picker
3. ✅ **Observe Loading States**:
   - **Loading**: ProgressView/spinner appears
   - **Success**: Image displays clearly
   - No error messages

4. If you have slow connection:
   - Turn on Airplane mode briefly
   - Try sending image
   - ✅ **Expected**: Appropriate loading state or retry

**Pass Criteria:**
- ✅ Loading indicator during upload
- ✅ Success state shows image
- ✅ Graceful handling of errors

---

### 3.3 Multiple Images

**User 1 (Alice):**
1. Send an image
2. Send a text message: "Here's another one"
3. Send another image
4. ✅ **Expected**: All messages display correctly in order

**User 2 (Bob):**
1. Verify all messages received
2. Send an image back to Alice
3. ✅ **Expected**: Image appears on right side

**Pass Criteria:**
- ✅ Multiple images can be sent
- ✅ Text and images can be mixed
- ✅ Correct alignment (sent vs received)

---

## Test 4: Voice Messages (20 minutes)

### 4.1 Record and Send Voice Message

**User 1 (Alice):**
1. Open conversation with Bob
2. Clear text input field
3. ✅ **Expected**: Microphone button (🎤) appears
4. Tap the **microphone button**
5. ✅ **Expected**: 
   - Permission prompt for microphone (first time)
   - Full-screen voice recorder opens

6. **Grant microphone permission** (if prompted)

7. ✅ **Verify Voice Recorder UI**:
   - Title: "Voice Message"
   - X button to close
   - Large timer showing "0:00"
   - Three buttons at bottom:
     - Red trash icon (Cancel)
     - Red/Orange mic icon (Record/Stop)
     - Blue arrow icon (Send) - disabled initially

8. Tap the **red microphone button** to start recording
9. ✅ **Expected While Recording**:
   - Timer starts counting: 0:01, 0:02, etc.
   - Mic button turns orange
   - Waveform animation appears (20 animated bars)
   - "Recording..." indicator with red dot

10. Speak for 5-10 seconds: "Hey Bob, this is a voice message test!"
11. Tap the **orange stop button**
12. ✅ **Expected After Stopping**:
    - Recording stops
    - Timer shows final duration
    - Blue send button is now **enabled**
    - Can review duration

13. Tap the **blue send button**
14. ✅ **Expected**:
    - Recorder closes
    - Voice message appears in chat
    - Shows as blue bubble (sent by you)
    - Contains play button, progress bar, duration

**User 2 (Bob):**
1. ✅ **Expected**: Voice message appears in chat
2. ✅ **Verify Voice Message Display**:
   - Gray bubble (received message)
   - Play button (▶) on left
   - Progress bar in middle
   - Duration on right (e.g., "0:05")
   - Waveform icon

3. Tap the **play button**
4. ✅ **Expected**:
   - Audio plays
   - Button changes to pause (⏸)
   - Progress bar animates
   - Duration counts up: 0:01, 0:02, etc.

5. Let it play to completion
6. ✅ **Expected**: 
   - Returns to play button when finished
   - Progress bar resets

**Pass Criteria:**
- ✅ Microphone permission requested
- ✅ Voice recorder UI displays correctly
- ✅ Recording starts/stops properly
- ✅ Waveform animates during recording
- ✅ Duration tracks correctly
- ✅ Voice message sends successfully
- ✅ Playback controls work
- ✅ Progress bar animates during playback

---

### 4.2 Voice Message - Cancel Recording

**User 1 (Alice):**
1. Tap microphone button
2. Start recording
3. Speak for a few seconds
4. Tap the **red trash button** (Cancel)
5. ✅ **Expected**:
   - Recording stops immediately
   - Recorder closes
   - No message sent
   - Recording file deleted

**Pass Criteria:**
- ✅ Cancel button stops recording
- ✅ No message sent
- ✅ Returns to chat view

---

### 4.3 Voice Message - Minimum Duration

**User 1 (Alice):**
1. Tap microphone button
2. Start recording
3. Stop immediately (< 0.5 seconds)
4. ✅ **Expected**: Send button remains **disabled**
5. Start recording again
6. Record for at least 1 second
7. Stop
8. ✅ **Expected**: Send button is now **enabled**

**Pass Criteria:**
- ✅ Minimum duration validation (0.5 seconds)
- ✅ Send button disabled for too-short recordings

---

### 4.4 Voice Transcription (Cloud Function)

**Note:** This tests the backend AI transcription feature.

**User 1 (Alice):**
1. Send a voice message with clear speech: "This is a test of voice transcription"
2. Note the message ID

**Check Firestore Console:**
1. Open Firebase Console → Firestore
2. Navigate to: `conversations/{conversationId}/messages/{messageId}`
3. Wait 5-10 seconds
4. ✅ **Expected**: 
   - Field `voiceTranscript` appears
   - Contains text: "This is a test of voice transcription" (or similar)
   - Field `transcribedAt` shows timestamp

**Note:** The UI to display transcripts can be added later. For now, verify they're being generated in the backend.

**Pass Criteria:**
- ✅ Voice messages trigger transcription
- ✅ Transcripts stored in Firestore
- ✅ Reasonable accuracy
- ✅ Processing time < 10 seconds

---

## Test 5: Message Threading (15 minutes)

### 5.1 Start a Thread

**User 1 (Alice):**
1. Send a main message: "Should we meet on Monday or Tuesday?"
2. Wait for it to send

**User 2 (Bob):**
1. Long-press Alice's message
2. ✅ **Expected**: Context menu shows **"Reply in Thread"** option
3. Tap **"Reply in Thread"**
4. ✅ **Expected**: 
   - Thread view opens
   - Parent message displayed at top in header
   - "Thread" title in navigation bar
   - "0 replies" indicator
   - Empty state: "No replies yet"
   - Reply input bar at bottom

5. Type in input bar: "Monday works better for me"
6. Tap send
7. ✅ **Expected**:
   - Reply appears in thread view
   - Auto-scrolls to show reply
   - Header updates to "1 reply"

**User 1 (Alice):**
1. Look at main conversation
2. ✅ **Expected**: 
   - Your message now shows a blue badge below it
   - Badge says "1 reply"
   - Badge is tappable

3. Tap the **"1 reply"** badge
4. ✅ **Expected**:
   - Thread view opens
   - See parent message at top
   - See Bob's reply: "Monday works better for me"

5. Type a reply: "Great! Let's meet at 2PM"
6. Send
7. ✅ **Expected**: Reply appears in thread

**User 2 (Bob):**
1. ✅ **Expected**: Reply appears in real-time in thread view
2. Navigate back to main conversation
3. ✅ **Expected**: Badge now shows "2 replies"

**Pass Criteria:**
- ✅ "Reply in Thread" option in context menu
- ✅ Thread view opens with parent message
- ✅ Can send replies in thread
- ✅ Reply count updates in real-time
- ✅ Badge appears on parent message
- ✅ Tapping badge opens thread

---

### 5.2 Thread with Multiple Replies

**User 1 (Alice):**
1. In the thread, send 3 more messages:
   - "We could meet at the office"
   - "Or grab lunch somewhere"
   - "What do you prefer?"

**User 2 (Bob):**
1. ✅ **Expected**: All 3 messages appear in real-time
2. Reply: "Let's grab lunch!"
3. Navigate back to main chat
4. ✅ **Expected**: Badge shows "6 replies"

**Pass Criteria:**
- ✅ Multiple replies work
- ✅ All replies display chronologically
- ✅ Counter updates correctly
- ✅ Real-time sync works

---

### 5.3 Thread Features Work

**User 1 (Alice):**
1. In the thread view
2. Long-press one of your replies
3. ✅ **Expected**: Context menu shows:
   - Quick reactions (❤️, 👍, 😂)
   - More Reactions
   - Copy
   - Delete

4. React to a reply with 👍
5. ✅ **Expected**: Reaction appears on the reply

**User 2 (Bob):**
1. Long-press one of Alice's replies in thread
2. React with ❤️
3. ✅ **Expected**: Both reactions display

**Pass Criteria:**
- ✅ All message features work in threads
- ✅ Reactions work in threads
- ✅ Copy works in threads
- ✅ Delete works for own messages

---

### 5.4 Multiple Threads

**User 1 (Alice):**
1. Go back to main conversation
2. Send a new message: "Separate topic: What's the project deadline?"
3. Wait for it to send

**User 2 (Bob):**
1. Long-press the new message → "Reply in Thread"
2. Send a reply: "End of this month"

**User 1 (Alice):**
1. ✅ **Expected**: Now have 2 messages with thread badges
2. Tap first thread badge
3. ✅ **Expected**: Opens first thread (about Monday meeting)
4. Go back
5. Tap second thread badge
6. ✅ **Expected**: Opens second thread (about deadline)

**Pass Criteria:**
- ✅ Multiple independent threads work
- ✅ Each thread maintains separate replies
- ✅ Correct thread opens when tapping badge
- ✅ Threads don't interfere with each other

---

## Test 6: Integration Tests (10 minutes)

### 6.1 All Features Together

**Scenario: Planning a party**

**User 1 (Alice):**
1. Send text: "Planning a surprise party for Sarah!"
2. Send an image of party decorations
3. Long-press the image → React with 🎉

**User 2 (Bob):**
1. Reply in thread to the main message
2. In thread: "Count me in! What can I bring?"
3. React to Alice's image with 🎊

**User 1 (Alice):**
1. In the thread, send voice message: "Can you handle the music?"
2. Send text in thread: "And maybe some snacks"

**User 2 (Bob):**
1. Play the voice message
2. React to it with 👍
3. Reply in thread: "Got it! I'll bring speakers"

**User 1 (Alice):**
1. Edit your earlier message to: "Planning a surprise party for Sarah on Saturday!"
2. ✅ **Verify**: "Edited" label appears

**Pass Criteria:**
- ✅ Text, images, and voice work together
- ✅ Reactions work on all message types
- ✅ Threading works with mixed media
- ✅ Editing works in main chat
- ✅ All features work simultaneously

---

### 6.2 Performance Test

**User 1 (Alice):**
1. Send 10 messages rapidly
2. React to each message
3. Send 2 images
4. Send 2 voice messages
5. Start 3 different threads

**Observe:**
- ✅ App remains responsive
- ✅ No crashes or freezes
- ✅ All messages sync correctly
- ✅ UI updates smoothly
- ✅ Memory usage reasonable

**Pass Criteria:**
- ✅ Handles burst of messages
- ✅ No performance degradation
- ✅ All features still work after heavy use

---

## Test 7: Edge Cases (15 minutes)

### 7.1 Empty States

**Test:**
1. New conversation with no messages
2. ✅ **Expected**: Empty state shows "No messages yet"

3. Open thread with no replies yet
4. ✅ **Expected**: "No replies yet" + "Start the conversation!"

**Pass Criteria:**
- ✅ Appropriate empty states display
- ✅ Clear call-to-action messaging

---

### 7.2 Long Messages

**User 1 (Alice):**
1. Send a very long text message (500+ characters)
2. ✅ **Expected**: 
   - Message wraps properly in bubble
   - Doesn't break layout
   - Scrollable if needed

3. Edit the long message
4. ✅ **Expected**: Edit UI handles long text

**Pass Criteria:**
- ✅ Long text doesn't break UI
- ✅ Text wraps correctly
- ✅ Editing long text works

---

### 7.3 Network Issues

**Test:**
1. Turn on Airplane mode
2. Try sending a message
3. ✅ **Expected**: Appropriate error handling
4. Turn off Airplane mode
5. ✅ **Expected**: Message sends when reconnected

**Pass Criteria:**
- ✅ Graceful offline handling
- ✅ Auto-retry when back online

---

### 7.4 Delete Messages

**User 1 (Alice):**
1. Send a message with reactions
2. Delete the message
3. ✅ **Expected**: Message and reactions disappear

4. Send a message in a thread
5. Delete it
6. ✅ **Expected**: Reply removed from thread

**Pass Criteria:**
- ✅ Delete works for all message types
- ✅ Reactions removed with message
- ✅ Thread count updates when reply deleted

---

## Test Checklist Summary

### Feature Completion

- [ ] **Emoji Reactions**
  - [ ] Quick reactions (❤️👍😂)
  - [ ] Full emoji picker
  - [ ] Recently used emojis
  - [ ] Multiple reactions
  - [ ] Remove reactions

- [ ] **Message Editing**
  - [ ] Edit own messages
  - [ ] Edit mode UI
  - [ ] 15-minute time window
  - [ ] "Edited" indicator
  - [ ] Cancel editing

- [ ] **Image Sharing**
  - [ ] Photo picker
  - [ ] Image upload
  - [ ] Image display
  - [ ] Loading states
  - [ ] Multiple images

- [ ] **Voice Messages**
  - [ ] Record audio
  - [ ] Waveform animation
  - [ ] Duration tracking
  - [ ] Playback controls
  - [ ] AI transcription
  - [ ] Cancel recording

- [ ] **Message Threading**
  - [ ] Reply in thread
  - [ ] Thread view
  - [ ] Reply count badge
  - [ ] Multiple threads
  - [ ] Features work in threads

- [ ] **Integration**
  - [ ] All features work together
  - [ ] Performance acceptable
  - [ ] No crashes
  - [ ] Edge cases handled

---

## Known Issues / Limitations

Document any issues found during testing:

| Issue | Severity | Steps to Reproduce | Status |
|-------|----------|-------------------|--------|
| _Example: Emoji picker search not functional_ | Low | Open picker → type in search | Known |
| | | | |

---

## Sign-Off

**Tester:** _________________
**Date:** _________________
**Build Version:** _________________
**iOS Version:** _________________
**Device:** _________________

**Overall Result:** ☐ Pass ☐ Fail ☐ Pass with Issues

**Notes:**
_______________________________________________
_______________________________________________
_______________________________________________

---

## Next Steps

After completing Phase 4 testing:
1. Document any bugs found
2. Fix critical issues
3. Update `PHASE4_COMPLETE.md` with test results
4. Proceed to **Phase 5: Voice/Video Calling** if all tests pass

**Estimated Total Testing Time:** ~85 minutes (1.5 hours)

---

**Good luck with testing! 🚀**

