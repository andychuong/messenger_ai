# Crash Fix: Missing EnvironmentObjects (CallViewModel & ToastManager)

## The Problem

**Crash Errors:** 
```
Fatal error: No ObservableObject of type CallViewModel found.
A View.environmentObject(_:) for CallViewModel may be missing as an ancestor of this view.

Fatal error: No ObservableObject of type ToastManager found.
A View.environmentObject(_:) for ToastManager may be missing as an ancestor of this view.
```

**Location:** ChatView.swift (lines 12, 142), triggered when navigating from FriendsListView to ChatView

**Root Cause:**
When we refactored the calling feature to use a global `CallViewModel` in `MainTabView`, we changed `ChatView` to expect it as an `@EnvironmentObject`:

```swift
@EnvironmentObject private var callViewModel: CallViewModel
@EnvironmentObject private var toastManager: ToastManager
```

However, when views with their own `NavigationStack` (like `FriendsListView`, `ConversationListView`, `NewMessageView`) navigate to `ChatView`, the environment objects weren't being properly received by those parent views and therefore couldn't be propagated to their navigation destinations.

ChatView requires BOTH environment objects because:
- `callViewModel` is used for call buttons in the toolbar
- `toastManager` is used to prevent showing toasts for the active conversation

## The Solution

Added both required `@EnvironmentObject` properties to all views that:
1. Create their own NavigationStack
2. Navigate to ChatView as a destination
3. Need to propagate the environment objects down the view hierarchy

Required environment objects for ChatView:
- `CallViewModel` - For call functionality
- `ToastManager` - For message notifications

## Files Fixed

### 1. FriendsListView.swift
**Changes:** 
- Added `@EnvironmentObject private var callViewModel: CallViewModel`
- Added `@EnvironmentObject private var toastManager: ToastManager`

**Why:** FriendsListView has its own NavigationStack and navigates to ChatView when clicking on a friend. Both environment objects need to be received here so they can propagate to navigation destinations.

**Also Updated:** 
- Preview to include both environment objects
- MainTabView to provide `.environmentObject(toastManager)` to FriendsListView

### 2. ConversationListView.swift
**Changes:**
- Added `@EnvironmentObject private var callViewModel: CallViewModel`
- Already had `@EnvironmentObject private var toastManager: ToastManager`

**Why:** ConversationListView navigates to ChatView from the conversations list. Needs to receive and propagate both environment objects.

**Also Updated:** Preview to include both ToastManager and CallViewModel environment objects.

### 3. NewMessageView.swift
**Changes:**
- Added `@EnvironmentObject private var callViewModel: CallViewModel`
- Added `@EnvironmentObject private var toastManager: ToastManager`

**Why:** NewMessageView is shown as a sheet from ConversationListView and navigates to ChatView when selecting a friend to message. Needs both environment objects for its navigation destination.

**Also Updated:** Preview to include both environment objects

### 4. MainTabView.swift
**Changes:**
- Added `.environmentObject(toastManager)` to FriendsListView tab
- Already had `.environmentObject(callViewModel)` for all tabs

**Why:** FriendsListView wasn't receiving ToastManager, so it couldn't propagate it to ChatView

### 4. ChatView.swift
**Update:** Added CallViewModel to Preview

**Why:** Preview was missing the environment object, would crash during preview/development.

## How SwiftUI EnvironmentObject Propagation Works

```
MainTabView (creates CallViewModel as @StateObject)
    ↓ .environmentObject(callViewModel)
FriendsListView (receives as @EnvironmentObject)
    ↓ automatic propagation
    NavigationStack
        ↓ automatic propagation  
        navigationDestination
            ↓ automatic propagation
            ChatView (receives as @EnvironmentObject)
```

**Key Point:** Every view in the chain that has a `NavigationStack` or acts as a boundary must explicitly receive the `@EnvironmentObject` even if it doesn't directly use it, so it can propagate to child views.

## Why ChatView Needs These EnvironmentObjects

Even though we moved the call UI overlays to MainTabView (global level), ChatView still needs both environment objects:

### CallViewModel
Used for **call buttons in toolbar** (lines 115, 122):
```swift
Button {
    callViewModel.startAudioCall(to: viewModel.otherUserId)
}
Button {
    callViewModel.startVideoCall(to: viewModel.otherUserId)
}
```
These buttons allow users to initiate calls directly from the chat screen.

### ToastManager
Used to **prevent duplicate notifications** (line 142):
```swift
toastManager.activeConversationId = viewModel.conversationId
```
When you're viewing a chat, you shouldn't get toast notifications for new messages in that same chat. ToastManager tracks which conversation is currently active.

## Testing the Fix

To verify the fix works:

1. ✅ Build the app - should compile without errors
2. ✅ Launch the app and login
3. ✅ Navigate to Friends tab
4. ✅ Click on a friend's name
5. ✅ Should open ChatView without crash
6. ✅ Test call buttons in chat toolbar
7. ✅ Navigate from Conversations list to chat
8. ✅ Start new message from compose button

## Prevention

To prevent this issue in the future:

1. **Always propagate required EnvironmentObjects** - If a child view needs an environment object, all parent views in the navigation chain must receive it (even if they don't use it)

2. **Update Previews** - Always include all required environment objects in Preview blocks

3. **Document dependencies** - Comment which environment objects a view requires

4. **Consider alternatives** - For optional features, consider making the environment object optional or using a different pattern

## Related Files

- MainTabView.swift - Creates and provides global CallViewModel
- CallViewModel.swift - The shared view model for calling features
- CallService.swift - The singleton service managing actual call state

