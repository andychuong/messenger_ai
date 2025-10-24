# Phase 8 Quick Start Guide

**Get Phase 8 features running in 10 minutes!**

---

## Prerequisites

- Firebase project configured
- OpenAI API key
- Xcode installed
- Node.js 18+ for Cloud Functions

---

## Step 1: Configure OpenAI API Key (2 minutes)

```bash
# Navigate to functions directory
cd firebase/functions

# Set OpenAI API key
firebase functions:config:set openai.api_key="sk-your-key-here"

# Or create .env file for local development
echo "OPENAI_API_KEY=sk-your-key-here" > .env
```

---

## Step 2: Deploy Cloud Functions (3 minutes)

```bash
# Build TypeScript
npm run build

# Deploy all functions
firebase deploy --only functions

# Or deploy specific modules
firebase deploy --only functions:generateMessageEmbedding,functions:semanticSearch,functions:answerQuestion,functions:extractActionItems,functions:detectDecision,functions:classifyPriority
```

**Expected output:**
```
✔  functions: Finished running predeploy script.
✔  functions[generateMessageEmbedding(us-central1)]: Successful create operation.
✔  functions[semanticSearch(us-central1)]: Successful create operation.
✔  functions[answerQuestion(us-central1)]: Successful create operation.
✔  functions[extractActionItems(us-central1)]: Successful create operation.
...
✔  Deploy complete!
```

---

## Step 3: Deploy Firestore Rules & Indexes (2 minutes)

```bash
# Deploy security rules
firebase deploy --only firestore:rules

# Deploy indexes (this takes 5-10 minutes to build)
firebase deploy --only firestore:indexes
```

**Note:** Indexes build in the background. Check status:
```bash
firebase firestore:indexes

# Or check Firebase Console:
# https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes
```

---

## Step 4: Build iOS App (3 minutes)

### Option A: Xcode

1. Open `ios/messagingapp/messagingapp.xcodeproj` in Xcode
2. Add new files to project:
   - `Models/ActionItem.swift`
   - `Models/Decision.swift`
   - `Services/RAGService.swift`
   - `Views/AI/ActionItemsView.swift`
   - `Views/AI/DecisionLogView.swift`
3. Build and run (⌘R)

### Option B: Command Line

```bash
cd ios/messagingapp
xcodebuild -project messagingapp.xcodeproj -scheme messagingapp -configuration Debug
```

---

## Step 5: Verify Deployment (Quick Tests)

### Test 1: Embedding Generation

1. Open app and send a message
2. Check Firebase Console → Firestore → `embeddings` collection
3. Should see new document with 1536-dimension embedding array

### Test 2: Semantic Search

In iOS app or test code:
```swift
let ragService = RAGService.shared

Task {
    let results = try await ragService.semanticSearch(
        query: "test search",
        limit: 5
    )
    print("Found \(results.results.count) results")
}
```

### Test 3: Action Item Extraction

```swift
let items = try await ragService.extractActionItems(
    from: "Can you send me the report by Friday?",
    messageId: "test123",
    conversationId: "conv123",
    senderId: "user123"
)
print("Extracted \(items.count) items")
```

---

## Troubleshooting

### Problem: "OpenAI API key not configured"

**Solution:**
```bash
firebase functions:config:get openai
# If empty, set it:
firebase functions:config:set openai.api_key="sk-..."
# Redeploy:
firebase deploy --only functions
```

### Problem: "Permission denied" in Firestore

**Solution:**
```bash
# Redeploy security rules
firebase deploy --only firestore:rules
```

### Problem: "Index not found" error

**Solution:**
```bash
# Check index status
firebase firestore:indexes

# Wait for indexes to build (5-10 minutes)
# Or click the error link to create index manually
```

### Problem: Cloud Functions timeout

**Solution:**
- Check OpenAI API status: https://status.openai.com
- View logs: `firebase functions:log`
- Increase timeout in `firebase.json`:
```json
{
  "functions": {
    "timeoutSeconds": 60
  }
}
```

---

## Next Steps

### Integrate with UI

Add Action Items and Decision Log to your main navigation:

```swift
// MainTabView.swift
TabView {
    ConversationListView()
        .tabItem { Label("Messages", systemImage: "message") }
    
    FriendsListView()
        .tabItem { Label("Friends", systemImage: "person.2") }
    
    ActionItemsView()
        .tabItem { Label("Tasks", systemImage: "checkmark.circle") }
    
    DecisionLogView()
        .tabItem { Label("Decisions", systemImage: "checkmark.seal") }
}
```

### Enable Automatic Features

To automatically extract action items and decisions from messages, call the functions after sending:

```swift
// In MessageService.swift, after sending message:
if messageContainsPotentialActionItems(text) {
    Task {
        _ = try? await RAGService.shared.extractActionItems(
            from: text,
            messageId: messageId,
            conversationId: conversationId,
            senderId: senderId
        )
    }
}
```

