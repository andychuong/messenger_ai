/**
 * Enhanced Data Extraction Cloud Function
 * 
 * Extracts structured data from conversations including:
 * - Events (meetings, appointments)
 * - Tasks and action items
 * - Dates and deadlines
 * - Locations and addresses
 * - Contact information
 * - Decisions
 * 
 * Supports multilingual extraction with timezone awareness.
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// ===== Types and Interfaces =====

interface Message {
  id: string;
  text: string;
  senderId: string;
  timestamp: string; // ISO 8601 format
  language?: string;
}

interface StructuredDataRequest {
  messages: Message[];
  conversationId: string;
  dataTypes?: DataType[];
  languages?: string[];
  userTimezone?: string;
}

type DataType = 'events' | 'tasks' | 'dates' | 'locations' | 'contacts' | 'decisions';

interface ExtractedEvent {
  title: string;
  date: string; // ISO format
  time?: string;
  endTime?: string;
  duration?: number; // in minutes
  location?: string;
  participants: string[];
  messageId: string;
  confidence: number;
  description?: string;
}

interface ExtractedTask {
  task: string;
  assignee?: string;
  deadline?: string;
  priority: 'high' | 'medium' | 'low';
  status: 'pending' | 'in_progress' | 'completed';
  messageId: string;
  confidence: number;
}

interface ExtractedDate {
  date: string; // ISO format
  context: string;
  type: 'deadline' | 'meeting' | 'reminder' | 'event' | 'reference';
  messageId: string;
  confidence: number;
}

interface ExtractedLocation {
  name: string;
  address?: string;
  coordinates?: { lat: number; lng: number };
  context: string;
  messageId: string;
  confidence: number;
}

interface ExtractedContact {
  name: string;
  phone?: string;
  email?: string;
  company?: string;
  context: string;
  messageId: string;
  confidence: number;
}

interface ExtractedDecision {
  decision: string;
  context: string;
  participants: string[];
  date: string;
  messageId: string;
  confidence: number;
}

interface StructuredDataResponse {
  events: ExtractedEvent[];
  tasks: ExtractedTask[];
  dates: ExtractedDate[];
  locations: ExtractedLocation[];
  contacts: ExtractedContact[];
  decisions: ExtractedDecision[];
  extractedAt: string;
  conversationId: string;
}

// ===== Helper Functions =====

/**
 * Build extraction prompt for GPT-4o
 */
function buildExtractionPrompt(
  messages: Message[],
  dataTypes: DataType[],
  userTimezone: string
): string {
  const conversationText = messages.map((msg, idx) => 
    `[Message ${idx + 1} - ${msg.timestamp}]\n${msg.text}`
  ).join('\n\n');

  return `You are an expert at extracting structured data from conversations. 
Analyze the following conversation and extract: ${dataTypes.join(', ')}.

User's Timezone: ${userTimezone}
Current Date/Time: ${new Date().toISOString()}

Conversation:
${conversationText}

Extract all relevant information with high confidence. For dates and times:
- Convert relative dates (today, tomorrow, next week) to absolute dates
- Use ISO 8601 format for dates and times
- Consider the user's timezone: ${userTimezone}
- If no specific time is mentioned, extract only the date

For each extracted item:
- Provide a confidence score (0.0-1.0)
- Include the message index it came from
- Extract all relevant context

Be precise and only extract information explicitly mentioned or clearly implied.`;
}

/**
 * Extract structured data using GPT-4o function calling
 */
