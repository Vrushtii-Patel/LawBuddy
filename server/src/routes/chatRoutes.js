const express = require('express');
const router = express.Router();
const llmService = require('../services/llmService');
const ChatSession = require('../models/ChatSession');
const { requireAuth } = require('../middleware/authMiddleware');

// 1. Send chat message & persist to a ChatSession for authenticated user
router.post('/chat', requireAuth, async (req, res) => {
    try {
        const { history, sessionId } = req.body;
        if (!history || !Array.isArray(history) || history.length === 0) {
            return res.status(400).json({ error: 'History array is required' });
        }

        const response = await llmService.chat(history);
        const userId = req.user.userId;

        let activeSessionId = sessionId;

        // Auto-persist / update session if requested or if sessionId exists
        try {
            const latestUserMsg = history[history.length - 1];
            const replyMsg = {
                role: 'ai',
                text: response.reply,
                suggestions: response.suggestions || [],
                sources: response.sources || [],
                time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
            };

            if (activeSessionId) {
                const existingSession = await ChatSession.findOne({ _id: activeSessionId, userId });
                if (existingSession) {
                    existingSession.messages.push({
                        role: 'user',
                        text: latestUserMsg.text,
                        time: latestUserMsg.time || new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                    });
                    existingSession.messages.push(replyMsg);
                    existingSession.updatedAt = new Date();
                    await existingSession.save();
                }
            } else {
                // Generate a brief descriptive title from the first message
                let title = latestUserMsg.text.trim();
                if (title.length > 40) {
                    title = title.substring(0, 37) + '...';
                }

                const newSession = new ChatSession({
                    userId,
                    title: title || 'Legal Consultation',
                    messages: [
                        {
                            role: 'user',
                            text: latestUserMsg.text,
                            time: latestUserMsg.time || new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                        },
                        replyMsg
                    ]
                });
                const saved = await newSession.save();
                activeSessionId = saved._id.toString();
            }
        } catch (dbErr) {
            console.warn('Failed to save chat session to DB (continuing anyway):', dbErr.message);
        }

        res.json({
            ...response,
            sessionId: activeSessionId
        });
    } catch (error) {
        console.error('Error in chat:', error);
        if (error.status === 429) {
            return res.status(429).json({ error: 'Rate limit reached. Please wait a moment before sending another message.' });
        }
        res.status(500).json({ error: 'Failed to process chat', details: error.message });
    }
});

// 2. Get all chat sessions for user
router.get('/chat/sessions', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const sessions = await ChatSession.find({ userId })
            .sort({ updatedAt: -1 })
            .select('_id title messages updatedAt createdAt')
            .limit(50);

        const formatted = sessions.map(s => {
            const lastMsg = s.messages && s.messages.length > 0 ? s.messages[s.messages.length - 1] : null;
            return {
                id: s._id,
                title: s.title,
                messageCount: s.messages ? s.messages.length : 0,
                lastSnippet: lastMsg ? (lastMsg.text.length > 75 ? lastMsg.text.substring(0, 72) + '...' : lastMsg.text) : '',
                updatedAt: s.updatedAt,
                createdAt: s.createdAt
            };
        });

        res.json(formatted);
    } catch (error) {
        console.error('Error fetching chat sessions:', error);
        res.status(500).json({ error: 'Failed to fetch chat sessions' });
    }
});

// 3. Get single chat session with full message history
router.get('/chat/sessions/:id', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const session = await ChatSession.findOne({ _id: req.params.id, userId });
        if (!session) {
            return res.status(404).json({ error: 'Chat session not found' });
        }
        res.json({
            id: session._id,
            title: session.title,
            messages: session.messages,
            updatedAt: session.updatedAt,
            createdAt: session.createdAt
        });
    } catch (error) {
        console.error('Error fetching single chat session:', error);
        res.status(500).json({ error: 'Failed to fetch session' });
    }
});

// 4. Delete a chat session
router.delete('/chat/sessions/:id', requireAuth, async (req, res) => {
    try {
        const userId = req.user.userId;
        const result = await ChatSession.deleteOne({ _id: req.params.id, userId });
        if (result.deletedCount === 0) {
            return res.status(404).json({ error: 'Session not found or already deleted' });
        }
        res.json({ message: 'Chat session deleted successfully' });
    } catch (error) {
        console.error('Error deleting chat session:', error);
        res.status(500).json({ error: 'Failed to delete session' });
    }
});

module.exports = router;
