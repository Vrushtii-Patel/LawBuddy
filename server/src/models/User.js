const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    unique: true
  },
  full_name: {
    type: String,
    required: true,
    trim: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  emailVerified: {
    type: Boolean,
    default: false
  },
  phone: {
    type: String,
    unique: true,
    sparse: true,
    trim: true
  },
  password: {
    type: String
  },
  passwordHash: {
    type: String
  },
  dateOfBirth: {
    type: Date
  },
  preferredLanguage: {
    type: String
  },
  termsAcceptedAt: {
    type: Date
  },
  termsVersion: {
    type: String
  },
  tokenVersion: {
    type: Number,
    default: 0
  },
  created_at: {
    type: Date,
    default: Date.now
  },
  last_login: {
    type: Date,
    default: Date.now
  },
  profile_photo: {
    type: String,
    default: 'https://api.dicebear.com/7.x/bottts/svg?seed=LegalScanner'
  },
  role: {
    type: String,
    enum: ['user', 'admin'],
    default: 'user'
  },
  updated_at: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: { createdAt: 'created_at', updatedAt: 'updated_at' }
});

// TTL cleanup: unverified users (emailVerified: false) are automatically deleted 24h (86400s) after creation.
// Verified accounts (emailVerified: true) including legacy users are strictly excluded and never deleted.
userSchema.index(
  { created_at: 1 },
  { expireAfterSeconds: 86400, partialFilterExpression: { emailVerified: false } }
);

module.exports = mongoose.model('User', userSchema);
