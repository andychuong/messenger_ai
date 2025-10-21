# Phase 3: Visual Testing Guide

This guide shows what you should see at each step. Use it to verify UI is correct.

---

## 1. Messages Tab (Empty State)

**When:** New user with no conversations

**Should See:**
```
┌──────────────────────────────────┐
│  Messages                    [+] │
├──────────────────────────────────┤
│                                  │
│                                  │
│         📨  (large icon)         │
│                                  │
│     No Conversations Yet         │
│                                  │
│  Start a conversation with       │
│        your friends              │
│                                  │
│    [📝 New Message button]       │
│                                  │
│                                  │
└──────────────────────────────────┘
```

**Check:**
- [ ] Large message icon centered
- [ ] Title text "No Conversations Yet"
- [ ] Gray secondary text
- [ ] Blue "New Message" button
- [ ] Clean, empty state

---

## 2. Messages Tab (With Conversations)

**When:** User has active conversations

**Should See:**
```
┌──────────────────────────────────┐
│  Messages                    [+] │
│  Search...                   [x] │
├──────────────────────────────────┤
│  [B]  Bob                 2:30 PM│
│       Hey! How are you?      (1) │
├──────────────────────────────────┤
│  [C]  Charlie            Yesterday│
│       See you tomorrow!          │
├──────────────────────────────────┤
│  [A]  Alice               Mon     │
│       Thanks!                    │
└──────────────────────────────────┘
```

**Check:**
- [ ] Profile initials in colored circles
- [ ] Green dot on online users
- [ ] Friend name in bold
- [ ] Last message preview (2 lines max)
- [ ] Timestamp aligned right
- [ ] Blue unread badge (if unread)
- [ ] Most recent conversation at top

---

## 3. Conversation Row Details

**Anatomy of a conversation row:**

```
┌────────────────────────────────────────┐
│                                        │
│  [B] ●  Bob Smith          2:30 PM (1) │
│         Hey! How are you doing?        │
│         Let's catch up soon            │
│                                        │
└────────────────────────────────────────┘
   │ │  │                    │        │
   │ │  │                    │        └─ Unread badge (blue)
   │ │  │                    └────────── Timestamp
   │ │  └──────────────────────────────── Friend name
   │ └──────────────────────────────────── Online indicator (green)
   └────────────────────────────────────── Profile initial circle
```

**Check:**
- [ ] Circle is perfectly round
- [ ] Initial is centered, white text
- [ ] Online dot overlaps bottom-right
- [ ] Name is headline font
- [ ] Preview is 2 lines max
- [ ] Badge is pill-shaped

---

## 4. Empty Chat View

**When:** Opening new conversation with no messages

**Should See:**
```
┌──────────────────────────────────┐
│  ← Bob              ☎️  📹       │
├──────────────────────────────────┤
│                                  │
│                                  │
│         💬💬  (icon)             │
│                                  │
│       No messages yet            │
│                                  │
│      Say hi to Bob!              │
│                                  │
│                                  │
├──────────────────────────────────┤
│  [Message input bar]         [↑] │
└──────────────────────────────────┘
```

**Check:**
- [ ] Back button works
- [ ] Friend name in nav bar
- [ ] Call buttons present (disabled)
- [ ] Empty state icon centered
- [ ] Encouraging message
- [ ] Input bar at bottom

---

## 5. Chat View (With Messages)

**When:** Active conversation

**Should See:**
```
┌──────────────────────────────────┐
│  ← Bob              ☎️  📹       │
├──────────────────────────────────┤
│          ┌── Today ──┐           │
│                                  │
│  Alice                           │
│  ┌─────────────────┐             │
│  │ Hey Bob! 👋     │ 2:15 PM     │
│  └─────────────────┘             │
│                                  │
│                      Bob         │
│           ┌─────────────────┐    │
│  2:20 PM  │ Hi Alice!       │    │
│           │ How are you?    │ ✓✓ │
│           └─────────────────┘    │
│               ❤️                 │
│                                  │
│  Alice                           │
│  ┌─────────────────┐             │
│  │ I'm great!      │ 2:25 PM     │
│  │ Thanks! 😊      │             │
│  └─────────────────┘             │
│                                  │
├──────────────────────────────────┤
│  Message...                  [↑] │
└──────────────────────────────────┘
```

**Check:**
- [ ] Date separator centered, gray pill
- [ ] Received messages (left, gray)
- [ ] Sent messages (right, blue)
- [ ] Sender name above message
- [ ] Timestamps beside messages
- [ ] Status indicators on sent messages
- [ ] Reactions below messages
- [ ] Messages stack with proper spacing

