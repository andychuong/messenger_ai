# Phase 4.5: Group Chat Implementation Plan

## 📋 Overview

**Duration:** 1 day (Days 10.5-11.5)  
**Prerequisites:** Phase 4 (Rich Messaging Features) complete  
**Next Phase:** Phase 5 (Voice/Video Calling)

Group chat functionality enables multi-person conversations with full member management, group settings, and admin controls.

---

## ✅ What Was Added to APP_PLAN.md

### **Phase 4.5 Structure:**

#### 4.5.1 Group Chat Data & Services
**Backend logic for group management**
- Create group conversations with multiple members
- Add/remove members dynamically
- Leave group functionality
- Update group name and photo
- Fetch group member list
- Multi-participant message delivery
- Group-aware read receipts (show count instead of names)
- System messages (member joined/left, name changed)

#### 4.5.2 Create Group UI
**Views for creating new groups**
- Create Group button in NewMessageView
- Multi-select friend picker
- Selected members display (chips)
- Optional group name input
- Optional group photo picker
- Validation (minimum 2 members)
- Loading states

#### 4.5.3 Group Info & Management
**Views for managing existing groups**
- Group info view with all members
- Edit group (name, photo)
- Add members to existing group
- Leave group option
- Admin controls
- Future: Media/Links/Docs tabs

#### 4.5.4 Update Chat Interface for Groups
**Adapt existing UI for groups**
- Show group name in title
- Show member count ("10 members")
- Tap title to open group info
- Show sender names on ALL messages
- Group-specific message styling
- Read receipts show count ("Read by 5")
- Last message preview shows sender name

#### 4.5.5 Group-Specific Features
**Special group functionality**
- System messages:
  - "Alice added Bob to the group"
  - "Charlie left the group"
  - "Alice changed the group name"
- Group notifications via Cloud Functions
- Notification format: "Alice in Study Group: Hey everyone!"
- Group roles (Creator = Admin)
- Admin permissions (add/remove, edit info)

#### 4.5.6 Firestore Rules for Groups
**Security for group conversations**
- Only members can read group messages
- Only members can send messages
- Only admins can modify group settings
- Anyone can leave a group

---

## 🏗️ Technical Implementation

### **Services to Update:**

```swift
// ConversationService.swift
func createGroupConversation(memberIds: [String], groupName: String?) async throws -> Conversation
func addMembersToGroup(conversationId: String, userIds: [String]) async throws
func removeMemberFromGroup(conversationId: String, userId: String) async throws
func leaveGroup(conversationId: String) async throws
func updateGroupName(conversationId: String, name: String) async throws
func updateGroupPhoto(conversationId: String, imageURL: String) async throws
func fetchGroupMembers(conversationId: String) async throws -> [User]

// MessageService.swift
// Update to handle multi-participant delivery
// Group-aware read receipts
// System message creation
```

### **New Views:**

```
Views/Conversations/Groups/
├── CreateGroupView.swift
├── GroupMemberSelectionView.swift
├── GroupInfoView.swift
├── EditGroupView.swift
└── AddGroupMembersView.swift
```

### **Updated Views:**

```
- ChatView.swift (group title, member count)
- ConversationListView.swift (group avatars, sender names)
- MessageRow.swift (sender names, read receipt counts)
- NewMessageView.swift (add "Create Group" button)
```

---

## 📊 Data Model

Already supported in `Conversation` model:

```swift
struct Conversation {
    var participants: [String]  // ✅ Multiple users
    var participantDetails: [String: ParticipantDetail]  // ✅ All members
    var type: ConversationType  // ✅ .direct or .group
    var groupName: String?  // To add
    var groupPhotoURL: String?  // To add
    var admins: [String]?  // To add (optional for MVP)
    var createdBy: String?  // To add
}
```

---

## 🎨 User Experience

### **Creating a Group:**
```
1. User taps "New Message"
2. Taps "Create Group"
3. Selects multiple friends (checkbox list)
4. Enters group name (optional)
5. Adds group photo (optional)
6. Taps "Create"
7. Group created, opens to chat
```

