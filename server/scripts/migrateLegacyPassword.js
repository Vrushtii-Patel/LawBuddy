/**
 * One-off migration: retire the legacy `password` field on User documents.
 *
 * For every user that still has a `password` field:
 *   - if `passwordHash` is missing AND the legacy value is a bcrypt hash,
 *     copy it into `passwordHash` (so the user can keep logging in);
 *   - in all cases, $unset `password`.
 * Legacy values that are not bcrypt hashes are NOT copied (they could never
 * have matched bcrypt.compare anyway); those users just use "Forgot password".
 *
 * Reads the raw collection because the field is no longer in the Mongoose schema.
 *
 * Usage (run BEFORE deploying the code that removes the field):
 *   node scripts/migrateLegacyPassword.js            # dry run, changes nothing
 *   node scripts/migrateLegacyPassword.js --apply    # performs the migration
 */
require('dotenv').config();
const mongoose = require('mongoose');

const BCRYPT_RE = /^\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}$/;
const apply = process.argv.includes('--apply');

async function main() {
    const uri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/lawbuddy';
    await mongoose.connect(uri, { family: 4, serverSelectionTimeoutMS: 5000 });
    const users = mongoose.connection.db.collection('users');

    const legacy = await users
        .find({ password: { $exists: true } }, { projection: { userId: 1, email: 1, password: 1, passwordHash: 1 } })
        .toArray();

    let toCopy = 0, alreadyHasHash = 0, unusable = 0;

    for (const u of legacy) {
        const hasHash = typeof u.passwordHash === 'string' && u.passwordHash.length > 0;
        const legacyIsBcrypt = typeof u.password === 'string' && BCRYPT_RE.test(u.password);

        const update = { $unset: { password: '' } };
        if (!hasHash && legacyIsBcrypt) {
            update.$set = { passwordHash: u.password };
            toCopy++;
        } else if (hasHash) {
            alreadyHasHash++;
        } else {
            unusable++;
        }

        if (apply) await users.updateOne({ _id: u._id }, update);
    }

    console.log(`${apply ? 'APPLIED' : 'DRY RUN'} — users with legacy "password": ${legacy.length}`);
    console.log(`  copied to passwordHash:            ${toCopy}`);
    console.log(`  already had passwordHash:          ${alreadyHasHash}`);
    console.log(`  legacy value not bcrypt (must reset password): ${unusable}`);
    if (!apply) console.log('Re-run with --apply to make these changes.');

    await mongoose.disconnect();
}

main().catch(err => { console.error(err); process.exit(1); });