// JWT_SECRET must be set via environment variable — the server refuses to
// start without it, rather than silently signing/verifying tokens with a
// guessable default that anyone could forge a valid login with.
const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET || JWT_SECRET.trim().length === 0) {
    throw new Error(
        'JWT_SECRET environment variable is not set. Refusing to start: ' +
        'without it, the server would fall back to a publicly-known default ' +
        'secret, letting anyone forge a valid login token. Set JWT_SECRET in ' +
        'your .env file (a long random string) and restart.'
    );
}

module.exports = JWT_SECRET;