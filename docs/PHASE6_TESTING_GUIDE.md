# Phase 6: Security & Encryption - Testing Guide

**Last Updated:** October 23, 2025  
**Purpose:** Comprehensive testing guide for E2EE implementation

---

## Quick Test Checklist

### Basic Encryption Tests
- [ ] **Test 1:** Send a text message - verify it's encrypted in Firestore
- [ ] **Test 2:** Receive a message - verify it's decrypted and readable
- [ ] **Test 3:** Send an image - verify it's encrypted in Storage
- [ ] **Test 4:** View an image - verify it's decrypted and displays correctly
- [ ] **Test 5:** Edit a message - verify encryption is maintained
- [ ] **Test 6:** React to a message - verify reactions work with encrypted messages

### Authentication Flow Tests
- [ ] **Test 7:** Sign up new user - verify RSA keys are generated
- [ ] **Test 8:** Login existing user - verify keys are loaded/generated
- [ ] **Test 9:** Logout - verify all keys are deleted from Keychain
- [ ] **Test 10:** Login again - verify messages still decrypt correctly

### Advanced Tests
- [ ] **Test 11:** Thread replies - verify encrypted
- [ ] **Test 12:** Group messages - verify encrypted
- [ ] **Test 13:** Voice messages - verify encrypted
- [ ] **Test 14:** Multiple conversations - verify separate keys

---

## Detailed Test Cases

### Test 1: Send Encrypted Text Message

**Objective:** Verify text messages are encrypted before storage

**Steps:**
1. Open the app and login
2. Navigate to a conversation
3. Send message: "This is a test message"
4. Open Firebase Console → Firestore
5. Navigate to `/conversations/{id}/messages/{messageId}`
6. Check the `text` field

**Expected Result:**
- ✅ Text field contains base64 encoded string (not plaintext)
- ✅ String looks like: `iGN0ZXh0IjogIkhlbGxvISIsICJub25jZSI6...`
- ✅ Message displays correctly in app as "This is a test message"

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 2: Receive and Decrypt Message

**Objective:** Verify incoming messages are decrypted

**Steps:**
1. Have User A send message to User B
2. User B should see the message in real-time
3. Message should be readable plaintext

**Expected Result:**
- ✅ Message appears immediately (real-time listener)
- ✅ Message text is decrypted and readable
- ✅ No "[Encrypted]" placeholder shown
- ✅ Timestamp, sender name, and other metadata visible

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 3: Send Encrypted Image

**Objective:** Verify images are encrypted before upload

**Steps:**
1. Open conversation
2. Tap image picker
3. Select a photo
4. Send the image
5. Open Firebase Console → Storage
6. Navigate to `/images/{conversationId}/`
7. Find the uploaded file

**Expected Result:**
- ✅ File extension is `.enc` (not `.jpg`)
- ✅ Content-Type is `application/octet-stream`
- ✅ Metadata includes `encrypted: true`
- ✅ File is not viewable in Storage console (encrypted binary)
- ✅ Image displays correctly in app

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 4: View Encrypted Image

**Objective:** Verify images are decrypted on display

**Steps:**
1. Open conversation with image message
2. Tap on image to view full screen
3. Image should display correctly

**Expected Result:**
- ✅ Image loads and displays correctly
- ✅ Full resolution visible
- ✅ No decryption errors
- ✅ Loading time reasonable (<2 seconds)

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 5: Edit Encrypted Message

**Objective:** Verify edited messages remain encrypted

**Steps:**
1. Send a message: "Original message"
2. Long press on message → Edit
3. Change to: "Edited message"
4. Save edit
5. Check Firestore console

**Expected Result:**
- ✅ Edited text is encrypted in Firestore
- ✅ `editedAt` timestamp is set
- ✅ `originalText` field contains original encrypted text
- ✅ Message displays as "Edited message" with "Edited" label
- ✅ Editing works within 15-minute window

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 6: Message Reactions with Encryption

**Objective:** Verify reactions work with encrypted messages

