/**
 * Single source of truth for LLM pipeline metadata.
 *
 * Every value that gets stamped onto a Document/ScanJob record (so we can
 * later tell what actually generated a given analysis) lives here.
 *
 * IMPORTANT: this file must have zero require()s of its own models/services.
 * llmService.js requires ../models/Document, so if Document.js required
 * llmService.js back to read these constants, that would be a circular
 * dependency. Keeping this file dependency-free lets both sides import it
 * directly instead of hardcoding a second, driftable copy of the values.
 *
 * If you change the active model here, every place that reads it (the
 * generation pipeline, the embedding pipeline, and the Mongoose schema
 * defaults) picks it up automatically — there is nowhere else to update.
 */

// Generation pipeline
const MODEL_NAME = "gemini-3.5-flash-lite";
const MODEL_VERSION = "latest";
const PROMPT_VERSION = "v1.1.0";
const ANALYSIS_VERSION = "v1.1.0";
const TEMPERATURE = 0.0;

// Embedding pipeline (used for law-snippet retrieval / RAG)
// Must match the model used in scripts/ingestLaws.js when the embeddings
// were generated — changing this without re-ingesting will make stored
// vectors incomparable to freshly-generated query embeddings.
const EMBEDDING_MODEL_NAME = "gemini-embedding-2";

module.exports = {
    MODEL_NAME,
    MODEL_VERSION,
    PROMPT_VERSION,
    ANALYSIS_VERSION,
    TEMPERATURE,
    EMBEDDING_MODEL_NAME,
};
