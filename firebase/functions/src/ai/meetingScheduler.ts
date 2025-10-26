/**
 * Phase 18: Timezone Coordination
 * Meeting time suggestion with timezone awareness
 */

import * as functions from "firebase-functions";
import { OpenAI } from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

interface Participant {
  userId: string;
  timezone: string;
  workingHours?: {
    start: string; // "09:00"
    end: string; // "17:00"
    days: string[]; // ["Mon", "Tue", "Wed", "Thu", "Fri"]
  };
}

interface MeetingTimeRequest {
  participants: Participant[];
  duration: number; // in minutes
  preferredDates?: string[]; // ISO 8601 date strings
  onlyWorkingHours?: boolean;
}

interface MeetingTimeResponse {
  suggestions: Array<{
    startTime: string; // ISO 8601
    endTime: string; // ISO 8601
    participantAvailability: Record<string, "available" | "outside_hours" | "unknown">;
    score: number;
    reasoning: string;
  }>;
}

/**
 * Suggest meeting times based on participant timezones and working hours
 */
export const suggestMeetingTimes = functions.https.onCall(
  async (data: MeetingTimeRequest, context): Promise<MeetingTimeResponse> => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const {
      participants,
      duration,
      preferredDates = [],
      onlyWorkingHours = true,
    } = data;

    // Validation
    if (!participants || participants.length < 2) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "At least 2 participants required"
      );
    }

    if (!duration || duration < 15 || duration > 480) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Duration must be between 15 and 480 minutes"
      );
    }

    try {
      // Generate time slots based on constraints
      const timeSlots = generateTimeSlots(
        participants,
        duration,
        preferredDates,
        onlyWorkingHours
      );

      // Use GPT-4o to rank and provide reasoning for suggestions
      const rankedSuggestions = await rankMeetingTimes(
        timeSlots,
        participants,
        duration
      );

      return {
        suggestions: rankedSuggestions,
      };
    } catch (error) {
      console.error("Error suggesting meeting times:", error);
      throw new functions.https.HttpsError(
        "internal",
        `Failed to suggest meeting times: ${error}`
      );
    }
  }
);

/**
 * Generate potential time slots based on participants' availability
 */
function generateTimeSlots(
  participants: Participant[],
  duration: number,
  preferredDates: string[],
  onlyWorkingHours: boolean
): Array<{
  startTime: Date;
  endTime: Date;
  participantAvailability: Record<string, "available" | "outside_hours" | "unknown">;
}> {
  const slots: Array<{
    startTime: Date;
    endTime: Date;
    participantAvailability: Record<string, "available" | "outside_hours" | "unknown">;
  }> = [];

  // Generate date range (next 7 days if no preferred dates)
  const dates: Date[] = [];
  if (preferredDates.length > 0) {
    preferredDates.forEach((dateStr) => {
      const date = new Date(dateStr);
      if (!isNaN(date.getTime())) {
        dates.push(date);
      }
    });
  } else {
    // Default: next 7 days
    for (let i = 1; i <= 7; i++) {
      const date = new Date();
      date.setDate(date.getDate() + i);
      dates.push(date);
    }
  }

  // For each date, generate potential time slots
  dates.forEach((date) => {
    // Try different hours (9 AM to 5 PM in UTC as baseline)
    for (let hour = 9; hour <= 17; hour++) {
      const startTime = new Date(date);
      startTime.setHours(hour, 0, 0, 0);

      const endTime = new Date(startTime);
      endTime.setMinutes(endTime.getMinutes() + duration);

      // Check if this time works for all participants
      const availability: Record<string, "available" | "outside_hours" | "unknown"> = {};
      let allAvailable = true;

      participants.forEach((participant) => {
        const status = checkAvailability(
          participant,
          startTime,
          endTime,
          onlyWorkingHours
        );
        availability[participant.userId] = status;

        if (onlyWorkingHours && status !== "available") {
          allAvailable = false;
        }
      });

      // Add slot if it meets criteria
      if (!onlyWorkingHours || allAvailable) {
        slots.push({
          startTime,
          endTime,
          participantAvailability: availability,
        });
      }
    }
  });

  return slots;
}

/**
 * Check if a participant is available at a given time
 */
function checkAvailability(
  participant: Participant,
  startTime: Date,
  endTime: Date,
  strictWorkingHours: boolean
): "available" | "outside_hours" | "unknown" {
  if (!participant.workingHours) {
    return strictWorkingHours ? "unknown" : "available";
  }

  // Convert time to participant's timezone
  const participantTime = convertToTimezone(startTime, participant.timezone);

  // Get day of week
  const daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const dayName = daysOfWeek[participantTime.getDay()];

  // Check if it's a working day
  if (!participant.workingHours.days.includes(dayName)) {
    return "outside_hours";
  }

  // Check if it's within working hours
  const hours = participantTime.getHours();
  const minutes = participantTime.getMinutes();
  const currentMinutes = hours * 60 + minutes;

  const [startHour, startMinute] = participant.workingHours.start.split(":").map(Number);
  const [endHour, endMinute] = participant.workingHours.end.split(":").map(Number);

  const workStartMinutes = startHour * 60 + startMinute;
  const workEndMinutes = endHour * 60 + endMinute;

  if (currentMinutes >= workStartMinutes && currentMinutes < workEndMinutes) {
    return "available";
  } else {
    return "outside_hours";
  }
}