**Steps:**
1. Send an encrypted message
2. Long press → React with emoji (e.g., 👍)
3. Check that reaction displays
4. Remove reaction

**Expected Result:**
- ✅ Reaction adds successfully
- ✅ Reaction displays below message
- ✅ Reaction removes successfully
- ✅ Multiple reactions possible
- ✅ Encrypted message still readable

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 7: New User Signup with Key Generation

**Objective:** Verify RSA keys are generated on signup

**Steps:**
1. Sign up a new user
2. Check console logs for "🔐 Phase 6: Generated encryption keys"
3. Open Firestore → `/users/{userId}`
4. Check for `publicKey` field

**Expected Result:**
- ✅ Console shows key generation message
- ✅ `publicKey` field exists in Firestore
- ✅ Public key is base64 encoded string
- ✅ Public key is ~500+ characters long
- ✅ Signup completes successfully

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 8: Existing User Login with Key Verification

**Objective:** Verify existing users get keys if they don't have them

**Steps:**
1. Login with an existing user (created before Phase 6)
2. Check console for "🔐 Phase 6: Generating encryption keys for existing user"
3. Send a message
4. Message should be encrypted

**Expected Result:**
- ✅ Keys generated automatically on first login
- ✅ Public key saved to Firestore
- ✅ User can send/receive encrypted messages immediately
- ✅ No errors in console

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 9: Logout Key Deletion

**Objective:** Verify all encryption keys are deleted on logout

**Steps:**
1. Login and send some messages
2. Logout
3. Check console for "🔐 Phase 6: Deleted all encryption keys on logout"
4. (Optional) Use Keychain Access app to verify

**Expected Result:**
- ✅ Console shows key deletion message
- ✅ No errors during logout
- ✅ Logout completes successfully
- ✅ All conversation keys deleted
- ✅ User RSA keys deleted

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 10: Re-Login and Decrypt Previous Messages

**Objective:** Verify messages remain decryptable after logout/login

**Steps:**
1. Login with user who has sent encrypted messages
2. Open conversation
3. Scroll through message history
4. All messages should be decrypted

**Expected Result:**
- ✅ All previous messages decrypt correctly
- ✅ Images decrypt correctly
- ✅ No "[Encrypted]" placeholders
- ✅ Conversation keys re-generated automatically

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 11: Thread Replies Encryption

**Objective:** Verify thread replies are encrypted

**Steps:**
1. Send a message
2. Reply to message (create thread)
3. Send several replies
4. Check Firestore for thread messages

**Expected Result:**
- ✅ All thread replies are encrypted
- ✅ Replies decrypt correctly in thread view
- ✅ Parent message still readable
- ✅ Thread count updates correctly

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 12: Group Chat Encryption

**Objective:** Verify group messages are encrypted

**Steps:**
1. Create a group with 3+ members
2. Send messages from different members
3. Check Firestore for group messages
4. Verify all members can read messages

**Expected Result:**
- ✅ All group messages encrypted
- ✅ All members can decrypt and read messages
- ✅ Same conversation key used for all members
- ✅ System messages (joins/leaves) not encrypted

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 13: Voice Messages Encryption

**Objective:** Verify voice message transcripts are encrypted

**Steps:**
1. Send a voice message
2. Wait for transcription (if implemented)
3. Check Firestore for voice message document

**Expected Result:**
- ✅ Voice message text field encrypted
- ✅ Media URL points to encrypted file
- ✅ Voice duration visible
- ✅ Play button works correctly

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Test 14: Multiple Conversations with Separate Keys

**Objective:** Verify each conversation has unique encryption key

**Steps:**
1. Send messages to Conversation A
2. Send messages to Conversation B
3. Send messages to Conversation C
4. Verify all messages decrypt correctly in their respective conversations

**Expected Result:**
- ✅ All messages in Conversation A readable
- ✅ All messages in Conversation B readable
- ✅ All messages in Conversation C readable
- ✅ No cross-contamination between conversations
- ✅ Each conversation has separate key in Keychain

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