async function extractWithGPT(
  messages: Message[],
  dataTypes: DataType[],
  userTimezone: string = 'UTC'
): Promise<Partial<StructuredDataResponse>> {
  const prompt = buildExtractionPrompt(messages, dataTypes, userTimezone);

  const tools: OpenAI.Chat.ChatCompletionTool[] = [];

  // Define functions for each data type
  if (dataTypes.includes('events')) {
    tools.push({
      type: 'function',
      function: {
        name: 'extract_events',
        description: 'Extract events, meetings, and appointments from the conversation',
        parameters: {
          type: 'object',
          properties: {
            events: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  title: { type: 'string', description: 'Event title or name' },
                  date: { type: 'string', description: 'Event date in ISO 8601 format' },
                  time: { type: 'string', description: 'Event start time (HH:MM format)' },
                  endTime: { type: 'string', description: 'Event end time (HH:MM format)' },
                  duration: { type: 'number', description: 'Duration in minutes' },
                  location: { type: 'string', description: 'Event location' },
                  participants: { type: 'array', items: { type: 'string' } },
                  description: { type: 'string', description: 'Event description or notes' },
                  messageIndex: { type: 'number' },
                  confidence: { type: 'number', minimum: 0, maximum: 1 },
                },
                required: ['title', 'date', 'messageIndex', 'confidence'],
              },
            },
          },
          required: ['events'],
        },
      },
    });
  }

  if (dataTypes.includes('tasks')) {
    tools.push({
      type: 'function',
      function: {
        name: 'extract_tasks',
        description: 'Extract tasks, action items, and to-dos from the conversation',
        parameters: {
          type: 'object',
          properties: {
            tasks: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  task: { type: 'string', description: 'Task description' },
                  assignee: { type: 'string', description: 'Person assigned to the task' },
                  deadline: { type: 'string', description: 'Task deadline in ISO 8601 format' },
                  priority: { type: 'string', enum: ['high', 'medium', 'low'] },
                  status: { type: 'string', enum: ['pending', 'in_progress', 'completed'] },
                  messageIndex: { type: 'number' },
                  confidence: { type: 'number', minimum: 0, maximum: 1 },
                },
                required: ['task', 'priority', 'status', 'messageIndex', 'confidence'],
              },
            },
          },
          required: ['tasks'],
        },
      },
    });
  }

  if (dataTypes.includes('dates')) {
    tools.push({
      type: 'function',
      function: {
        name: 'extract_dates',
        description: 'Extract dates, deadlines, and time references from the conversation',
        parameters: {
          type: 'object',
          properties: {
            dates: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  date: { type: 'string', description: 'Date in ISO 8601 format' },
                  context: { type: 'string', description: 'Context around the date mention' },
                  type: { type: 'string', enum: ['deadline', 'meeting', 'reminder', 'event', 'reference'] },
                  messageIndex: { type: 'number' },
                  confidence: { type: 'number', minimum: 0, maximum: 1 },
                },
                required: ['date', 'context', 'type', 'messageIndex', 'confidence'],
              },
            },
          },
          required: ['dates'],
        },
      },
    });
  }

  if (dataTypes.includes('locations')) {
    tools.push({
      type: 'function',
      function: {
        name: 'extract_locations',
        description: 'Extract locations, addresses, and places from the conversation',
        parameters: {
          type: 'object',
          properties: {
            locations: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  name: { type: 'string', description: 'Location name' },
                  address: { type: 'string', description: 'Full address if available' },
                  context: { type: 'string', description: 'Context around the location mention' },
                  messageIndex: { type: 'number' },
                  confidence: { type: 'number', minimum: 0, maximum: 1 },
                },
                required: ['name', 'context', 'messageIndex', 'confidence'],
              },
            },
          },
          required: ['locations'],
        },
      },
    });
  }

  if (dataTypes.includes('contacts')) {
    tools.push({
      type: 'function',
      function: {
        name: 'extract_contacts',
        description: 'Extract contact information (names, emails, phone numbers) from the conversation',
        parameters: {
          type: 'object',
          properties: {
            contacts: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  name: { type: 'string', description: 'Contact name' },
                  phone: { type: 'string', description: 'Phone number' },
                  email: { type: 'string', description: 'Email address' },
                  company: { type: 'string', description: 'Company or organization' },
                  context: { type: 'string', description: 'Context around the contact mention' },
                  messageIndex: { type: 'number' },
                  confidence: { type: 'number', minimum: 0, maximum: 1 },
                },
                required: ['name', 'context', 'messageIndex', 'confidence'],
              },
            },
          },
          required: ['contacts'],
        },
      },
    });
  }

  if (dataTypes.includes('decisions')) {
    tools.push({
      type: 'function',
      function: {
        name: 'extract_decisions',
        description: 'Extract decisions, agreements, and conclusions from the conversation',
        parameters: {
          type: 'object',
          properties: {
            decisions: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  decision: { type: 'string', description: 'The decision made' },
                  context: { type: 'string', description: 'Context and reasoning' },
                  participants: { type: 'array', items: { type: 'string' } },
                  messageIndex: { type: 'number' },
                  confidence: { type: 'number', minimum: 0, maximum: 1 },
                },
                required: ['decision', 'context', 'messageIndex', 'confidence'],
              },
            },
          },
          required: ['decisions'],
        },
      },
    });
  }

  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o-2024-08-06',
      messages: [
        {
          role: 'system',
          content: 'You are an expert data extraction assistant. Extract structured information accurately and provide confidence scores.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      tools: tools,
      tool_choice: 'auto',
      temperature: 0.1, // Low temperature for consistent extraction
    });

    const result: Partial<StructuredDataResponse> = {
      events: [],
      tasks: [],
      dates: [],
      locations: [],
      contacts: [],
      decisions: [],
    };

    // Parse tool calls
    const toolCalls = response.choices[0].message.tool_calls || [];
    
    for (const toolCall of toolCalls) {
      if (toolCall.type === 'function') {
        const functionName = toolCall.function.name;
        const args = JSON.parse(toolCall.function.arguments);

        switch (functionName) {
          case 'extract_events':
            result.events = args.events.map((event: any) => ({
              ...event,
              participants: event.participants || [],
              messageId: messages[event.messageIndex]?.id || '',
            }));
            break;
          case 'extract_tasks':
            result.tasks = args.tasks.map((task: any) => ({
              ...task,
              messageId: messages[task.messageIndex]?.id || '',
            }));
            break;
          case 'extract_dates':
            result.dates = args.dates.map((date: any) => ({
              ...date,
              messageId: messages[date.messageIndex]?.id || '',
            }));
            break;
          case 'extract_locations':
            result.locations = args.locations.map((location: any) => ({
              ...location,
              messageId: messages[location.messageIndex]?.id || '',
            }));
            break;
          case 'extract_contacts':
            result.contacts = args.contacts.map((contact: any) => ({
              ...contact,
              messageId: messages[contact.messageIndex]?.id || '',
            }));
            break;
          case 'extract_decisions':
            result.decisions = args.decisions.map((decision: any) => ({
              ...decision,
              date: new Date().toISOString(),
              messageId: messages[decision.messageIndex]?.id || '',
            }));
            break;
        }
      }
    }

    return result;
  } catch (error) {
    console.error('Error extracting data with GPT:', error);
    throw new functions.https.HttpsError('internal', 'Failed to extract data');
  }
}