### **Group Chat:**
```
┌─────────────────────────────────────┐
│ ← Study Group        👥 [i]         │
│   5 members                         │
├─────────────────────────────────────┤
│ Alice                               │
│ Hey everyone! 📚                    │
│ ❤️ 3  👍 2         2:30 PM          │
├─────────────────────────────────────┤
│                         Bob         │
│                    I'm ready! 💪    │
│              2:31 PM  Read by 4     │
├─────────────────────────────────────┤
│ System Message                      │
│ Charlie joined the group            │
│           2:32 PM                   │
└─────────────────────────────────────┘
```

### **Group Info:**
```
┌─────────────────────────────────────┐
│           Study Group               │
│         [Group Photo]               │
│         5 members                   │
│                                     │
│ ✏️ Edit (Admin only)                │
├─────────────────────────────────────┤
│ Members:                            │
│ • Alice (Admin) 👑                  │
│ • Bob                               │
│ • Charlie                           │
│ • David                             │
│ • Eve                               │
├─────────────────────────────────────┤
│ ➕ Add Members                      │
│ 🚪 Leave Group (red)                │
└─────────────────────────────────────┘
```

---

## 🔒 Security

### **Firestore Rules:**

```javascript
// Only members can read group messages
match /conversations/{convId}/messages/{msgId} {
  allow read: if request.auth.uid in 
    get(/databases/$(database)/documents/conversations/$(convId)).data.participants;
  
  allow create: if request.auth.uid in 
    get(/databases/$(database)/documents/conversations/$(convId)).data.participants;
}

// Only admins can modify group
match /conversations/{convId} {
  allow update: if request.auth.uid in 
    resource.data.admins;
  
  // Anyone can leave
  allow update: if request.auth.uid in resource.data.participants &&
    request.resource.data.participants.size() == resource.data.participants.size() - 1;
}
```

---

## 🚀 Timeline Impact

### **Updated Schedule:**

| Phase | Days | Description |
|-------|------|-------------|
| 1 | 2 | Project setup & authentication |
| 2 | 2 | Friends system |
| 3 | 3 | Core messaging |
| 4 | 3 | Rich messaging features |
| **4.5** | **1** | **Group chat** ⬅️ NEW! |
| 5 | 3 | Voice/video calling |
| ... | ... | ... |
| **Total** | **33 days** | (was 32 days) |

**MVP now includes:** Phases 1-4.5 (8-12 days)
- ✅ Authentication
- ✅ Friends system
- ✅ 1-on-1 messaging
- ✅ Rich media (images, voice, reactions, edits, threads)
- ✅ **Group chat** ⬅️ NEW!

---

## 🎯 Key Features

### **Must-Have (MVP):**
- ✅ Create group with 2+ members
- ✅ Group name (optional, falls back to member names)
- ✅ Send messages in group
- ✅ See all member names on messages
- ✅ Add members to group
- ✅ Leave group
- ✅ System messages

### **Nice-to-Have (Post-MVP):**
- ⏳ Group photo
- ⏳ Remove members (admin only)
- ⏳ Admin roles and permissions
- ⏳ Mute group notifications
- ⏳ Group call (add in Phase 5+)
- ⏳ Media gallery
- ⏳ Pinned messages
- ⏳ Group description

---

## 📝 Implementation Notes

1. **Start Simple:** Basic group creation and messaging first
2. **Iterate:** Add admin features after basic functionality works
3. **Reuse Code:** Leverage existing MessageRow and ChatView
4. **System Messages:** Use `MessageType.system` for group events
5. **Read Receipts:** Show count in groups to avoid clutter
6. **Notifications:** Update Cloud Functions for group format

---

## ✅ Success Criteria

- [ ] User can create group with 2+ friends
- [ ] All members receive messages in real-time
- [ ] Group name displays correctly
- [ ] Member names show on messages
- [ ] Can add members after creation
- [ ] Can leave group successfully
- [ ] System messages appear for member changes
- [ ] Notifications include group name
- [ ] No performance issues with 10+ members

---

## 🔗 Related Documentation

- Phase 4: Rich Messaging Features (prerequisite)
- Phase 5: Voice/Video Calling (1-on-1 first, group later)
- `Conversation.swift` model (already supports groups)
- Firebase Cloud Functions (update for group notifications)

---

**Status:** Planned  
**Added:** October 21, 2025  
**Estimated Effort:** 1 day  
**Priority:** Medium (enhances MVP significantly)


