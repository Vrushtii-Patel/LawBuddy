const multer = require('multer');
const path = require('path');

// 30 MB maximum file size limit
const MAX_FILE_SIZE = 30 * 1024 * 1024;

const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'application/x-pdf',
  'application/acrobat',
  'applications/vnd.pdf',
  'text/pdf',
  'text/x-pdf',
  'application/octet-stream',
  'binary/octet-stream',
  'image/jpeg',
  'image/jpg',
  'image/pjpeg',
  'image/png',
  'image/x-png',
  'image/webp'
]);

const ALLOWED_EXTENSIONS = new Set([
  '.pdf',
  '.jpg',
  '.jpeg',
  '.png',
  '.webp'
]);

/**
 * Validates actual binary signature (magic bytes) of the uploaded buffer.
 * Rejects disguised files (e.g., .exe renamed to .pdf).
 */
function validateFileSignature(buffer, mimeType = '', ext = '') {
  if (!buffer || buffer.length < 4) return false;

  const mime = (mimeType || '').toLowerCase();
  const extension = (ext || '').toLowerCase();

  // Search header chunk (up to first 1024 bytes) for format markers
  const headerSlice = buffer.subarray(0, Math.min(buffer.length, 1024));
  const headerString = headerSlice.toString('latin1');

  // PDF signature: '%PDF' in the first 1024 bytes (per ISO 32000-1 specification)
  if (extension === '.pdf' || mime.includes('pdf') || mime.includes('octet-stream') || mime === '') {
    if (headerString.includes('%PDF')) {
      return true;
    }
  }

  // JPEG signature: FF D8 FF
  if (extension === '.jpg' || extension === '.jpeg' || mime.includes('jpeg') || mime.includes('jpg') || mime.includes('octet-stream')) {
    if (buffer.length >= 3 && buffer[0] === 0xFF && buffer[1] === 0xD8 && buffer[2] === 0xFF) {
      return true;
    }
  }

  // PNG signature: 89 50 4E 47 0D 0A 1A 0A
  if (extension === '.png' || mime.includes('png') || mime.includes('octet-stream')) {
    if (
      buffer.length >= 8 &&
      buffer[0] === 0x89 &&
      buffer[1] === 0x50 &&
      buffer[2] === 0x4E &&
      buffer[3] === 0x47 &&
      buffer[4] === 0x0D &&
      buffer[5] === 0x0A &&
      buffer[6] === 0x1A &&
      buffer[7] === 0x0A
    ) {
      return true;
    }
  }

  // WebP signature: RIFF....WEBP (0x52 0x49 0x46 0x46 ... 0x57 0x45 0x42 0x50)
  if (extension === '.webp' || mime.includes('webp') || mime.includes('octet-stream')) {
    if (buffer.length >= 12) {
      const isRiff = buffer[0] === 0x52 && buffer[1] === 0x49 && buffer[2] === 0x46 && buffer[3] === 0x46;
      const isWebp = buffer[8] === 0x57 && buffer[9] === 0x45 && buffer[10] === 0x42 && buffer[11] === 0x50;
      if (isRiff && isWebp) return true;
    }
  }

  // Fallback: If header contains %PDF anywhere in first 1024 bytes, accept as valid PDF
  if (headerString.includes('%PDF')) {
    return true;
  }

  return false;
}

// In-memory storage: prevents orphaned temporary files while allowing instant SHA-256 computation
const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 1
  },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const mime = (file.mimetype || '').toLowerCase();

    // Accept if either extension is valid or MIME type is recognized
    if (ALLOWED_EXTENSIONS.has(ext) || ALLOWED_MIME_TYPES.has(mime) || mime.includes('pdf') || mime.includes('image')) {
      return cb(null, true);
    }

    const err = new Error('UNSUPPORTED_FILE_TYPE');
    err.code = 'UNSUPPORTED_FILE_TYPE';
    return cb(err, false);
  }
});

/**
 * Middleware for document file uploads ('document' field).
 * Supports both multipart/form-data with a file and standard JSON requests (when no file is uploaded).
 */
function uploadDocument(req, res, next) {
  const contentType = (req.headers['content-type'] || '').toLowerCase();

  // If request is JSON, bypass Multer and let express.json() handle it
  if (contentType.includes('application/json')) {
    return next();
  }

  upload.single('document')(req, res, (err) => {
    if (err) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({
          error: 'This document is too large. Please upload a smaller file.'
        });
      }
      if (err.code === 'UNSUPPORTED_FILE_TYPE' || err.message === 'UNSUPPORTED_FILE_TYPE') {
        return res.status(400).json({
          error: 'This file type is not supported. Please upload a PDF or supported image.'
        });
      }
      return res.status(400).json({
        error: 'Unable to upload the document. Please check your connection and try again.'
      });
    }

    // If a file was uploaded, perform binary magic byte signature verification
    if (req.file && req.file.buffer) {
      const ext = path.extname(req.file.originalname || '').toLowerCase();
      const mime = (req.file.mimetype || '').toLowerCase();

      const isValidSignature = validateFileSignature(req.file.buffer, mime, ext);
      if (!isValidSignature) {
        console.warn(`[Upload Rejected] Invalid file signature for file: ${req.file.originalname}, MIME: ${mime}`);
        return res.status(400).json({
          error: 'This file type is not supported. Please upload a PDF or supported image.'
        });
      }
    }

    next();
  });
}

module.exports = {
  uploadDocument,
  validateFileSignature,
  MAX_FILE_SIZE
};
