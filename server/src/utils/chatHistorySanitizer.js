const MAX_HISTORY_TURNS = 30;
const MAX_MESSAGE_CHARS = 8000;
const MAX_TOTAL_CHARS = 50000;

class ChatHistoryError extends Error {
    constructor(message, statusCode = 400) {
        super(message);
        this.name = 'ChatHistoryError';
        this.statusCode = statusCode;
        this.status = statusCode;
    }
}

/**
 * Validates and sanitizes chat history before passing to AI models or saving to database:
 * 1. Validates array structure and non-empty content.
 * 2. Normalizes roles ('user' or 'ai'), discarding unknown/invalid roles (e.g. 'error').
 * 3. Enforces length caps per message and overall window.
 * 4. Merges consecutive same-role turns into single turns to preserve strict turn alternation.
 * 5. Ensures history starts with a 'user' turn and ends with a 'user' turn.
 */
function sanitizeChatHistory(rawHistory, options = {}) {
    const maxTurns = options.maxTurns || MAX_HISTORY_TURNS;
    const maxChars = options.maxMessageChars || MAX_MESSAGE_CHARS;
    const maxTotalChars = options.maxTotalChars || MAX_TOTAL_CHARS;

    if (!rawHistory || !Array.isArray(rawHistory) || rawHistory.length === 0) {
        throw new ChatHistoryError('History must be a non-empty array of messages');
    }

    // 1. Filter, sanitize content and normalize roles
    const cleaned = [];
    for (const item of rawHistory) {
        if (!item || typeof item !== 'object') continue;
        const rawText = typeof item.text === 'string' ? item.text.trim() : '';
        if (!rawText) continue;

        let role = typeof item.role === 'string' ? item.role.toLowerCase().trim() : '';
        if (role === 'ai' || role === 'model' || role === 'assistant') {
            role = 'ai';
        } else if (role === 'user') {
            role = 'user';
        } else {
            // Discard invalid or client-internal roles like 'error' or 'system'
            continue;
        }

        const text = rawText.length > maxChars ? rawText.substring(0, maxChars) : rawText;
        cleaned.push({
            role,
            text,
            time: typeof item.time === 'string' ? item.time : undefined
        });
    }

    if (cleaned.length === 0) {
        throw new ChatHistoryError('History must contain at least one valid message with text');
    }

    // 2. Merge consecutive turns with the same role
    const merged = [];
    for (const msg of cleaned) {
        if (merged.length > 0 && merged[merged.length - 1].role === msg.role) {
            const prev = merged[merged.length - 1];
            const combined = `${prev.text}\n\n${msg.text}`;
            prev.text = combined.length > maxChars * 2 ? combined.substring(0, maxChars * 2) : combined;
            if (msg.time) prev.time = msg.time;
        } else {
            merged.push({ ...msg });
        }
    }

    // 3. History for Gemini must start with a 'user' turn
    while (merged.length > 0 && merged[0].role !== 'user') {
        merged.shift();
    }

    if (merged.length === 0) {
        throw new ChatHistoryError('History must contain at least one user message');
    }

    // 4. The latest turn (which is the user's active query) must be from 'user'
    if (merged[merged.length - 1].role !== 'user') {
        throw new ChatHistoryError('The latest message in history must be from the user');
    }

    // 5. Cap total turns to maxTurns (keep the most recent turns)
    let windowed = merged;
    if (windowed.length > maxTurns) {
        windowed = windowed.slice(-maxTurns);
        // If slicing broke the alternating start, strip leading AI turn
        while (windowed.length > 0 && windowed[0].role !== 'user') {
            windowed.shift();
        }
    }

    // 6. Ensure total character budget
    let totalChars = 0;
    for (const msg of windowed) {
        totalChars += msg.text.length;
    }
    if (totalChars > maxTotalChars) {
        // If total characters still exceed max budget, trim older turns until under budget
        while (windowed.length > 1 && totalChars > maxTotalChars) {
            const removed = windowed.shift();
            totalChars -= removed.text.length;
            while (windowed.length > 0 && windowed[0].role !== 'user') {
                const extra = windowed.shift();
                totalChars -= extra.text.length;
            }
        }
    }

    if (windowed.length === 0 || windowed[windowed.length - 1].role !== 'user') {
        throw new ChatHistoryError('Unable to produce valid user message within length budget');
    }

    return windowed;
}

module.exports = {
    sanitizeChatHistory,
    ChatHistoryError,
    MAX_HISTORY_TURNS,
    MAX_MESSAGE_CHARS,
    MAX_TOTAL_CHARS
};
