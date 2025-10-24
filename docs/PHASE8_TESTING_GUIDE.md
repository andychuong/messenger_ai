# Phase 8 Testing Guide
## RAG & Conversation Intelligence Features

**Version:** 1.0  
**Date:** October 23, 2025

---

## Overview

This guide provides comprehensive testing procedures for Phase 8 features:
- Embedding generation and semantic search
- Question answering with RAG
- Action item extraction
- Decision tracking
- Priority message detection

---

## Pre-Testing Setup

### 1. Environment Setup

```bash
# Ensure you're in the functions directory
cd firebase/functions

# Build TypeScript
npm run build

# Deploy Cloud Functions
firebase deploy --only functions

# Deploy Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes
```

### 2. Verify OpenAI API Key

```bash
# Check if API key is configured
firebase functions:config:get openai

# If not set, configure it
firebase functions:config:set openai.api_key="sk-..."
```

### 3. Test Data Preparation

Create test conversations with various message types:
- Simple messages
- Messages with action items ("Can you send the report by Friday?")
- Messages with decisions ("We decided to go with option B")
- Urgent messages ("URGENT: Need your input ASAP")
- Questions requiring responses

---

## Test Suite 1: Embedding Generation

### Test 1.1: Automatic Embedding on New Message

**Objective:** Verify embeddings are created automatically when messages are sent.

**Steps:**
1. Open the app and navigate to a conversation
2. Send a message: "We need to finalize the project timeline by next week"
3. Wait 2-3 seconds
4. Check Firestore Console → `embeddings` collection

**Expected Results:**
- New document with messageId as document ID
- `embedding` field contains array of 1536 numbers
- `text` field contains the message text
- `conversationId` matches the conversation
- `senderId` matches your user ID
- `timestamp` is set correctly

**Pass Criteria:** ✅ Document created with all required fields

---

### Test 1.2: Embedding Quality

**Objective:** Verify embeddings are semantically meaningful.

**Steps:**
1. Send messages with similar meanings:
   - "We need to discuss the budget"
   - "Let's talk about financial planning"
   - "We should review the expenses"
2. Send unrelated message:
   - "The weather is nice today"
3. Use Firebase Console to check embeddings

**Expected Results:**
- Similar messages should have similar embeddings (high cosine similarity)
- Unrelated message should have different embedding

**Pass Criteria:** ✅ Embeddings capture semantic meaning

---

## Test Suite 2: Semantic Search

### Test 2.1: Basic Semantic Search

**Objective:** Test semantic search across all conversations.

**Test Code:**
```swift
let ragService = RAGService.shared

Task {
    do {
        let results = try await ragService.semanticSearch(
            query: "project deadlines",
            limit: 5
        )
        
        print("Found \(results.results.count) results")
        for result in results.results {
            print("Message: \(result.text)")
            print("Similarity: \(result.similarity)")
            print("---")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

**Expected Results:**
- Returns messages related to project deadlines
- Similarity scores between 0.5 and 1.0
- Results sorted by relevance (highest similarity first)
- At least 3 relevant results if available

**Pass Criteria:** ✅ Returns relevant messages with reasonable similarity scores

---

### Test 2.2: Conversation-Specific Search

**Objective:** Test search within a specific conversation.

**Test Code:**
```swift
let results = try await ragService.semanticSearch(
    query: "action items",
    conversationId: "your-conversation-id",
    limit: 10
)
```

**Expected Results:**
- Only returns messages from specified conversation
- Filters out messages from other conversations
- Still maintains relevance ranking

**Pass Criteria:** ✅ Results limited to specified conversation

---

### Test 2.3: No Results Handling

**Objective:** Test behavior when no relevant messages found.

**Test Code:**
```swift
let results = try await ragService.semanticSearch(
    query: "quantum physics Nobel Prize winners",
    limit: 5
)
```

**Expected Results:**
- Returns empty or very low similarity results
- No crashes or errors
- Graceful handling in UI

**Pass Criteria:** ✅ Handles no results gracefully

---

## Test Suite 3: Question Answering (RAG)

### Test 3.1: Simple Question

**Objective:** Test RAG-powered question answering.

**Test Code:**
```swift
let answer = try await ragService.answerQuestion(
    question: "What did we discuss about the project?",
    limit: 10
)

