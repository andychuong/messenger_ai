# Firebase Backend for MessageAI

This directory contains all Firebase backend configuration including Cloud Functions, Firestore rules, and security settings.

## Structure

```
firebase/
├── functions/              # Cloud Functions (TypeScript)
│   ├── src/
│   │   ├── index.ts       # Main entry point
│   │   ├── messaging/     # Push notifications
│   │   └── ai/            # AI features
│   ├── package.json
│   └── tsconfig.json
├── firestore.rules        # Firestore security rules
├── storage.rules          # Storage security rules
├── firestore.indexes.json # Database indexes
└── firebase.json          # Firebase configuration
```

## Setup

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Configure Environment Variables

Create `functions/.env` file:

```env
OPENAI_API_KEY=your_key_here
PINECONE_API_KEY=your_key_here
PINECONE_ENVIRONMENT=your_environment
```

### 3. Initialize Firebase

```bash
firebase login
firebase use --add  # Select your Firebase project
```

### 4. Deploy

```bash
# Deploy everything
firebase deploy

# Deploy only functions
firebase deploy --only functions

# Deploy only rules
firebase deploy --only firestore:rules,storage:rules
```

## Development

### Run Local Emulators

```bash
firebase emulators:start
```

Access emulator UI at: http://localhost:4000

### Test Functions Locally

```bash
cd functions
npm test
```

### Build Functions

```bash
cd functions
npm run build
```

## Cloud Functions

### Notifications
- `sendMessageNotification` - Push notification for new messages
- `sendCallNotification` - Push notification for incoming calls
- `sendFriendRequestNotification` - Push notification for friend requests

### AI Features
- `translateMessage` - Translate message to target language
- `chatWithAssistant` - AI assistant conversation
- `transcribeVoiceMessage` - Voice-to-text transcription
- `generateMessageEmbedding` - Create embeddings for RAG
- `semanticSearch` - Semantic search over messages

### Utility
- `healthCheck` - Check function deployment status
- `getConfig` - Verify environment configuration

## Security

- API keys stored in environment variables (never in code)
- Firestore rules enforce user permissions
- Storage rules limit file types and sizes
- Cloud Functions verify authentication

## Monitoring

View logs:
```bash
firebase functions:log
```

View specific function:
```bash
firebase functions:log --only sendMessageNotification
```

## Troubleshooting

### Functions not deploying
- Check Node.js version: `node --version` (should be 18)
- Verify Firebase CLI: `firebase --version`
- Build functions: `cd functions && npm run build`

### Missing environment variables
- Check `functions/.env` exists
- Ensure API keys are valid
- Redeploy: `firebase deploy --only functions`

### Firestore permission errors
- Verify security rules: `firebase.rules`
- Test rules in Firebase Console
- Check authentication token

## Cost Management

### Free Tier Limits
- Functions: 2M invocations/month
- Firestore: 50k reads, 20k writes/day
- Storage: 1GB, 50k downloads/day

### Optimize Costs
- Enable function caching
- Use Firestore indexes
- Implement rate limiting
- Cache translations and embeddings

## Documentation

- [Firebase Functions Docs](https://firebase.google.com/docs/functions)
- [Firestore Docs](https://firebase.google.com/docs/firestore)
- [Storage Docs](https://firebase.google.com/docs/storage)