## Security Verification Tests

### Security Test 1: Firestore Data Inspection

**Objective:** Verify no plaintext in database

**Steps:**
1. Send various messages (text, images, edits)
2. Open Firebase Console → Firestore
3. Randomly inspect 10+ messages
4. Verify all `text` fields are encrypted

**Expected Result:**
- ✅ 100% of messages have encrypted text
- ✅ No readable plaintext in database
- ✅ Only metadata visible (timestamps, IDs)

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Security Test 2: Storage Data Inspection

**Objective:** Verify no plaintext images in Storage

**Steps:**
1. Upload several images
2. Open Firebase Console → Storage
3. Try to view images directly in console
4. Verify images cannot be viewed

**Expected Result:**
- ✅ Images have `.enc` extension
- ✅ Cannot preview in Storage console
- ✅ Download and attempt to open = unreadable binary
- ✅ Only decryptable through app

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Security Test 3: Keychain Verification

**Objective:** Verify keys are stored securely in Keychain

**Steps:**
1. Login to app
2. Send messages to create conversation keys
3. Use Xcode → Debug → View Device Keychain (if simulator)
4. Search for "com.messagingapp.encryption"

**Expected Result:**
- ✅ Keys visible in Keychain
- ✅ Keys have correct identifiers (conversationKey_, privateKey_, etc.)
- ✅ Keys protected with device security
- ✅ After logout, keys are deleted

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Security Test 4: Network Traffic Inspection

**Objective:** Verify encrypted data transmitted over network

**Steps:**
1. Use Charles Proxy or similar tool
2. Capture network traffic
3. Send messages and images
4. Inspect Firestore API calls

**Expected Result:**
- ✅ Message text in API payload is encrypted (base64)
- ✅ Image data in API payload is encrypted binary
- ✅ No plaintext visible in network traffic
- ✅ HTTPS encryption + app encryption = double protection

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Security Test 5: Unauthorized Access Attempt

**Objective:** Verify Firestore rules prevent unauthorized access

**Steps:**
1. User A sends messages in Conversation 1
2. User B (not in Conversation 1) attempts to read messages
3. Should be blocked by Firestore rules

**Expected Result:**
- ✅ User B cannot read messages
- ✅ Firestore returns permission denied error
- ✅ User B cannot write to conversation
- ✅ Only participants can access conversation

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

## Performance Tests

### Performance Test 1: Encryption Speed

**Objective:** Measure encryption performance

**Steps:**
1. Send 10 messages rapidly
2. Note any delays
3. Check console for timing logs (if added)

**Expected Result:**
- ✅ Each message encrypts in <5ms
- ✅ No noticeable lag in UI
- ✅ Messages appear instantly after send

**Actual Result:**
- Encryption time: _____ ms per message
- [ ] Pass (<5ms)
- [ ] Fail - Details: _______________

---

### Performance Test 2: Decryption Speed

**Objective:** Measure decryption performance

**Steps:**
1. Open conversation with 50+ messages
2. Note load time
3. Scroll through messages

**Expected Result:**
- ✅ All messages decrypt in <5ms each
- ✅ Conversation loads in <2 seconds
- ✅ Smooth scrolling (no lag)

**Actual Result:**
- Load time: _____ seconds
- [ ] Pass (<2s)
- [ ] Fail - Details: _______________

---

### Performance Test 3: Image Encryption Overhead

**Objective:** Measure image encryption time

**Steps:**
1. Select a large image (2-3 MB)
2. Send image
3. Note upload time
4. Compare to unencrypted upload (if possible)

**Expected Result:**
- ✅ Encryption adds <100ms to upload
- ✅ Total upload time reasonable (<5 seconds on good connection)
- ✅ No app freeze during encryption

**Actual Result:**
- Encryption time: _____ ms
- Total upload time: _____ seconds
- [ ] Pass
- [ ] Fail - Details: _______________

---

## Edge Cases and Error Handling

### Edge Case 1: Missing Encryption Key