print("Answer: \(answer.answer)")
print("Sources used: \(answer.contextUsed)")
for source in answer.sources {
    print("- \(source.sender): \(source.text)")
}
```

**Expected Results:**
- Clear, coherent answer based on conversation history
- Sources array contains relevant messages
- Answer cites specific people and information
- contextUsed > 0

**Pass Criteria:** ✅ Provides accurate answer with sources

---

### Test 3.2: Complex Question

**Objective:** Test multi-fact question requiring synthesis.

**Test Code:**
```swift
let answer = try await ragService.answerQuestion(
    question: "What were the main action items from our last meeting and who was assigned to each?",
    limit: 15
)
```

**Expected Results:**
- Answer synthesizes information from multiple messages
- Lists action items with assignees
- Provides context and details
- Sources show where information came from

**Pass Criteria:** ✅ Synthesizes information from multiple sources

---

### Test 3.3: Unanswerable Question

**Objective:** Test behavior when answer cannot be determined.

**Test Code:**
```swift
let answer = try await ragService.answerQuestion(
    question: "What's the weather forecast for next week?",
    limit: 10
)
```

**Expected Results:**
- Answer clearly states information is not available
- Does not hallucinate or make up information
- Suggests what information is available

**Pass Criteria:** ✅ Honestly reports when unable to answer

---

## Test Suite 4: Action Item Extraction

### Test 4.1: Single Message Extraction

**Objective:** Extract action items from a message.

**Test Messages:**
1. "Can you send me the report by Friday?"
2. "Don't forget to review the budget this week"
3. "URGENT: Need your approval on the design ASAP"

**Test Code:**
```swift
for messageText in testMessages {
    let items = try await ragService.extractActionItems(
        from: messageText,
        messageId: "test-\(UUID())",
        conversationId: "conv123",
        senderId: "user123"
    )
    
    print("Extracted \(items.count) items from: \(messageText)")
    for item in items {
        print("- Task: \(item.task)")
        print("  Priority: \(item.priority)")
        print("  Assignee: \(item.assignedTo ?? "none")")
        print("  Due: \(item.dueDate?.description ?? "none")")
    }
}
```

**Expected Results:**

Message 1:
- Task: "Send the report"
- Assignee: Identified from context
- Due date: This Friday
- Priority: Medium

Message 2:
- Task: "Review the budget"
- Due: This week
- Priority: Medium

Message 3:
- Task: "Provide approval on design"
- Priority: High (due to URGENT)
- Assignee: Identified

**Pass Criteria:** ✅ Correctly identifies tasks, priority, and deadlines

---

### Test 4.2: Conversation-Wide Extraction

**Objective:** Extract all action items from a conversation.

**Prerequisite:** Conversation with 5-10 messages containing various tasks

**Test Code:**
```swift
let items = try await ragService.extractActionItemsFromConversation(
    conversationId: "your-conversation-id",
    limit: 50
)

print("Found \(items.count) action items")
for item in items {
    print("- \(item.task) [\(item.priority.rawValue)]")
}
```

**Expected Results:**
- Extracts all explicit action items
- No duplicate tasks
- Prioritizes correctly
- Groups related items

**Pass Criteria:** ✅ Comprehensive extraction without duplicates

---

### Test 4.3: ActionItemsView UI Test

**Objective:** Test the Action Items UI.

**Steps:**
1. Navigate to Action Items tab/view
2. Verify segmented control shows: Pending, Completed, Cancelled
3. Check that pending items display correctly
4. Tap checkbox on an item to complete it
5. Switch to "Completed" tab
6. Verify item appears in completed list
7. Swipe left on item to access actions
8. Test "Delete" action

**Expected Results:**
- All action items load correctly
- Overdue items highlighted in red
- Due soon items in separate section
- Checkbox toggles status
- Swipe actions work
- Filtering by status works
- Pull to refresh updates list

**Pass Criteria:** ✅ All UI interactions work smoothly

---

## Test Suite 5: Decision Tracking

### Test 5.1: Decision Detection

**Objective:** Detect decisions in messages.

**Test Messages:**
1. "After careful consideration, we've decided to go with vendor A"
2. "I think we should consider option B" (not a decision)
3. "Final decision: Launch on March 15th"

**Test Code:**
```swift
for messageText in testMessages {
    let decision = try await ragService.detectDecision(
        in: messageText,
        messageId: "test-\(UUID())",
        conversationId: "conv123",
        senderId: "user123"
    )
    
    if let decision = decision {
        print("Decision detected: \(decision.decision)")
        print("Rationale: \(decision.rationale ?? "none")")
    } else {
        print("No decision detected")
    }
}
```

**Expected Results:**

Message 1:
- Decision: "Go with vendor A"
- Rationale: "After careful consideration"
- Stored in Firestore

Message 2:
- No decision detected (tentative language)

Message 3:
- Decision: "Launch on March 15th"
- Outcome: Clear date

**Pass Criteria:** ✅ Accurately distinguishes decisions from discussions

---

### Test 5.2: DecisionLogView UI Test

**Objective:** Test the Decision Log UI.

**Steps:**
1. Navigate to Decision Log view
2. Verify decisions display as cards
3. Tap a decision card to expand
4. Verify rationale and outcome show
5. Test search functionality
6. Search for a keyword from a decision
7. Verify filtering works

**Expected Results:**
- All decisions load in chronological order
- Cards expand/collapse smoothly
- Search filters results
- "View in Chat" button navigates correctly
- Empty state shows when no decisions

**Pass Criteria:** ✅ UI is intuitive and functional

---

### Test 5.3: Get Conversation Decisions

**Objective:** Fetch all decisions for a conversation.

**Test Code:**
```swift
let decisions = try await ragService.getConversationDecisions(
    conversationId: "your-conversation-id",
    limit: 20
)

