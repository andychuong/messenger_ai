# Phase 3: Quick Test Checklist ✅

A condensed checklist for rapid testing. Check off items as you test.

---

## Prerequisites Setup

- [ ] Firebase rules deployed: `firebase deploy --only firestore:rules`
- [ ] App builds without errors (Cmd+B)
- [ ] 2 test accounts ready (Alice & Bob)
- [ ] 2 devices/simulators available
- [ ] Users are friends with each other

---

## Core Functionality (Must Pass)

### Conversation Creation
- [ ] Tap friend → opens chat
- [ ] Shows empty state on first open
- [ ] Conversation appears in Messages tab
- [ ] No duplicate conversations created

### Send Messages
- [ ] Type message → send button enables
- [ ] Tap send → message appears (blue bubble, right side)
- [ ] Shows clock → then checkmark (status update)
- [ ] Input field clears after send
- [ ] Auto-scrolls to bottom

### Receive Messages
- [ ] Second device receives message in real-time
- [ ] Message appears on left (gray bubble)
- [ ] Shows sender name
- [ ] Shows timestamp
- [ ] Unread badge appears on conversation

### Read Receipts
- [ ] Unread badge shows count
- [ ] Opening conversation clears badge
- [ ] Single checkmark = sent
- [ ] Double gray checkmark = delivered
- [ ] Double blue checkmark = read
- [ ] Status updates in real-time

### Message Features
- [ ] Long-press message → context menu appears
- [ ] Copy message → text copies to clipboard
- [ ] React with ❤️ → emoji appears below message
- [ ] Delete own message → message disappears
- [ ] Cannot delete others' messages

### Conversation List
- [ ] All conversations visible
- [ ] Sorted by most recent
- [ ] Shows last message preview
- [ ] Shows timestamp
- [ ] Shows unread badges
- [ ] Shows profile initials
- [ ] Search filters conversations
- [ ] Swipe left → delete works

### Real-Time Updates
- [ ] New messages appear instantly (<2 seconds)
- [ ] Status changes update live
- [ ] Reactions appear in real-time
- [ ] Conversation list updates automatically

---

## UI/UX (Important)

### Chat Interface
- [ ] Sent messages: blue, right-aligned
- [ ] Received messages: gray, left-aligned
- [ ] Date separator shows ("Today")
- [ ] Timestamps on all messages
- [ ] Input bar at bottom
- [ ] Send button disabled when empty
- [ ] Multi-line input works (up to 5 lines)

### Navigation
- [ ] Back button works
- [ ] Navigate from Friends → Chat
- [ ] Navigate from Messages → Chat
- [ ] Tab switching smooth
- [ ] No navigation bugs

### Loading States
- [ ] Shows spinner while loading conversations
- [ ] Shows spinner while loading messages
- [ ] Pull to refresh works
- [ ] Loading indicators clear when done

### Empty States
- [ ] Empty Messages tab shows helpful message
- [ ] Empty chat shows "Say hi to [Name]!"
- [ ] Empty states have appropriate icons

---

## Edge Cases (Should Handle)

- [ ] Very long message (500+ chars) displays correctly
- [ ] Messages with emojis display correctly
- [ ] Messages with special chars (@ # $ %) work
- [ ] Rapid sending (10 messages quickly) works
- [ ] Network off → shows sending/failed status
- [ ] App killed → data persists on reopen
- [ ] Multiple reactions on one message work

---

## Data Verification (Firestore Console)

### Conversations Collection
- [ ] Document exists with correct structure
- [ ] participants array has both user IDs
- [ ] participantDetails map has user info
- [ ] type = "direct"
- [ ] lastMessage populated after first message
- [ ] unreadCount map updates correctly
- [ ] timestamps are valid

### Messages Subcollection
- [ ] Messages saved under correct conversation
- [ ] text field contains message content
- [ ] senderId matches sender
- [ ] status updates (sent → delivered → read)
- [ ] timestamp is accurate
- [ ] reactions map updates when reacting

---

## Performance Check

- [ ] Messages load within 2 seconds
- [ ] Smooth scrolling in chat
- [ ] Smooth scrolling in conversation list
- [ ] No lag when typing
- [ ] No freezing when sending messages
- [ ] Memory stays reasonable (<200MB)
- [ ] No visible leaks over 5 minutes

---

## Regression (Previous Phases)

- [ ] Can login
- [ ] Can logout
- [ ] Friends list still works
- [ ] Can send friend requests
- [ ] Can accept/decline requests
- [ ] All tabs accessible
- [ ] Profile tab works

---

## Critical Issues Found

**Document any showstoppers here:**

1. _____________________________________________
2. _____________________________________________
3. _____________________________________________

---

## Test Status

**Date:** _______________  
**Tester:** _______________  
**Duration:** _______________

**Result:**
- [ ] ✅ ALL TESTS PASSED - Ready for Phase 4
- [ ] ⚠️ MINOR ISSUES - Can proceed with notes
- [ ] ❌ CRITICAL ISSUES - Must fix before continuing

**Pass Rate:** _____ / _____ tests passed

---

## 5-Minute Smoke Test

Quick verification script:

1. [ ] Login as Alice
2. [ ] Tap Bob in Friends tab
3. [ ] Send "Test message"
4. [ ] Login as Bob on device 2
5. [ ] See unread badge on Messages tab
6. [ ] Open conversation with Alice
7. [ ] See Alice's message
8. [ ] Send reply "Got it!"
9. [ ] Verify Alice receives it in real-time
10. [ ] React with ❤️ to message

**All 10 passed?** → Basic functionality working ✅

---

## Notes

______________________________________________
______________________________________________
______________________________________________
______________________________________________

---

**Print this checklist and check off items as you test!** 📋

