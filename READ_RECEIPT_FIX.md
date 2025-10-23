# Read Receipt Fix

## Problem
After adding in-app toast notifications, messages were being incorrectly marked as read when they shouldn't be. The issue was that the `ChatViewModel`'s real-time listener was marking ALL messages as read every time ANY message change occurred, even when:
- The user wasn't actively viewing the chat
- The app was in the background
- A notification toast was shown

This meant that as soon as a new message arrived and triggered a notification, it was immediately marked as read before the user even saw it.

## Root Cause
In `ChatViewModel.setupRealtimeListeners()`, the code was:
```swift
messagesListener = messageService.listenToMessages(conversationId: conversationId) { [weak self] messages in
    Task { @MainActor in
        self?.messages = messages
        await self?.markAllMessagesAsRead()  // ❌ ALWAYS marking as read!
    }
}
```

This listener fires whenever ANY message in the conversation changes (new message, edit, reaction, etc.), and it was unconditionally marking all messages as read.

## Solution
Added an `isChatActive` flag to track when the chat is actually being viewed:

### 1. ChatViewModel Changes
- Added `var isChatActive = false` to track active viewing state
- Updated `setupRealtimeListeners()` to only mark messages as read when `isChatActive == true`
- Updated `loadMessages()` to respect the `isChatActive` flag

### 2. ChatView Changes
- Set `viewModel.isChatActive = true` in `.onAppear`
- Set `viewModel.isChatActive = false` in `.onDisappear`
- Added `.onChange(of: scenePhase)` to track app foreground/background state:
  - When app goes to `.active`: set `isChatActive = true` and mark messages as read
  - When app goes to `.background` or `.inactive`: set `isChatActive = false`

## How It Works Now
1. **Chat View Appears**: `isChatActive = true`, messages are marked as read
2. **User Leaves Chat**: `isChatActive = false`, new messages won't be auto-marked as read
3. **App Goes to Background**: `isChatActive = false`, messages stay unread
4. **User Returns to Chat**: `isChatActive = true`, messages are marked as read
5. **Toast Notification Shows**: Chat isn't active, so messages stay unread ✅

## Testing
- Build succeeded with no errors
- Messages will only be marked as read when:
  - The chat view is visible AND
  - The app is in the foreground
- Toast notifications will continue to work for unread messages
- Read receipts will now accurately reflect when messages are actually viewed

## Files Modified
- `ios/messagingapp/messagingapp/ViewModels/ChatViewModel.swift`
- `ios/messagingapp/messagingapp/Views/Conversations/ChatView.swift`



