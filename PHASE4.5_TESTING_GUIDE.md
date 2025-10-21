# Phase 4.5: Group Chat Testing Guide

**Quick testing guide for group chat functionality**

---

## 🚀 Quick Start

### Deploy Firestore Rules First
```bash
cd firebase
firebase deploy --only firestore:rules
```

---

## 📱 Testing Checklist

### 1. Create a Group Chat (5 min)

**Steps:**
1. Open app, go to Messages tab
2. Tap "+" (New Message)
3. Tap "Create Group" at the top
4. Select at least 2 friends ✅
5. Enter group name (optional): "Test Group"
6. Tap "Create"

**Expected:**
- ✅ Group chat opens automatically
- ✅ System message: "Your Name created the group"
- ✅ Group name shows in navigation
- ✅ Member count shows (e.g., "3 members")
- ✅ Info button (ⓘ) appears in toolbar

**Verify:**
- Group appears in Messages list with group icon (👥)
- Last message shows your system message

---

### 2. Send Messages in Group (3 min)

**Steps:**
1. Send a text message
2. Send an image
3. Send a voice message
4. Add emoji reaction to a message

**Expected:**
- ✅ ALL messages show sender names (yours and others)
- ✅ Your messages: blue bubble, your name on top
- ✅ Others: gray bubble, their name on top
- ✅ Messages delivered to all members in real-time

**Test with Second Device:**
- Have friend open the group
- Both send messages
- Verify sender names appear correctly

---

### 3. Group Info Screen (5 min)

**Steps:**
1. In group chat, tap group name or ⓘ button
2. Verify you see:
   - Group icon
   - Group name
   - Member count
   - "Edit Group Info" button (you're admin)
   - List of all members
   - Your name has "Admin" badge
   - "Add Members" button
   - "Leave Group" button (red)

**Expected:**
- ✅ All members listed with avatars
- ✅ Admin badge next to your name
- ✅ Buttons accessible and styled correctly

---

### 4. Edit Group Name (2 min)

**Steps:**
1. In Group Info, tap "Edit Group Info"
2. Change name to "Updated Group Name"
3. Tap "Save"

**Expected:**
- ✅ System message: "Your Name changed the group name to 'Updated Group Name'"
- ✅ Navigation title updates
- ✅ All members see new name
- ✅ Messages list shows new name

---

### 5. Add Members (3 min)

**Steps:**
1. In Group Info, tap "Add Members"
2. Select 1-2 more friends
3. Tap "Add"

**Expected:**
- ✅ System message for each: "Your Name added Friend Name to the group"
- ✅ Member list updates
- ✅ Member count increases
- ✅ New members can see all previous messages
- ✅ New members can send messages

**Non-Admin Test:**
- Have friend open Group Info
- They should NOT see "Add Members" button

---

### 6. Remove Member (2 min)

**Admin Test:**
1. In Group Info, find a member (not yourself)
2. Tap the red (−) button next to their name
3. Confirm removal

**Expected:**
- ✅ System message: "Your Name removed Member Name from the group"
- ✅ Member disappears from list
- ✅ Member count decreases
- ✅ Removed member loses access to group

**Removed Member's View:**
- Group disappears from their Messages list
- Can't access group anymore

---

### 7. Leave Group (2 min)

**Create Test Group First** (you'll lose access):
1. Create another test group
2. Open Group Info
3. Tap "Leave Group" (red button)
4. Confirm

**Expected:**
- ✅ System message: "Your Name left the group"
- ✅ Group disappears from your Messages list
- ✅ Other members see system message
- ✅ Group continues for other members

**Last Member Test:**
- Create group with only you and one friend
- Both leave
- Verify conversation is deleted

---

## 🧪 Advanced Testing

### System Messages Display

Create a group and perform all actions to see system messages:
1. ✅ "Alice created the group"
2. ✅ "Alice added Bob to the group"
3. ✅ "Alice changed the group name to 'Team'"
4. ✅ "Charlie left the group"
5. ✅ "Alice removed Dave from the group"

**Verify:**
- All system messages centered
- Gray background
- No sender name
- No reactions/edit/delete options
- Proper formatting

---

### UI/UX Checks

**Conversation List:**
- ✅ Group icon (👥) vs single letter for direct chats
- ✅ Last message shows sender name: "Bob: Hello everyone"
- ✅ No online indicator for groups

**Chat View:**
- ✅ Group name in title
- ✅ Member count subtitle when tapped
- ✅ Info button visible
- ✅ Sender names on all messages
- ✅ System messages styled differently

**Create Group View:**
- ✅ Selected friends show as removable chips
- ✅ Counter shows selected count
- ✅ Create button disabled until 2+ selected
- ✅ Loading state during creation

**Group Info:**
- ✅ Clean layout
- ✅ Clear admin badges
- ✅ Buttons properly disabled for non-admins
- ✅ Leave button always visible (red)

---

### Edge Cases

**Large Groups:**
1. Create group with 5+ members
2. Verify scrolling in member list
3. Send messages - check performance
4. Add more members (test with 10+ total)

**Long Names:**
1. Create group with very long name (50+ chars)
2. Verify truncation in:
   - Navigation title
   - Messages list
   - Group Info

**Rapid Actions:**
1. Quickly add multiple members
2. Immediately remove some
3. Send messages during changes
4. Verify system messages in order

**Network Issues:**
1. Turn off wifi
2. Try to create group (should fail gracefully)
3. Turn wifi back on
4. Verify retry works

**Multiple Admins Scenario:**
Currently only creator is admin. Future feature:
- Create group as User A
- Have User A add members
- Only User A can edit/add/remove
- Other members can only send messages and leave

---

## ✅ Quick Verification Checklist

Use this for fast regression testing:

- [ ] Create group with 2+ friends
- [ ] See system message "created the group"
- [ ] Send text message - sender name shows
- [ ] Tap group title - Group Info opens
- [ ] Edit group name - system message appears
- [ ] Add member - system message appears
- [ ] Leave group - disappears from list
- [ ] Group icon shows in Messages list
- [ ] Last message shows sender name prefix
- [ ] No linter errors in Xcode

---

## 🐛 Common Issues & Fixes

### "Create" button disabled
- Must select at least 2 friends
- Check if you have enough friends added

### Can't see "Add Members" button
- Must be admin
- Create your own group to test

### System messages not appearing
- Check Firestore rules deployed
- Verify senderId == "system"
- Check MessageRow handles .system type

### Group name not updating
- Verify admin check in updateGroupName
- Check Firestore rules allow admin updates
- Refresh Group Info view

### Members can't see messages
- Verify participants array includes them
- Check Firestore rules
- Try force-refresh conversation list

---

## 📊 Success Metrics

After testing, you should have:
- ✅ Created at least 2 test groups
- ✅ Sent 10+ messages in groups
- ✅ Seen all 5 types of system messages
- ✅ Added and removed members
- ✅ Left at least one group
- ✅ Edited group name
- ✅ Verified non-admin restrictions
- ✅ No crashes or errors

---

## 🚀 Ready for Production?

Before marking Phase 4.5 complete:
- [ ] All checklist items pass
- [ ] Tested with 2+ real users
- [ ] Edge cases handled
- [ ] No console errors
- [ ] UI looks polished
- [ ] System messages appear correctly
- [ ] Admin controls work
- [ ] Leave/remove functions properly

---

**Happy Testing!** 🎉

Report any bugs to continue refinement.