**Objective:** Test app behavior when key is missing

**Steps:**
1. (Advanced) Manually delete conversation key from Keychain
2. Try to decrypt messages
3. App should handle gracefully

**Expected Result:**
- ✅ App doesn't crash
- ✅ Shows "[Encrypted]" placeholder for unreadable messages
- ✅ New conversation key generated if sending new message
- ✅ Error logged to console

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Edge Case 2: Very Long Message

**Objective:** Test encryption of large text

**Steps:**
1. Compose a very long message (5000+ characters)
2. Send message
3. Verify encryption works

**Expected Result:**
- ✅ Message encrypts successfully
- ✅ Firestore accepts message (under 20,000 char limit)
- ✅ Message decrypts correctly
- ✅ No truncation

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Edge Case 3: Corrupted Encrypted Data

**Objective:** Test decryption of corrupted data

**Steps:**
1. (Advanced) Manually edit encrypted text in Firestore
2. Try to view message in app
3. App should handle gracefully

**Expected Result:**
- ✅ App doesn't crash
- ✅ Shows "[Encrypted]" or error message
- ✅ Error logged to console
- ✅ Other messages still readable

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

### Edge Case 4: Offline Encryption

**Objective:** Test encryption without network

**Steps:**
1. Enable airplane mode
2. Send a message
3. Message should be encrypted locally
4. Disable airplane mode
5. Message should sync

**Expected Result:**
- ✅ Message encrypts while offline
- ✅ Message queued for sending
- ✅ Message syncs when back online
- ✅ Recipient can decrypt message

**Actual Result:**
- [ ] Pass
- [ ] Fail - Details: _______________

---

## Regression Tests

### Regression Test 1: Existing Features Still Work

**Objective:** Verify Phase 6 didn't break existing features

**Checklist:**
- [ ] Send/receive text messages
- [ ] Send/receive images
- [ ] Send/receive voice messages
- [ ] Message reactions
- [ ] Message editing
- [ ] Thread replies
- [ ] Group chat
- [ ] Typing indicators
- [ ] Read receipts
- [ ] Message status (sent/delivered/read)
- [ ] Conversation list updates
- [ ] Search functionality (if implemented)
- [ ] Voice/video calls
- [ ] Friend requests
- [ ] User profile updates

**Result:**
- [ ] All features working
- [ ] Issues found: _______________

---

## Test Summary

### Results

| Test Category | Total Tests | Passed | Failed | Skipped |
|---------------|-------------|--------|--------|---------|
| Basic Encryption | 6 | ___ | ___ | ___ |
| Authentication Flow | 4 | ___ | ___ | ___ |
| Advanced Features | 4 | ___ | ___ | ___ |
| Security Verification | 5 | ___ | ___ | ___ |
| Performance | 3 | ___ | ___ | ___ |
| Edge Cases | 4 | ___ | ___ | ___ |
| Regression | 1 | ___ | ___ | ___ |
| **TOTAL** | **27** | **___** | **___** | **___** |

### Issues Found

1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

### Sign-Off

- [ ] All critical tests passed
- [ ] No security vulnerabilities found
- [ ] Performance acceptable
- [ ] Ready for production

**Tested By:** _______________  
**Date:** _______________  
**Version:** Phase 6  
**Build:** _______________

---

## Debugging Tips

### Issue: Messages show "[Encrypted]"
**Solution:** Check that conversation key exists in Keychain

### Issue: Images don't display
**Solution:** Verify conversationId is passed to downloadImage()

### Issue: "Keys not found" error
**Solution:** Ensure user is logged in and keys were generated

### Issue: Firestore permission denied
**Solution:** Deploy updated firestore.rules

### Issue: Very slow encryption
**Solution:** Check device performance, optimize if needed

---

## Next Steps After Testing

1. ✅ Fix any issues found
2. ✅ Re-test failed cases
3. ✅ Update documentation with findings
4. ✅ Get approval from team lead
5. ✅ Deploy to production

---

**Happy Testing! 🔐**

