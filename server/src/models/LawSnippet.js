const mongoose = require('mongoose');

const lawSnippetSchema = new mongoose.Schema({
    text: {
        type: String,
        required: true,
    },
    document: {
        type: String,
        required: true,
        default: 'Statutory Law',
    },
    actOrRule: {
        type: String,
        default: 'Act',
    },
    section: {
        type: String,
        default: null,
    },
    subsection: {
        type: String,
        default: null,
    },
    rule: {
        type: String,
        default: null,
    },
    title: {
        type: String,
        default: null,
    },
    jurisdiction: {
        type: String,
        default: 'India',
    },
    authority: {
        type: String,
        default: 'India Code',
    },
    sourceUrl: {
        type: String,
        default: null,
    },
    source: {
        type: String,
        default: 'Indian Property Laws & Statutory References',
    },
    // Stable identity for this entry, derived from document+section+subsection+rule+title.
    // Lets the ingestion script tell "this is the same provision, possibly re-embedded"
    // apart from "this is a new provision", instead of wiping and reloading everything
    // on every run.
    sourceKey: {
        type: String,
        default: null,
        index: true,
    },
    embedding: {
        type: [Number],
        required: true,
    }
}, { timestamps: true });

module.exports = mongoose.model('LawSnippet', lawSnippetSchema);