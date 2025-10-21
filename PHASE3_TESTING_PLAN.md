# Phase 3: Core Messaging - Testing Plan

## Overview

This document provides a comprehensive testing plan for Phase 3: Core Messaging. Follow these test cases systematically to ensure all features are working correctly.

**Estimated Testing Time:** 45-60 minutes

---

## Prerequisites

### Setup Requirements

- [ ] Xcode 15+ installed
- [ ] iOS Simulator or physical device (iOS 17+)
- [ ] Firebase project configured
- [ ] Firestore rules deployed
- [ ] Two test user accounts created (from Phase 2)

### Test User Accounts

You'll need at least 2 test accounts. If you don't have them, create them:

**User A (Alice):**
- Email: `alice@test.com`
- Password: `password123`
- Display Name: Alice

**User B (Bob):**
- Email: `bob@test.com`
- Password: `password123`
- Display Name: Bob

**Optional User C (Charlie):**
- Email: `charlie@test.com`
- Password: `password123`
- Display Name: Charlie

### Setup Instructions

1. **Deploy Firestore Rules:**
   ```bash
   cd firebase
   firebase deploy --only firestore:rules
   ```

2. **Build the App:**
   - Open project in Xcode
   - Press `Cmd+B` to build
   - Fix any build errors

3. **Prepare Test Environment:**
   - Launch 2 iOS simulators (iPhone 15 Pro recommended)
   - OR use 1 simulator + 1 physical device
   - Clear app data if needed

---

## Test Suite

### Section 1: Conversation Creation (15 min)

#### Test 1.1: Create Conversation from Friend List

**Steps:**
1. ✅ Launch app on Device 1
2. ✅ Login as Alice (`alice@test.com`)
3. ✅ Navigate to **Friends** tab
4. ✅ Verify Bob is in friends list
5. ✅ Tap on Bob's name
6. ✅ Observe conversation creation

**Expected Results:**
- ✅ Loading indicator shows briefly: "Opening chat..."
- ✅ Navigate to ChatView with Bob's name in navigation bar
- ✅ Empty state displays: "No messages yet" with "Say hi to Bob!"
- ✅ Message input bar is visible at bottom
- ✅ Send button is disabled (grayed out)

**Verification:**
- Check Firestore Console → conversations collection
- Should see new conversation document with:
  - participants: [alice_uid, bob_uid]
  - type: "direct"
  - createdAt: timestamp
  - lastMessage: null

---

#### Test 1.2: Conversation Appears in Messages Tab

**Steps:**
1. ✅ From ChatView, press Back button
2. ✅ Navigate to **Messages** tab
3. ✅ Check conversation list

**Expected Results:**
- ✅ Conversation with Bob appears in list
- ✅ Shows Bob's profile initial (B)
- ✅ Shows "No messages yet" as preview
- ✅ No unread badge
- ✅ No timestamp (since no messages)

---

#### Test 1.3: Open Existing Conversation

**Steps:**
1. ✅ Go back to **Friends** tab
2. ✅ Tap on Bob again
3. ✅ Observe behavior