/**
 * Geocode location to get coordinates
 */
async function geocodeLocation(location: ExtractedLocation): Promise<ExtractedLocation> {
  // In production, integrate with Google Maps Geocoding API
  // For now, return location as-is
  // TODO: Add Google Maps API integration
  return location;
}

/**
 * Deduplicate extracted data
 */
function deduplicateData<T extends { confidence: number }>(
  items: T[],
  compareFn: (a: T, b: T) => boolean
): T[] {
  const deduplicated: T[] = [];

  for (const item of items) {
    const existing = deduplicated.find(d => compareFn(d, item));
    if (!existing) {
      deduplicated.push(item);
    } else if (item.confidence > existing.confidence) {
      // Replace with higher confidence version
      const index = deduplicated.indexOf(existing);
      deduplicated[index] = item;
    }
  }

  return deduplicated;
}

/**
 * Deduplicate events
 */
function deduplicateEvents(events: ExtractedEvent[]): ExtractedEvent[] {
  return deduplicateData(events, (a, b) => 
    a.title.toLowerCase() === b.title.toLowerCase() &&
    a.date === b.date &&
    a.time === b.time
  );
}

/**
 * Deduplicate tasks
 */
function deduplicateTasks(tasks: ExtractedTask[]): ExtractedTask[] {
  return deduplicateData(tasks, (a, b) => 
    a.task.toLowerCase().includes(b.task.toLowerCase()) ||
    b.task.toLowerCase().includes(a.task.toLowerCase())
  );
}

/**
 * Deduplicate locations
 */
function deduplicateLocations(locations: ExtractedLocation[]): ExtractedLocation[] {
  return deduplicateData(locations, (a, b) => {
    if (a.name.toLowerCase() === b.name.toLowerCase()) return true;
    if (a.address && b.address && a.address.toLowerCase() === b.address.toLowerCase()) return true;
    return false;
  });
}