print("Found \(decisions.count) decisions")
for decision in decisions {
    print("\(decision.formattedDate): \(decision.decision)")
}
```

**Expected Results:**
- Returns all decisions for the conversation
- Ordered by date (most recent first)
- Includes all metadata

**Pass Criteria:** ✅ Complete decision history retrieved

---

## Test Suite 6: Priority Detection

### Test 6.1: Priority Classification

**Objective:** Test message priority detection.

**Test Messages:**
1. "URGENT: Server is down, need immediate help!"
2. "Can you review this when you get a chance?"
3. "FYI, the meeting is rescheduled"

**Test Code:**
```swift
for messageText in testMessages {
    let priority = try await ragService.classifyPriority(
        messageText: messageText,
        messageId: "test-\(UUID())",
        conversationId: "conv123"
    )
    
    print("Message: \(messageText)")
    print("Priority: \(priority.priority.rawValue)")
    print("Reason: \(priority.reason)")
    print("Requires response: \(priority.requiresResponse)")
    print("---")
}
```

**Expected Results:**

Message 1:
- Priority: High
- Requires response: true
- Reason: Contains "URGENT" and immediate action needed

Message 2:
- Priority: Medium
- Requires response: true
- Reason: Direct question/request

Message 3:
- Priority: Low
- Requires response: false
- Reason: Informational FYI

**Pass Criteria:** ✅ Accurate priority assignment with clear reasoning

---

### Test 6.2: Mention Priority Boost

**Objective:** Test that mentions increase priority.

**Test Code:**
```swift
let priority = try await ragService.classifyPriority(
    messageText: "Can you check this out?",
    messageId: "msg123",
    conversationId: "conv123",
    mentions: [Auth.auth().currentUser!.uid]
)

print("Priority: \(priority.priority)")
```

**Expected Results:**
- Priority elevated to High
- Reason mentions being mentioned
- requiresResponse: true

**Pass Criteria:** ✅ Mentions correctly boost priority

---

### Test 6.3: Priority Indicators in UI

**Objective:** Test visual priority indicators in conversation list.

**Steps:**
1. Have a conversation with high-priority unread message
2. Navigate to conversation list
3. Look for priority indicators

**Expected Results:**
- Red exclamation mark badge on avatar
- Red triangle icon next to conversation name
- Only shows for unread priority messages
- Disappears when message is read

**Pass Criteria:** ✅ Visual indicators present and accurate

---

## Test Suite 7: Integration Tests

### Test 7.1: End-to-End Flow

**Objective:** Test complete flow from message to extraction.

**Steps:**
1. Send message: "John, can you complete the financial report by Friday? This is urgent."
2. Wait for embedding generation
3. Extract action items
4. Classify priority
5. Detect decision (if applicable)

**Expected Results:**
- Embedding created within 3 seconds
- Action item extracted: "Complete financial report"
- Priority: High (urgent keyword)
- Assignee: John
- Due date: This Friday
- All data stored in Firestore

**Pass Criteria:** ✅ Complete pipeline works end-to-end

---

### Test 7.2: Performance Test

**Objective:** Test system under load.

**Steps:**
1. Send 10 messages rapidly
2. Trigger action item extraction on large conversation (50+ messages)
3. Perform multiple semantic searches concurrently

**Expected Results:**
- All embeddings generated (may take up to 30 seconds)
- No errors or timeouts
- Batch extraction completes within 10 seconds
- Searches return results within 2 seconds each

**Pass Criteria:** ✅ System handles load gracefully

---

### Test 7.3: Error Handling

**Objective:** Test error scenarios.

**Test Cases:**
1. Network disconnection during search
2. Invalid conversationId
3. Empty message text
4. Very long message (5000+ characters)

**Expected Results:**
- Appropriate error messages shown to user
- App doesn't crash
- Retry mechanisms work
- Graceful degradation

**Pass Criteria:** ✅ Robust error handling throughout

---

## Test Suite 8: Security & Privacy

### Test 8.1: Firestore Security Rules

**Objective:** Verify security rules prevent unauthorized access.

**Test Cases:**

1. **Embeddings Collection**
   - Try to read from web console as authenticated user
   - Should fail (only Cloud Functions can access)

2. **Action Items**
   - Try to create action item directly
   - Should fail (Cloud Functions only)
   - Try to read another user's action items
   - Should fail

3. **Decisions**
   - Try to update or delete decision
   - Should fail (read-only for users)
   - Try to read decisions from conversation you're not in
   - Should fail

**Expected Results:**
- All unauthorized operations fail
- Error messages indicate permission denied
- No data leaks

**Pass Criteria:** ✅ Security rules properly enforced

---

### Test 8.2: Data Privacy

**Objective:** Verify sensitive data is protected.

**Checks:**
1. Embeddings collection not readable by iOS app
2. Message text in embeddings stored unencrypted (by design for search)
3. Action items only visible to assignees and creators
4. Decisions only visible to conversation participants

**Expected Results:**
- Privacy boundaries respected
- No leakage across conversations
- User data properly scoped

**Pass Criteria:** ✅ Data privacy maintained

---

## Bug Report Template

If you encounter issues during testing, use this template:

```markdown
### Bug Report

