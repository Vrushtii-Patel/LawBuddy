const mongoose = require('mongoose');

const chatMessageSchema = new mongoose.Schema({
    role: { type: String, required: true }, // 'user', 'ai', 'error'
    text: { type: String, required: true },
    time: { type: String },
    suggestions: [{ type: String }],
    sources: [{ type: mongoose.Schema.Types.Mixed }]
}, { _id: false });

const chatSessionSchema = new mongoose.Schema({
    userId: { type: String, required: true, index: true },
    title: { type: String, required: true },
    messages: [chatMessageSchema]
}, { timestamps: true });

module.exports = mongoose.model('ChatSession', chatSessionSchema);