/**
 * Deduplicate contacts
 */
function deduplicateContacts(contacts: ExtractedContact[]): ExtractedContact[] {
  return deduplicateData(contacts, (a, b) => {
    if (a.name.toLowerCase() === b.name.toLowerCase()) return true;
    if (a.email && b.email && a.email.toLowerCase() === b.email.toLowerCase()) return true;
    if (a.phone && b.phone && a.phone === b.phone) return true;
    return false;
  });
}

// ===== Main Cloud Function =====

/**
 * Extract structured data from conversation messages
 * 
 * Supports multilingual extraction with timezone awareness
 */
export const extractStructuredData = functions.https.onCall(
  async (data: StructuredDataRequest, context) => {
    // Authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated'
      );
    }

    const {
      messages,
      conversationId,
      dataTypes = ['events', 'tasks', 'dates', 'locations', 'contacts', 'decisions'],
      userTimezone = 'UTC',
    } = data;

    if (!messages || messages.length === 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Messages array is required and must not be empty'
      );
    }

    if (!conversationId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'conversationId is required'
      );
    }

    try {
      // Extract data using GPT-4o
      const extractedData = await extractWithGPT(messages, dataTypes, userTimezone);

      // Deduplicate extracted data
      const deduplicatedData: StructuredDataResponse = {
        events: deduplicateEvents(extractedData.events || []),
        tasks: deduplicateTasks(extractedData.tasks || []),
        dates: extractedData.dates || [],
        locations: deduplicateLocations(extractedData.locations || []),
        contacts: deduplicateContacts(extractedData.contacts || []),
        decisions: extractedData.decisions || [],
        extractedAt: new Date().toISOString(),
        conversationId,
      };

      // Geocode locations (if needed)
      if (deduplicatedData.locations.length > 0) {
        deduplicatedData.locations = await Promise.all(
          deduplicatedData.locations.map(loc => geocodeLocation(loc))
        );
      }

      // Store in Firestore
      const db = admin.firestore();
      await db
        .collection('conversations')
        .doc(conversationId)
        .collection('extractedData')
        .doc('latest')
        .set({
          ...deduplicatedData,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      return deduplicatedData;
    } catch (error) {
      console.error('Error extracting structured data:', error);
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      throw new functions.https.HttpsError(
        'internal',
        `Failed to extract structured data: ${errorMessage}`
      );
    }
  }
);

/**
 * Auto-extract data when conversation is updated
 * Triggered when new messages are added
 */
export const autoExtractData = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const conversationId = context.params.conversationId;
    const db = admin.firestore();

    try {
      // Get last extraction timestamp
      const extractedDataDoc = await db
        .collection('conversations')
        .doc(conversationId)
        .collection('extractedData')
        .doc('latest')
        .get();

      const lastExtracted = extractedDataDoc.exists
        ? extractedDataDoc.data()?.updatedAt?.toDate()
        : new Date(0);

      // Only extract if last extraction was more than 5 minutes ago
      const now = new Date();
      const timeSinceLastExtraction = now.getTime() - lastExtracted.getTime();
      const FIVE_MINUTES = 5 * 60 * 1000;

      if (timeSinceLastExtraction < FIVE_MINUTES) {
        return;
      }

      // Get recent messages (last 50)
      const messagesSnapshot = await db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', 'desc')
        .limit(50)
        .get();

      const messages = messagesSnapshot.docs
        .map(doc => ({
          id: doc.id,
          ...doc.data(),
        }))
        .reverse(); // Chronological order

      if (messages.length === 0) {
        return;
      }

      // Extract data
      const extractedData = await extractWithGPT(
        messages as Message[],
        ['events', 'tasks', 'dates', 'locations', 'contacts', 'decisions'],
        'UTC' // Use UTC for auto-extraction, will be converted on client
      );

      // Store results
      await db
        .collection('conversations')
        .doc(conversationId)
        .collection('extractedData')
        .doc('latest')
        .set({
          ...extractedData,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    } catch (error) {
      console.error(`Error auto-extracting data for ${conversationId}:`, error);
      // Don't throw - this is a background operation
    }
  });