/**
 * Convert time to a specific timezone (simplified)
 */
function convertToTimezone(date: Date, timezone: string): Date {
  // This is a simplified conversion
  // In production, use a library like moment-timezone or date-fns-tz
  const utcTime = date.getTime();
  const utcOffset = date.getTimezoneOffset() * 60000;
  const utcDate = new Date(utcTime + utcOffset);

  // Get timezone offset from Intl API
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });

  const parts = formatter.formatToParts(utcDate);
  const year = parseInt(parts.find((p) => p.type === "year")?.value || "0");
  const month = parseInt(parts.find((p) => p.type === "month")?.value || "0") - 1;
  const day = parseInt(parts.find((p) => p.type === "day")?.value || "0");
  const hour = parseInt(parts.find((p) => p.type === "hour")?.value || "0");
  const minute = parseInt(parts.find((p) => p.type === "minute")?.value || "0");

  return new Date(year, month, day, hour, minute);
}

/**
 * Use GPT-4o to rank meeting times and provide reasoning
 */
async function rankMeetingTimes(
  timeSlots: Array<{
    startTime: Date;
    endTime: Date;
    participantAvailability: Record<string, "available" | "outside_hours" | "unknown">;
  }>,
  participants: Participant[],
  duration: number
): Promise<Array<{
  startTime: string;
  endTime: string;
  participantAvailability: Record<string, "available" | "outside_hours" | "unknown">;
  score: number;
  reasoning: string;
}>> {
  if (timeSlots.length === 0) {
    return [];
  }

  // Take top 10 slots based on simple scoring
  const scoredSlots = timeSlots.map((slot) => {
    let score = 0;
    const availableCount = Object.values(slot.participantAvailability).filter(
      (status) => status === "available"
    ).length;

    // Prefer times when all participants are available
    score += availableCount * 10;

    // Prefer mid-morning and early afternoon times (10 AM - 2 PM UTC)
    const hour = slot.startTime.getUTCHours();
    if (hour >= 10 && hour <= 14) {
      score += 5;
    }

    // Prefer weekdays
    const day = slot.startTime.getUTCDay();
    if (day >= 1 && day <= 5) {
      score += 3;
    }

    return { ...slot, score };
  });

  // Sort by score and take top 10
  scoredSlots.sort((a, b) => b.score - a.score);
  const topSlots = scoredSlots.slice(0, 10);

  // Use GPT-4o to provide reasoning for top suggestions
  const prompt = `You are a meeting scheduler. Given the following meeting time options and participant information, provide concise reasoning for why each time is a good choice.

Meeting Duration: ${duration} minutes
Participants: ${participants.length}
Participant Timezones: ${participants.map((p) => p.timezone).join(", ")}

Time Slots (in UTC):
${topSlots.map((slot, idx) => {
    const available = Object.values(slot.participantAvailability).filter(
      (s) => s === "available"
    ).length;
    return `${idx + 1}. ${slot.startTime.toISOString()} - ${available}/${participants.length} participants available`;
  }).join("\n")}

For each time slot, provide a brief one-sentence reasoning (max 100 characters). Return as JSON array with format:
[{"index": 0, "reasoning": "..."}, ...]`;

  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        {
          role: "system",
          content: "You are a helpful meeting scheduler assistant. Provide concise, practical reasoning for meeting time suggestions.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
      temperature: 0.7,
      max_tokens: 500,
    });

    const content = response.choices[0]?.message?.content || "[]";
    
    // Try to parse JSON response
    let reasonings: Array<{ index: number; reasoning: string }> = [];
    try {
      // Extract JSON from markdown code blocks if present
      const jsonMatch = content.match(/```(?:json)?\s*(\[[\s\S]*?\])\s*```/);
      const jsonString = jsonMatch ? jsonMatch[1] : content;
      reasonings = JSON.parse(jsonString);
    } catch (parseError) {
      console.error("Failed to parse GPT reasoning:", parseError);
      // Fallback to generic reasoning
      reasonings = topSlots.map((_, idx) => ({
        index: idx,
        reasoning: "Good time for most participants",
      }));
    }

    // Combine slots with reasoning
    return topSlots.slice(0, 5).map((slot, idx) => {
      const reasoning = reasonings.find((r) => r.index === idx)?.reasoning ||
        "Convenient time for participants";

      return {
        startTime: slot.startTime.toISOString(),
        endTime: slot.endTime.toISOString(),
        participantAvailability: slot.participantAvailability,
        score: slot.score / 10, // Normalize score to 0-10
        reasoning,
      };
    });
  } catch (error) {
    console.error("Error getting GPT reasoning:", error);
    
    // Fallback: return slots with generic reasoning
    return topSlots.slice(0, 5).map((slot) => ({
      startTime: slot.startTime.toISOString(),
      endTime: slot.endTime.toISOString(),
      participantAvailability: slot.participantAvailability,
      score: slot.score / 10,
      reasoning: "Suitable time based on participant availability",
    }));
  }
}