**Expected Results:**
- ✅ Opens same conversation (doesn't create duplicate)
- ✅ No loading delay (conversation already exists)
- ✅ Still shows empty state

**Verification:**
- Check Firestore Console
- Should still only have 1 conversation document (no duplicates)

---

### Section 2: Sending Messages (20 min)

#### Test 2.1: Send First Message

**Steps:**
1. ✅ In ChatView with Bob
2. ✅ Tap in message input field
3. ✅ Type: "Hey Bob! 👋"
4. ✅ Observe send button
5. ✅ Tap send button
6. ✅ Observe message appearance

**Expected Results:**
- ✅ Keyboard appears when tapping input
- ✅ Send button turns blue as you type
- ✅ Message appears immediately in chat (optimistic update)
- ✅ Message aligned to right (blue bubble)
- ✅ Shows clock icon (sending status)
- ✅ Clock changes to single checkmark (sent status)
- ✅ Input field clears immediately
- ✅ Timestamp shows current time (e.g., "2:30 PM")
- ✅ Auto-scrolls to show new message

**Verification:**
- Check Firestore Console → conversations/[id]/messages
- Should see message document with:
  - text: "Hey Bob! 👋"
  - senderId: alice_uid
  - status: "sent"
  - timestamp: [current time]

---

#### Test 2.2: Conversation List Updates

**Steps:**
1. ✅ Press Back to return to Messages tab
2. ✅ Check conversation with Bob

**Expected Results:**
- ✅ Last message preview shows: "Hey Bob! 👋"
- ✅ Timestamp shows (e.g., "2:30 PM")
- ✅ Still no unread badge (you sent it)

---

#### Test 2.3: Receive Message Real-Time

**Setup:**
- Keep Device 1 (Alice) on ChatView with Bob

**Steps:**
1. ✅ Launch app on Device 2
2. ✅ Login as Bob (`bob@test.com`)
3. ✅ Navigate to **Messages** tab
4. ✅ Observe conversation list

**Expected Results:**
- ✅ Conversation with Alice appears
- ✅ Shows blue unread badge: "1"
- ✅ Last message preview: "Hey Bob! 👋"
- ✅ Timestamp shows (e.g., "2:30 PM")

**Steps (continued):**
5. ✅ Tap on conversation with Alice
6. ✅ Observe ChatView

**Expected Results:**
- ✅ Alice's message appears on left (gray bubble)
- ✅ Shows sender name: "Alice"
- ✅ Shows timestamp
- ✅ Message marked as read automatically
- ✅ Unread badge disappears from conversation list

**Verification on Device 1 (Alice):**
- ✅ Message status changes from single checkmark to double blue checkmark (read)
- ✅ Updates in real-time (within 1-2 seconds)

---

#### Test 2.4: Send Multiple Messages

**Steps (Device 2 - Bob):**
1. ✅ Type: "Hi Alice! How are you?"
2. ✅ Send message
3. ✅ Wait 2 seconds
4. ✅ Type: "Long time no see!"
5. ✅ Send message
6. ✅ Wait 2 seconds
7. ✅ Type: "What have you been up to?"
8. ✅ Send message

**Expected Results:**
- ✅ All messages appear on right (blue bubbles)
- ✅ Messages stack vertically
- ✅ Each has timestamp
- ✅ Status indicators update for each

**Verification on Device 1 (Alice):**
- ✅ All 3 messages appear in real-time on left (gray bubbles)
- ✅ Each shows "Bob" as sender
- ✅ Messages appear within 1-2 seconds of sending
- ✅ Auto-scrolls to show new messages
- ✅ Conversation list updates with latest message

---

#### Test 2.5: Multi-Line Messages

**Steps (Device 1 - Alice):**
1. ✅ Type a long message with line breaks:
   ```
   That's great to hear!
   
   I've been working on some projects.
   How about we catch up this weekend?
   ```
2. ✅ Send message

**Expected Results:**
- ✅ Text input expands to show all lines (up to 5 lines)
- ✅ Message sends with all line breaks preserved
- ✅ Message bubble expands to fit content
- ✅ Appears correctly on Bob's device

---

#### Test 2.6: Empty Message Handling

**Steps:**
1. ✅ Try to send empty message (just spaces)
2. ✅ Observe send button

**Expected Results:**
- ✅ Send button remains disabled/grayed
- ✅ Cannot tap send button
- ✅ No message sent

---

### Section 3: Message Features (15 min)

#### Test 3.1: Copy Message

**Steps (Device 1 - Alice):**
1. ✅ Long-press on any message
2. ✅ Select "Copy" from context menu
3. ✅ Open Notes app
4. ✅ Paste (long-press and select Paste)

**Expected Results:**
- ✅ Context menu appears with options
- ✅ Message text is copied to clipboard
- ✅ Can paste message in other apps

---

#### Test 3.2: React to Message

**Steps (Device 1 - Alice):**
1. ✅ Long-press on Bob's message: "Hi Alice! How are you?"
2. ✅ Tap "❤️ React" from context menu
3. ✅ Observe message

**Expected Results:**
- ✅ Heart emoji appears below message in small bubble
- ✅ Reaction appears immediately (optimistic update)

**Verification on Device 2 (Bob):**
- ✅ Heart reaction appears on your message within 1-2 seconds
- ✅ Shows in small bubble below message

**Steps (continued):**
4. ✅ On Device 2 (Bob), long-press same message
5. ✅ Tap "👍 React"

**Expected Results:**
- ✅ Thumbs up appears below message
- ✅ Now shows both ❤️ and 👍 emojis

**Verification on Device 1 (Alice):**
- ✅ Both reactions visible
- ✅ Updates in real-time

---

#### Test 3.3: Delete Own Message

**Steps (Device 1 - Alice):**
1. ✅ Long-press on your own message
2. ✅ Select "Delete" from context menu
3. ✅ Observe chat

**Expected Results:**
- ✅ Message disappears immediately
- ✅ Conversation last message updates if it was the last one

**Verification on Device 2 (Bob):**
- ✅ Message disappears from Bob's view within 1-2 seconds

**Steps (try deleting Bob's message):**
4. ✅ Long-press on Bob's message
5. ✅ Check context menu

**Expected Results:**
- ✅ "Delete" option NOT available (can only delete own messages)

---

### Section 4: Real-Time Updates (10 min)

#### Test 4.1: Simultaneous Messaging

**Setup:**
- Have both devices on ChatView

**Steps:**
1. ✅ On Device 1 (Alice), type and send: "Testing real-time!"
2. ✅ Immediately on Device 2 (Bob), type and send: "Me too!"
3. ✅ Both keep sending messages rapidly

**Expected Results:**
- ✅ Both users see messages appear in real-time
- ✅ Messages appear in correct order
- ✅ No message loss
- ✅ Status indicators update correctly
- ✅ Auto-scroll works on both devices

---

#### Test 4.2: Read Receipts Update

**Steps:**
1. ✅ On Device 1 (Alice), send message: "Can you see this?"
2. ✅ Observe status indicator (should be double gray checkmark - delivered)
3. ✅ On Device 2 (Bob), make sure you're viewing the ChatView
4. ✅ Observe on Device 1 (Alice)

**Expected Results:**
- ✅ Status changes from delivered (double gray) to read (double blue)
- ✅ Updates within 1-2 seconds
- ✅ Unread count clears on Bob's side

---

#### Test 4.3: Background/Foreground Behavior

**Steps:**
1. ✅ On Device 2 (Bob), press Home button (minimize app)
2. ✅ On Device 1 (Alice), send message: "Are you there?"
3. ✅ Wait 3 seconds
4. ✅ On Device 2 (Bob), open app again
5. ✅ Check Messages tab

**Expected Results:**
- ✅ Unread badge shows on conversation with Alice
- ✅ Message is visible when opening conversation
- ✅ Read receipts work when viewing message

---

### Section 5: Conversation Management (10 min)

#### Test 5.1: Search Conversations

**Setup:**
- Create conversations with multiple friends (Alice should have Bob and Charlie as friends)

**Steps:**
1. ✅ On Device 1 (Alice), go to Messages tab
2. ✅ Pull down to reveal search bar
3. ✅ Type "Bob"
4. ✅ Observe results

**Expected Results:**
- ✅ Search bar appears
- ✅ Conversation with Bob remains visible
- ✅ Other conversations are hidden
- ✅ Clear button (X) appears in search bar

**Steps (continued):**
5. ✅ Clear search
6. ✅ Type "Charlie"

**Expected Results:**
- ✅ Only conversation with Charlie shows
- ✅ Filtering is instant

---

#### Test 5.2: Unread Badge Accuracy

**Steps:**
1. ✅ On Device 1 (Alice), go to Friends tab
2. ✅ On Device 2 (Bob), send 3 messages to Alice
3. ✅ On Device 1 (Alice), check Messages tab

**Expected Results:**
- ✅ Unread badge shows "3" on Bob's conversation
- ✅ Badge is blue and clearly visible

**Steps (continued):**
4. ✅ Tap on conversation with Bob
5. ✅ Go back to Messages tab

**Expected Results:**
- ✅ Unread badge disappears (count is 0)
- ✅ Messages marked as read

---

#### Test 5.3: Delete Conversation

**Steps:**
1. ✅ On Device 1 (Alice), go to Messages tab
2. ✅ Swipe left on conversation with Charlie
3. ✅ Tap "Delete" button
4. ✅ Observe conversation list

**Expected Results:**
- ✅ Red delete button appears on swipe
- ✅ Conversation disappears from list
- ✅ Other conversations remain

**Verification:**
- Check Firestore Console
- Conversation document should be deleted
- All messages in that conversation should be deleted

**Important:**
5. ✅ On Charlie's device, check if conversation still exists
   - Conversation should still exist for Charlie (each user manages their own view)

---

#### Test 5.4: Conversation Sorting

**Steps:**
1. ✅ Send message in conversation with Bob
2. ✅ Wait 5 seconds
3. ✅ Send message in conversation with Charlie
4. ✅ Check Messages tab

**Expected Results:**
- ✅ Conversation with Charlie appears at top (most recent)
- ✅ Conversation with Bob appears below
- ✅ Sorting updates automatically

---

### Section 6: UI/UX Verification (10 min)

#### Test 6.1: Date Separators

**Steps:**
1. ✅ Open any conversation
2. ✅ Check for date separators

**Expected Results:**
- ✅ First message has "Today" separator
- ✅ Separator is gray pill-shaped label
- ✅ Centered above messages

**To test "Yesterday":**
1. ✅ In Firestore Console, manually edit a message timestamp to yesterday
2. ✅ Reload conversation in app

**Expected Results:**
- ✅ Shows "Yesterday" separator
- ✅ Shows specific date for older messages (e.g., "October 15, 2024")

---

#### Test 6.2: Message Alignment

**Steps:**
1. ✅ Open conversation
2. ✅ Verify message layout

**Expected Results:**
- ✅ Your messages: aligned right, blue bubbles
- ✅ Their messages: aligned left, gray bubbles
- ✅ Proper spacing between messages
- ✅ 60px minimum margin on opposite side

---

#### Test 6.3: Online Status Indicators

**Steps:**
1. ✅ Go to Messages tab
2. ✅ Check profile pictures in conversation list

**Expected Results:**
- ✅ Green dot for online users (if implemented)
- ✅ Profile initials clearly visible
- ✅ Circle shape is perfect

---

#### Test 6.4: Timestamps

**Steps:**
1. ✅ Send messages at different times
2. ✅ Check timestamp format

**Expected Results:**
- ✅ Shows time for today's messages (e.g., "2:30 PM")
- ✅ Shows "Yesterday" for yesterday's messages
- ✅ Shows day of week for this week (e.g., "Monday")
- ✅ Shows date for older messages (e.g., "10/15/24")

---

#### Test 6.5: Loading States

**Steps:**
1. ✅ Fresh login to app
2. ✅ Go to Messages tab
3. ✅ Observe initial load

**Expected Results:**
- ✅ Shows "Loading conversations..." if slow
- ✅ Spinner/progress indicator visible
- ✅ Conversations appear when loaded

**Steps (in ChatView):**
4. ✅ Open a conversation
5. ✅ Observe message load

**Expected Results:**
- ✅ Shows spinner if messages take time to load
- ✅ Messages appear smoothly

---

#### Test 6.6: Empty States

**Steps:**
1. ✅ Create a new test user with no friends
2. ✅ Login as new user
3. ✅ Go to Messages tab

**Expected Results:**
- ✅ Shows empty state: "No Conversations Yet"
- ✅ Message icon displayed
- ✅ "Start a conversation with your friends" text
- ✅ "New Message" button visible

**Steps (in ChatView):**
4. ✅ Send friend request and start new conversation
5. ✅ Open conversation before sending messages

**Expected Results:**
- ✅ Shows empty state: "No messages yet"
- ✅ Shows chat bubble icon
- ✅ Shows "Say hi to [Friend Name]!" text

---

#### Test 6.7: Pull to Refresh

**Steps:**
1. ✅ Go to Messages tab
2. ✅ Pull down from top of list
3. ✅ Release

**Expected Results:**
- ✅ Refresh indicator appears
- ✅ List refreshes
- ✅ Indicator disappears when done

---

### Section 7: Edge Cases (15 min)

#### Test 7.1: Very Long Messages

**Steps:**
1. ✅ Type a very long message (500+ characters)
2. ✅ Send message
3. ✅ Observe display

**Expected Results:**
- ✅ Message sends successfully
- ✅ Bubble expands to fit content
- ✅ Doesn't break layout
- ✅ Still readable on recipient's device

---

#### Test 7.2: Special Characters

**Steps:**
1. ✅ Send messages with:
   - Emojis: "Hello! 😀🎉💕"
   - Symbols: "Test #1 @ 100% & more!"
   - Unicode: "Hello مرحبا 你好"
   - Code: `const greeting = "Hello";`
2. ✅ Verify on both devices

**Expected Results:**
- ✅ All characters display correctly
- ✅ No encoding issues
- ✅ Emojis render properly
- ✅ Special characters preserved

---

#### Test 7.3: Rapid Message Sending

**Steps:**
1. ✅ Type and send 10 messages very quickly (1 per second)
2. ✅ Don't wait for send to complete

**Expected Results:**
- ✅ All messages send successfully
- ✅ Messages appear in correct order
- ✅ No duplicates
- ✅ Status indicators update correctly
- ✅ No crashes or freezing

---

#### Test 7.4: Network Interruption

**Steps:**
1. ✅ Enable Airplane Mode on Device 1
2. ✅ Try to send message
3. ✅ Observe behavior

**Expected Results:**
- ✅ Message shows as "sending" (clock icon)
- ✅ Eventually shows as "failed" (red exclamation mark)
- ✅ App doesn't crash
- ✅ Error message may appear

**Steps (continued):**
4. ✅ Disable Airplane Mode
5. ✅ Try to resend message

**Expected Results:**
- ✅ Message sends successfully
- ✅ Status updates to "sent"

---

#### Test 7.5: App Killed and Reopened

**Steps:**
1. ✅ Force quit app (swipe up in app switcher)
2. ✅ Reopen app
3. ✅ Go to Messages tab

**Expected Results:**
- ✅ Conversations still visible
- ✅ Messages preserved
- ✅ Unread counts accurate
- ✅ Real-time listeners reconnect

---

#### Test 7.6: Multiple Simultaneous Reactions

**Steps:**
1. ✅ Have 3 users react to same message with different emojis
2. ✅ All react within 1 second

**Expected Results:**
- ✅ All reactions appear
- ✅ No reactions lost
- ✅ Each reaction counted separately
- ✅ Display updates correctly

---

#### Test 7.7: Conversation with No Last Message

**Steps:**
1. ✅ Create new conversation but don't send any messages
2. ✅ Check Messages tab

**Expected Results:**
- ✅ Conversation appears in list
- ✅ Shows "No messages yet" as preview
- ✅ No timestamp shown
- ✅ No crashes

---

### Section 8: Performance Testing (10 min)

#### Test 8.1: Large Message History

**Steps:**
1. ✅ Send 50+ messages in a conversation
2. ✅ Close and reopen conversation
3. ✅ Observe load time

**Expected Results:**
- ✅ Messages load within 2-3 seconds
- ✅ Smooth scrolling
- ✅ Auto-scrolls to bottom
- ✅ No lag when scrolling up

---

#### Test 8.2: Multiple Conversations

**Steps:**
1. ✅ Create conversations with 5+ friends
2. ✅ Send messages in each
3. ✅ Navigate to Messages tab

**Expected Results:**
- ✅ All conversations load quickly
- ✅ Smooth scrolling through list
- ✅ No lag or stuttering
- ✅ Unread counts accurate

---

#### Test 8.3: Memory Usage

**Steps:**
1. ✅ Open Xcode → Debug → Memory Report
2. ✅ Use app normally for 5 minutes
3. ✅ Send messages, navigate between views
4. ✅ Monitor memory usage

**Expected Results:**
- ✅ Memory usage stays reasonable (< 200MB)
- ✅ No memory leaks
- ✅ Memory doesn't grow continuously

---

### Section 9: Data Verification (10 min)

#### Test 9.1: Firestore Data Structure

**Steps:**
1. ✅ Open Firebase Console
2. ✅ Navigate to Firestore Database
3. ✅ Check `conversations` collection

**Verify Structure:**
```javascript
conversations/[conversationId]/
  ✅ id: string
  ✅ participants: array [userId1, userId2]
  ✅ participantDetails: map {
       userId1: {name, email, photoURL, status},
       userId2: {name, email, photoURL, status}
     }
  ✅ type: "direct"
  ✅ lastMessage: {
       text: string,
       senderId: string,
       senderName: string,
       timestamp: timestamp,
       type: "text"
     }
  ✅ lastMessageTime: timestamp
  ✅ unreadCount: map {
       userId1: number,
       userId2: number
     }
  ✅ createdAt: timestamp
  ✅ updatedAt: timestamp
```

---

#### Test 9.2: Message Data Structure

**Steps:**
1. ✅ In Firestore Console
2. ✅ Navigate to `conversations/[id]/messages`
3. ✅ Check message documents

**Verify Structure:**
```javascript
messages/[messageId]/
  ✅ id: string
  ✅ conversationId: string
  ✅ senderId: string
  ✅ senderName: string
  ✅ text: string
  ✅ timestamp: timestamp
  ✅ status: "sent" | "delivered" | "read"
  ✅ type: "text"
  ✅ reactions: map (optional)
  ✅ readBy: array (optional)
  ✅ deliveredTo: array (optional)
```

---

#### Test 9.3: Security Rules

**Steps:**
1. ✅ Try to read another user's messages without being a participant
2. ✅ Try to send message as someone else
3. ✅ Try to delete someone else's message

**Expected Results:**
- ✅ All unauthorized actions should fail
- ✅ Firestore should deny with permission errors
- ✅ App handles errors gracefully

---

### Section 10: Regression Testing (10 min)

Verify previous features still work:

#### Test 10.1: Authentication
- [ ] Can still login
- [ ] Can still logout
- [ ] Session persists

#### Test 10.2: Friends System
- [ ] Can view friends list
- [ ] Can send friend requests
- [ ] Can accept/decline requests
- [ ] Can remove friends
- [ ] Friend requests still work

#### Test 10.3: Navigation
- [ ] All tabs accessible
- [ ] Navigation between tabs smooth
- [ ] Back button works correctly
- [ ] Deep linking works

---

## Test Results Summary

### Total Tests: 50+

**Conversation Management:**
- [ ] Create conversation: ____
- [ ] View conversations: ____
- [ ] Search conversations: ____
- [ ] Delete conversations: ____

**Messaging:**
- [ ] Send messages: ____
- [ ] Receive messages: ____
- [ ] Read receipts: ____
- [ ] Message status: ____

**Message Features:**
- [ ] Copy message: ____
- [ ] React to message: ____
- [ ] Delete message: ____

**Real-Time:**
- [ ] Instant updates: ____
- [ ] Simultaneous messaging: ____
- [ ] Status updates: ____

**UI/UX:**
- [ ] Date separators: ____
- [ ] Message alignment: ____
- [ ] Loading states: ____
- [ ] Empty states: ____

**Edge Cases:**
- [ ] Long messages: ____
- [ ] Special characters: ____
- [ ] Network issues: ____
- [ ] App lifecycle: ____

**Performance:**
- [ ] Large history: ____
- [ ] Multiple conversations: ____
- [ ] Memory usage: ____

**Data Integrity:**
- [ ] Firestore structure: ____
- [ ] Message data: ____
- [ ] Security rules: ____

**Regression:**
- [ ] Auth still works: ____
- [ ] Friends still work: ____
- [ ] Navigation still works: ____

---

## Issues Found

Use this section to document any issues discovered:

### Critical Issues
| # | Issue | Steps to Reproduce | Expected | Actual | Status |
|---|-------|-------------------|----------|--------|--------|
| 1 |       |                   |          |        |        |

### Minor Issues
| # | Issue | Steps to Reproduce | Expected | Actual | Status |
|---|-------|-------------------|----------|--------|--------|
| 1 |       |                   |          |        |        |

### UI/UX Issues
| # | Issue | Steps to Reproduce | Expected | Actual | Status |
|---|-------|-------------------|----------|--------|--------|
| 1 |       |                   |          |        |        |

---

## Sign-Off

**Tester Name:** ___________________  
**Date:** ___________________  
**Build Version:** ___________________  
**Test Duration:** ___________________

**Overall Status:**
- [ ] ✅ All tests passed - Ready for Phase 4
- [ ] ⚠️ Minor issues found - Can proceed with fixes
- [ ] ❌ Critical issues found - Need immediate attention

**Notes:**
_______________________________________________________
_______________________________________________________
_______________________________________________________

---

## Quick Test Script (5-Minute Smoke Test)

If you need a quick verification:

1. **Login** as User A
2. **Go to Friends tab**, tap a friend
3. **Send a message** "Test"
4. **Login** as User B on another device
5. **Check Messages tab** - should see unread badge
6. **Open conversation** - should see User A's message
7. **Send reply** "Reply test"
8. **Verify** User A receives reply in real-time
9. **Long-press** message and react with ❤️
10. **Verify** reaction appears on both devices

**If all 10 steps work:** Basic functionality is operational ✅

---

## Automated Testing Notes

For future automation:

**Unit Tests to Write:**
- Message model creation
- Conversation model helpers
- Date formatting utilities
- Message status updates

**Integration Tests to Write:**
- Send message flow
- Receive message flow
- Real-time listener setup
- Read receipt updates

**UI Tests to Write:**
- Navigate to chat
- Send message
- Verify message appears
- Check read receipts

---

**Happy Testing! 🧪**

Remember: Thorough testing now saves debugging time later!