---

## Usage Examples

### Semantic Search
```swift
// Search all conversations
let results = try await ragService.semanticSearch(
    query: "project deadlines",
    limit: 10
)

// Search specific conversation
let results = try await ragService.semanticSearch(
    query: "action items",
    conversationId: conversationId,
    limit: 10
)
```

### Question Answering
```swift
let answer = try await ragService.answerQuestion(
    question: "What did we decide about the budget?",
    conversationId: conversationId,
    limit: 10
)

print("Answer: \(answer.answer)")
for source in answer.sources {
    print("Source: \(source.sender) said: \(source.text)")
}
```

### Action Items
```swift
// Extract from message
let items = try await ragService.extractActionItems(
    from: messageText,
    messageId: messageId,
    conversationId: conversationId,
    senderId: senderId
)

// Get user's action items
let myItems = try await ragService.getUserActionItems(
    status: .pending,
    limit: 50
)

// Mark as complete
try await ragService.updateActionItemStatus(
    actionItemId: itemId,
    status: .completed,
    completedBy: userId
)
```

### Decisions
```swift
// Detect decision
let decision = try await ragService.detectDecision(
    in: messageText,
    messageId: messageId,
    conversationId: conversationId,
    senderId: senderId
)

// Get conversation decisions
let decisions = try await ragService.getConversationDecisions(
    conversationId: conversationId,
    limit: 20
)
```

### Priority Classification
```swift
let priority = try await ragService.classifyPriority(
    messageText: messageText,
    messageId: messageId,
    conversationId: conversationId,
    mentions: [mentionedUserId]
)

print("Priority: \(priority.priority.rawValue)")
print("Reason: \(priority.reason)")
```

---

## Cost Management

### Monitor Usage

1. **OpenAI Dashboard**: https://platform.openai.com/usage
2. **Set Budget Limits**: https://platform.openai.com/account/billing/limits

### Optimization Tips

```typescript
// In Cloud Functions, add caching
const cache = new Map();

export const semanticSearch = functions.https.onCall(async (data, context) => {
  const cacheKey = `search:${data.query}`;
  if (cache.has(cacheKey)) {
    return cache.get(cacheKey);
  }
  
  const result = await performSearch(data.query);
  cache.set(cacheKey, result);
  return result;
});
```

### Rate Limiting

```typescript
// Add rate limiting per user
const rateLimit = new Map<string, number>();

export const extractActionItems = functions.https.onCall(async (data, context) => {
  const userId = context.auth!.uid;
  const count = rateLimit.get(userId) || 0;
  
  if (count > 10) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Too many requests. Please try again later.'
    );
  }
  
  rateLimit.set(userId, count + 1);
  // ... rest of function
});
```

---

## Performance Benchmarks

Run these tests to verify performance:

```swift
import Foundation

func measurePerformance() async {
    let ragService = RAGService.shared
    
    // Test 1: Semantic Search
    let searchStart = Date()
    _ = try? await ragService.semanticSearch(query: "test", limit: 5)
    let searchDuration = Date().timeIntervalSince(searchStart)
    print("Semantic Search: \(String(format: "%.2f", searchDuration))s")
    
    // Test 2: Question Answering
    let qaStart = Date()
    _ = try? await ragService.answerQuestion(question: "test?", limit: 5)
    let qaDuration = Date().timeIntervalSince(qaStart)
    print("Question Answering: \(String(format: "%.2f", qaDuration))s")
    
    // Test 3: Action Item Extraction
    let actionStart = Date()
    _ = try? await ragService.extractActionItems(
        from: "Test task by Friday",
        messageId: "test",
        conversationId: "test",
        senderId: "test"
    )
    let actionDuration = Date().timeIntervalSince(actionStart)
    print("Action Item Extraction: \(String(format: "%.2f", actionDuration))s")
}
```

**Expected Results:**
- Semantic Search: < 1s
- Question Answering: 2-4s
- Action Item Extraction: 1-2s

---

## Documentation

For detailed information:

- **Complete Documentation**: `PHASE8_COMPLETE.md`
- **Testing Guide**: `PHASE8_TESTING_GUIDE.md`
- **Summary**: `PHASE8_SUMMARY.md`

---

## Support

### View Logs
```bash
# Real-time logs
firebase functions:log --only embeddings,intelligence

# Specific function
firebase functions:log --only generateMessageEmbedding
```

### Debug Locally
```bash
cd firebase/functions
npm run serve
# Functions will run on http://localhost:5001
```

### Check Deployment Status
```bash
firebase functions:list
firebase firestore:indexes
```

---

**You're all set!** 🚀

Phase 8 features are now live and ready to use. Start sending messages and watch the AI extract insights automatically!

