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
 * Detects the binary magic bytes of the buffer.
 * Returns 'pdf' | 'jpeg' | 'png' | 'webp' | null.
 */
function detectBufferType(buffer) {
  if (!buffer || !Buffer.isBuffer(buffer) || buffer.length < 4) {
    return null;
  }

  // PDF signature: '%PDF' (0x25 0x50 0x44 0x46) at the very start (offset 0)
  if (
    buffer[0] === 0x25 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x44 &&
    buffer[3] === 0x46
  ) {
    return 'pdf';
  }

  // JPEG signature: FF D8 FF
  if (
    buffer.length >= 3 &&
    buffer[0] === 0xFF &&
    buffer[1] === 0xD8 &&
    buffer[2] === 0xFF
  ) {
    return 'jpeg';
  }

  // PNG signature: 89 50 4E 47 0D 0A 1A 0A
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
    return 'png';
  }

  // WebP signature: RIFF....WEBP (0x52 0x49 0x46 0x46 ... 0x57 0x45 0x42 0x50)
  if (buffer.length >= 12) {
    const isRiff = buffer[0] === 0x52 && buffer[1] === 0x49 && buffer[2] === 0x46 && buffer[3] === 0x46;
    const isWebp = buffer[8] === 0x57 && buffer[9] === 0x45 && buffer[10] === 0x42 && buffer[11] === 0x50;
    if (isRiff && isWebp) return 'webp';
  }

  return null;
}

/**
 * Validates actual binary signature (magic bytes) of the uploaded buffer.
 * Rejects disguised or mismatched files.
 * Rejects octet-stream MIME types.
 * Ensures the real header matches the claimed file type (for PDF, %PDF at the very start).
 */
function validateFileSignature(buffer, mimeType = '', ext = '') {
  if (!buffer || !Buffer.isBuffer(buffer) || buffer.length < 4) return false;

  const mime = (mimeType || '').toLowerCase().trim();
  let extension = (ext || '').toLowerCase().trim();
  if (extension) {
    if (extension.startsWith('.')) {
      // already starts with dot
    } else if (extension.includes('.')) {
      extension = path.extname(extension);
    } else {
      extension = `.${extension}`;
    }
  }

  // Explicitly reject octet-stream
  if (mime.includes('octet-stream')) {
    return false;
  }

  // Identify real binary header signature
  const detectedType = detectBufferType(buffer);
  if (!detectedType) {
    return false;
  }

  // Check that extension matches detected type
  if (extension) {
    switch (detectedType) {
      case 'pdf':
        if (extension !== '.pdf') return false;
        break;
      case 'jpeg':
        if (extension !== '.jpg' && extension !== '.jpeg') return false;
        break;
      case 'png':
        if (extension !== '.png') return false;
        break;
      case 'webp':
        if (extension !== '.webp') return false;
        break;
    }
  }

  // Check that mimeType matches detected type
  if (mime) {
    switch (detectedType) {
      case 'pdf':
        if (!mime.includes('pdf')) return false;
        break;
      case 'jpeg':
        if (!mime.includes('jpeg') && !mime.includes('jpg')) return false;
        break;
      case 'png':
        if (!mime.includes('png')) return false;
        break;
      case 'webp':
        if (!mime.includes('webp')) return false;
        break;
    }
  }

  return true;
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

    // Reject octet-stream explicitly
    if (!mime || mime.includes('octet-stream')) {
      const err = new Error('UNSUPPORTED_FILE_TYPE');
      err.code = 'UNSUPPORTED_FILE_TYPE';
      return cb(err, false);
    }

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