**Test Suite:** [e.g., Test 3.1 - Simple Question]
**Date:** [Date]
**Tester:** [Name]

**Description:**
[Clear description of the issue]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected Result:**
[What should happen]

**Actual Result:**
[What actually happened]

**Screenshots/Logs:**
[Attach any relevant screenshots or error logs]

**Environment:**
- iOS Version: [e.g., iOS 17.0]
- Device: [e.g., iPhone 15 Pro]
- Cloud Functions Version: [Check Firebase Console]

**Severity:**
- [ ] Critical (blocks testing)
- [ ] High (major feature broken)
- [ ] Medium (feature partially works)
- [ ] Low (minor issue)
```

---

## Performance Benchmarks

### Target Latencies

| Operation | Target | Acceptable |
|-----------|--------|-----------|
| Embedding Generation | < 500ms | < 1s |
| Semantic Search | < 1s | < 2s |
| Answer Question | < 3s | < 5s |
| Extract Action Items | < 2s | < 3s |
| Detect Decision | < 1.5s | < 2.5s |
| Classify Priority | < 1s | < 2s |

### Test Performance

Use this code to measure actual performance:

```swift
func measurePerformance(operation: String, block: () async throws -> Void) async {
    let start = Date()
    do {
        try await block()
        let duration = Date().timeIntervalSince(start)
        print("\(operation): \(String(format: "%.2f", duration))s")
    } catch {
        print("\(operation) failed: \(error)")
    }
}

// Usage
await measurePerformance(operation: "Semantic Search") {
    _ = try await ragService.semanticSearch(query: "test", limit: 5)
}
```

---

## Final Checklist

Before marking Phase 8 as complete:

### Cloud Functions
- [ ] All functions deploy without errors
- [ ] Functions appear in Firebase Console
- [ ] Logs show no critical errors
- [ ] OpenAI API key configured

### Firestore
- [ ] Security rules deployed
- [ ] Indexes created (check Firebase Console)
- [ ] Collections structure correct
- [ ] Test data populated

### iOS App
- [ ] All models compile
- [ ] RAGService works
- [ ] ActionItemsView displays correctly
- [ ] DecisionLogView displays correctly
- [ ] Priority indicators visible
- [ ] No crashes or memory leaks

### Functionality
- [ ] Embeddings generate automatically
- [ ] Semantic search returns results
- [ ] Question answering works
- [ ] Action items extracted correctly
- [ ] Decisions detected accurately
- [ ] Priority classification reasonable

### Performance
- [ ] All operations within acceptable latency
- [ ] No timeout errors
- [ ] UI remains responsive
- [ ] No excessive OpenAI API calls

### Documentation
- [ ] PHASE8_COMPLETE.md reviewed
- [ ] Testing guide followed
- [ ] Known issues documented
- [ ] Next steps identified

---

## Support & Resources

### Firebase Console
- Functions Logs: https://console.firebase.google.com/project/YOUR_PROJECT/functions/logs
- Firestore Data: https://console.firebase.google.com/project/YOUR_PROJECT/firestore

### OpenAI Platform
- Usage Dashboard: https://platform.openai.com/usage
- API Keys: https://platform.openai.com/api-keys

### Debugging Commands
```bash
# View Cloud Functions logs
firebase functions:log --only embeddings,intelligence

# Test locally with emulator
firebase emulators:start --only functions,firestore

# Check Firestore indexes status
firebase firestore:indexes
```

---

**Happy Testing!** 🧪

If you encounter any issues or have questions, refer to PHASE8_COMPLETE.md for detailed documentation.