---

## 6. Message Bubble Styles

**Sent Message (You):**
```
                     ┌─────────────────┐
                     │ Your message    │ ✓✓
                     │ goes here       │
            2:30 PM  └─────────────────┘
```
- Blue background (#007AFF)
- White text
- Right-aligned
- Rounded corners
- Timestamp + status on left
- Status: ✓✓ blue = read

**Received Message (Them):**
```
┌─────────────────┐
│ Their message   │
│ goes here       │  2:30 PM
└─────────────────┘
```
- Gray background (#E9ECEF)
- Black text
- Left-aligned
- Rounded corners
- Timestamp on right
- No status indicator

---

## 7. Status Indicators

**Message Status Progression:**

```
1. Sending:   🕐  (clock icon, gray)
2. Sent:      ✓   (single checkmark, gray)
3. Delivered: ✓✓  (double checkmark, gray)
4. Read:      ✓✓  (double checkmark, blue)
5. Failed:    ❗  (exclamation, red)
```

**Where They Appear:**
```
                 ┌─────────────┐
        2:30 PM  │ Message     │ ✓✓
                 └─────────────┘
                 ↑             ↑
             timestamp      status
```

---

## 8. Context Menu

**When:** Long-press on message

**Should See:**
```
┌────────────────────────────┐
│  ❤️ React                  │
│  👍 React                  │
│  😂 React                  │
├────────────────────────────┤
│  📋 Copy                   │
├────────────────────────────┤
│  🗑️ Delete (own msgs only) │
└────────────────────────────┘
```

**Check:**
- [ ] Menu appears on long-press
- [ ] All options visible
- [ ] Icons next to labels
- [ ] Delete only on own messages
- [ ] Tapping option executes action

---

## 9. Reactions Display

**Single Reaction:**
```
┌─────────────────┐
│ Message text    │
└─────────────────┘
    ❤️
```

**Multiple Reactions:**
```
┌─────────────────┐
│ Message text    │
└─────────────────┘
  ❤️2  👍  😂3
```

**Check:**
- [ ] Reactions below message
- [ ] Small gray bubbles
- [ ] Count shown if >1 user
- [ ] Multiple reactions side-by-side
- [ ] Tappable to react

---

## 10. Message Input Bar

**Empty State:**
```
┌──────────────────────────────────┐
│  Message...                  [↑] │
└──────────────────────────────────┘
     │                           │
   Input field              Send button
                           (gray, disabled)
```

**With Text:**
```
┌──────────────────────────────────┐
│  Hello! How are...           [↑] │
└──────────────────────────────────┘
     │                           │
   Input field              Send button
                           (blue, enabled)
```

**Multi-line:**
```
┌──────────────────────────────────┐
│  This is a longer message    [↑] │
│  that spans multiple             │
│  lines automatically             │
└──────────────────────────────────┘
```

**Check:**
- [ ] Input expands for multi-line (up to 5)
- [ ] Send button gray when empty
- [ ] Send button blue when has text
- [ ] Rounded corners on input
- [ ] Gray background on input
- [ ] Large circular send button

---

## 11. Search Bar

**Revealed by Pull-Down:**
```
┌──────────────────────────────────┐
│  Messages                    [+] │
│  🔍 Search...                [x] │
├──────────────────────────────────┤
│  (conversations list)            │
```

**Active Search:**
```
┌──────────────────────────────────┐
│  Messages                    [+] │
│  🔍 Bob                      [x] │
├──────────────────────────────────┤
│  [B]  Bob                 2:30 PM│
│       Hey! How are you?      (1) │
└──────────────────────────────────┘
```

**Check:**
- [ ] Search icon on left
- [ ] Gray background
- [ ] X button appears when typing
- [ ] Results filter instantly
- [ ] X clears search

---

## 12. Swipe Actions

**Swipe Left on Conversation:**
```
┌──────────────────────────────────┐
│  [B]  Bob            [🗑️ Delete] │
└──────────────────────────────────┘
           ←─────
       (swipe gesture)
```

**Check:**
- [ ] Red delete button appears
- [ ] Button follows swipe
- [ ] Tapping button deletes
- [ ] Smooth animation

---

## 13. Unread Badge

**On Conversation:**
```
┌──────────────────────────────────┐
│  [B]  Bob                 2:30 PM│
│       Hey! How are you?      (3) │
└──────────────────────────────────┘
                                 │
                          Blue badge with count
```

**On Tab Bar:**
```
┌──────────────────────────────────┐
│  📱   👥   ✨   👤               │
│  Msgs  Friends  AI  Profile      │
│   (2)                            │
└──────────────────────────────────┘
```

**Check:**
- [ ] Blue background
- [ ] White number
- [ ] Pill shape (rounded)
- [ ] Centered on right side
- [ ] Updates in real-time

---

## 14. Loading States

**Messages Tab Loading:**
```
┌──────────────────────────────────┐
│  Messages                    [+] │
├──────────────────────────────────┤
│                                  │
│        ⏳ Loading...             │
│          (spinner)               │
│                                  │
└──────────────────────────────────┘
```

**Chat Loading:**
```
┌──────────────────────────────────┐
│  ← Bob              ☎️  📹       │
├──────────────────────────────────┤
│                                  │
│          ⏳                      │
│          (spinner)               │
│                                  │
└──────────────────────────────────┘
```

**Pull to Refresh:**
```
┌──────────────────────────────────┐
│         ⏳ Refreshing...         │
│  Messages                    [+] │
├──────────────────────────────────┤
```

---

## 15. Date Separators

**Today:**
```
            ┌── Today ──┐
```

**Yesterday:**
```
           ┌── Yesterday ──┐
```

**Specific Date:**
```
        ┌── October 21, 2024 ──┐
```

**Check:**
- [ ] Gray text
- [ ] Centered
- [ ] Pill-shaped background
- [ ] Appears above first message of day
- [ ] Proper spacing

---

## Color Reference

**Primary Colors:**
- Blue (Sent messages): `#007AFF`
- Gray (Received messages): `#E9ECEF`
- Green (Online status): `#34C759`
- Red (Delete/Error): `#FF3B30`

**Text Colors:**
- Primary text: Black or `#000000`
- Secondary text: Gray `#8E8E93`
- White text: `#FFFFFF`

**Background Colors:**
- System background: White or Black (dark mode)
- Input background: `#F2F2F7`

---

## Spacing & Sizing

**Message Bubbles:**
- Padding: 16px horizontal, 10px vertical
- Corner radius: 20px
- Max width: 70% of screen
- Min margin from opposite edge: 60px

**Profile Circles:**
- Size: 56px (conversation list), 50px (friends list)
- Online indicator: 16px circle with 2px white border

**Typography:**
- Message text: Body (17pt)
- Timestamps: Caption2 (11pt)
- Names: Headline (17pt bold)
- Unread count: Caption (12pt bold)

---

## Verification Checklist

Use this when reviewing UI:

**Layout:**
- [ ] No text cutoff
- [ ] No overlapping elements
- [ ] Proper alignment
- [ ] Consistent spacing

**Colors:**
- [ ] Matches design system
- [ ] Good contrast (readable)
- [ ] Consistent throughout

**Typography:**
- [ ] Correct font sizes
- [ ] Proper font weights
- [ ] Line height appropriate
- [ ] No truncation issues

**Interactions:**
- [ ] Tap targets at least 44x44pt
- [ ] Visual feedback on tap
- [ ] Smooth animations
- [ ] No lag or stuttering

**Responsive:**
- [ ] Works on iPhone SE (small screen)
- [ ] Works on iPhone 15 Pro Max (large screen)
- [ ] Works in landscape
- [ ] Adapts to keyboard

---

## Screenshot Checklist

Take screenshots for documentation:

1. [ ] Empty Messages tab
2. [ ] Messages tab with conversations
3. [ ] Conversation detail with unread badge
4. [ ] Empty chat view
5. [ ] Chat with messages
6. [ ] Sent message with status
7. [ ] Received message
8. [ ] Message with reactions
9. [ ] Context menu
10. [ ] Search in action
11. [ ] Swipe to delete
12. [ ] Date separators
13. [ ] Loading state
14. [ ] Multi-line input

---

## Dark Mode Check

Test all screens in dark mode:

- [ ] Messages tab readable
- [ ] Chat bubbles contrast well
- [ ] Text colors adjusted
- [ ] Backgrounds appropriate
- [ ] Status indicators visible

---

## Accessibility Check

- [ ] VoiceOver reads all elements
- [ ] Tap targets large enough
- [ ] Color contrast sufficient
- [ ] Dynamic type scales correctly
- [ ] Reduce motion respected

---

**Use this guide to ensure your UI matches the design!** 🎨

Print and mark checkboxes as you verify each element.

