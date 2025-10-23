# Fix: Add FirebaseFunctions Dependency

**Issue:** `Unable to find module dependency: 'FirebaseFunctions'`

**Solution:** Add FirebaseFunctions to your Xcode project

---

## Quick Fix (2 minutes)

### Step 1: Open Project Settings
1. Open your Xcode project
2. Click on the **messagingapp** project in the navigator (top item, blue icon)
3. Select the **messagingapp** target under "TARGETS"

### Step 2: Add FirebaseFunctions
1. Click on the **"Frameworks, Libraries, and Embedded Content"** section
2. Or go to the **"General"** tab and scroll down
3. Click the **"+"** button at the bottom

### Step 3: Select the Package Product
1. In the popup, you'll see all available Firebase products
2. Scroll to find **"FirebaseFunctions"**
3. Check the checkbox next to it
4. Click **"Add"**

### Step 4: Verify
1. You should now see `FirebaseFunctions` in the frameworks list
2. Build the project (Cmd+B)
3. The error should be gone! ✅

---

## Alternative: Add via Package Dependencies Tab

### Method 2: Through Package Dependencies

1. Select the **messagingapp** project (blue icon)
2. Go to the **"Package Dependencies"** tab
3. Find **"firebase-ios-sdk"** in the list
4. Click on it, then look at the right panel
5. Under **"Add to Target"**, make sure **FirebaseFunctions** is checked
6. If not, check it and click **"Apply"**

---

## Verify Installation

After adding FirebaseFunctions, verify it's in the project:

**In project.pbxproj, you should see:**
```
/* FirebaseFunctions in Frameworks */
```

**In your code, this should now work:**
```swift
import FirebaseFunctions  // ✅ No error
```

---

## Current Firebase Dependencies

Your project currently has:
- ✅ FirebaseAnalytics
- ✅ FirebaseAuth
- ✅ FirebaseFirestore
- ✅ FirebaseMessaging
- ✅ FirebaseStorage
- ❌ FirebaseFunctions (NEEDS TO BE ADDED)

---

## Why This Happened

The `TranslationService.swift` file created in Phase 7 uses `FirebaseFunctions` to call the backend translation Cloud Functions. This dependency wasn't added earlier because previous phases didn't need it.

---

## After Adding

Once FirebaseFunctions is added:
1. Clean build folder (Cmd+Shift+K)
2. Build project (Cmd+B)
3. The error should disappear
4. Translation feature will work! 🎉

---

## Still Having Issues?

### If the error persists:

1. **Clean Build Folder**
   - In Xcode: Product → Clean Build Folder (Cmd+Shift+K)

2. **Restart Xcode**
   - Close Xcode completely
   - Reopen the project

3. **Delete Derived Data**
   - Xcode → Preferences → Locations
   - Click arrow next to Derived Data path
   - Delete the `messagingapp-xxxx` folder
   - Rebuild

4. **Check Package Resolution**
   - File → Packages → Resolve Package Versions
   - Wait for resolution to complete

---

## Manual Alternative (Not Recommended)

If you absolutely need to add it manually via project.pbxproj, I can help with that, but it's much safer to use Xcode's UI as described above.

---

**Expected Time:** 2 minutes  
**Difficulty:** Easy ⭐  
**Impact:** Fixes the import error completely

