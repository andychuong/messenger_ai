# Phase 9: AI Chat Assistant - Quick Start Guide

## Overview

This guide will help you quickly set up and test the AI Chat Assistant feature.

---

## Prerequisites

- Phase 8 completed (RAG, embeddings, intelligence features)
- OpenAI API key configured in Cloud Functions
- Firebase Functions deployed
- iOS app built and running

---

## Quick Setup (5 minutes)

### 1. Deploy Cloud Functions

```bash
cd firebase/functions
npm run build
firebase deploy --only functions:chatWithAssistant
```

**Verify:**
- Check Firebase Console → Functions
- Look for `chatWithAssistant` function
- Status should be "Active"

### 2. Add iOS Files to Xcode

**Required files:**
1. `Services/AIService.swift`
2. `ViewModels/AIAssistantViewModel.swift`
3. `Views/AI/AIAssistantView.swift`
4. `Views/AI/ConversationAIAssistantView.swift`

**Steps:**
1. Open Xcode project
2. Right-click on appropriate folders
3. "Add Files to..."
4. Select all 4 files
5. Ensure "Copy items if needed" is checked
6. Click "Add"

### 3. Build and Run

```bash
# In Xcode:
# 1. Select simulator or device
# 2. Press Cmd+R to build and run
```

---

## Quick Test (3 minutes)

### Test 1: Basic AI Chat

1. Launch app
2. Tap "AI" tab (purple sparkles)
3. See welcome screen
4. Tap "Action Items" quick action
5. Verify AI responds

**Expected:** AI lists your action items or says you have none.

---

### Test 2: Conversation Summary

**Setup:**
1. Have an existing conversation with 10+ messages

**Test:**
1. Open the conversation
2. Tap sparkles icon in toolbar (top right)
3. Tap "Summarize" button
4. Wait 2-3 seconds

**Expected:** AI provides a summary of the conversation.

---

### Test 3: Multi-Turn Conversation

1. Go to AI Assistant tab
2. Type: "What are my action items?"
3. Wait for response
4. Type: "Which one is due first?"
5. Verify AI references previous answer

**Expected:** AI maintains context and answers based on previous response.

---

## Common Issues

### "Authentication required" error

**Fix:**
```bash
# Ensure you're logged in
# Check Firebase Auth in app
```

### AI not responding

**Fix:**
```bash
# Check Cloud Function logs
firebase functions:log --only chatWithAssistant

# Verify OPENAI_API_KEY
firebase functions:config:get openai.api_key
```

### "Invalid response format" error

**Fix:**
- Ensure Cloud Functions deployed correctly
- Check TypeScript compilation succeeded
- Verify OpenAI API key is valid

---

## Feature Showcase

### 1. Quick Actions

**Try these:**
- "Summarize" → Get conversation overview
- "Action Items" → See pending tasks
- "Decisions" → Review decisions made
- "Priority" → Find urgent messages

### 2. Natural Language Queries

**Try asking:**
- "What did we decide about the project?"
- "Find messages about the deadline"
- "Show me high-priority messages"
- "What action items are due this week?"

### 3. Conversation-Specific Assistant

1. Open any conversation
2. Tap sparkles icon
3. Ask: "Summarize this conversation"
4. Try: "What decisions were made here?"

---

## Performance Tips

### Improve Response Time

1. **Limit conversation history:**
   - Only last 10 messages included by default
   - Adjust in `AIService.swift` if needed

2. **Cache responses:**
   - Summaries can be cached
   - Avoid re-summarizing same conversation

3. **Use specific queries:**
   - "What are my tasks?" (fast)
   - vs "Tell me everything" (slow)

### Reduce Costs

1. **Use quick actions** instead of typing
2. **Clear history** periodically
3. **Scope to conversation** when possible
4. **Avoid redundant queries**

---

## Development Tips

### Debug Mode

Enable detailed logging:

```swift
// In AIService.swift
print("🤖 Sending request:", requestData)
print("✅ Received response:", response)
```

### Test with Emulator

```bash
cd firebase/functions
npm run serve

# In AIService.swift, use emulator:
// functions.useFunctionsEmulator(origin: "http://localhost:5001")
```

### Monitor Costs

```javascript
// In assistant.ts
console.log('Token usage:', completion.usage);
```

---

## Next Steps

1. **Test all features** (see PHASE9_TESTING_GUIDE.md)
2. **Customize quick actions** to your needs
3. **Add more tools** to Cloud Function if desired
4. **Implement streaming** for real-time responses
5. **Add voice input** for queries

---

## Resources

- Full Documentation: `PHASE9_COMPLETE.md`
- Testing Guide: `PHASE9_TESTING_GUIDE.md`
- API Reference: `firebase/functions/src/ai/assistant.ts`

---

## Support

**Common Questions:**

Q: How do I add a new quick action?
A: Edit `quickActions` array in `AIAssistantViewModel.swift`

Q: Can I customize the AI's personality?
A: Yes, edit the system prompt in `assistant.ts`

Q: How do I disable AI for a conversation?
A: Currently not implemented, coming in future update

Q: What's the token limit?
A: 1500 tokens per response (adjustable in Cloud Function)

---

**Ready to test!** Launch the app and try the AI Assistant. 🚀

