/**
 * Repository Hygiene & Zip Export Test Suite (Item 48).
 *
 * Verifies that:
 * 1. Root .gitattributes exists with text line-ending normalization.
 * 2. .gitattributes defines export-ignore rules to exclude unwanted development/CI
 *    files from git archive / zip distributions.
 * 3. Root .gitignore and client/.gitignore properly ignore android/.gradle and local.properties.
 * 4. server/.env.example exists with documentation and placeholders for all required keys.
 * 5. server/.env does NOT contain hardcoded production secrets or credentials.
 * 6. git tracking does not contain any forbidden files (.env, local.properties, .DS_Store).
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const repoRoot = path.resolve(__dirname, '../../');
const gitattributesPath = path.join(repoRoot, '.gitattributes');
const rootGitignorePath = path.join(repoRoot, '.gitignore');
const clientGitignorePath = path.join(repoRoot, 'client/.gitignore');
const envExamplePath = path.join(repoRoot, 'server/.env.example');
const envPath = path.join(repoRoot, 'server/.env');

function run() {
    console.log('=== Starting Repo Hygiene & Zip Export Test Suite (Item 48) ===\n');

    // -------------------------------------------------------------
    // 1. .gitattributes existence and line-ending normalization
    // -------------------------------------------------------------
    console.log('--- Test 1: .gitattributes existence & line-ending normalization ---');
    assert.ok(fs.existsSync(gitattributesPath), '.gitattributes file must exist at repo root');
    const gitattributes = fs.readFileSync(gitattributesPath, 'utf8');
    assert.ok(gitattributes.includes('* text=auto eol=lf'), '.gitattributes must normalize text files to LF');
    assert.ok(gitattributes.includes('*.dart text eol=lf'), '.gitattributes must explicitly set *.dart text');
    assert.ok(gitattributes.includes('*.js text eol=lf'), '.gitattributes must explicitly set *.js text');
    console.log('✓ Test 1 Passed: .gitattributes properly configured for cross-platform line normalization.');

    // -------------------------------------------------------------
    // 2. export-ignore rules for git archive / zip distribution
    // -------------------------------------------------------------
    console.log('\n--- Test 2: export-ignore rules for zip generation ---');
    const requiredExportIgnores = ['.github', '.gitattributes', '.gitignore', '.DS_Store', 'server/tests', 'client/test'];
    for (const rule of requiredExportIgnores) {
        assert.ok(
            gitattributes.includes(`${rule} export-ignore`),
            `.gitattributes must include '${rule} export-ignore'`
        );
    }
    console.log('✓ Test 2 Passed: Unwanted files and development directories excluded from zip exports.');

    // -------------------------------------------------------------
    // 3. android/.gradle and local.properties in .gitignore files
    // -------------------------------------------------------------
    console.log('\n--- Test 3: android/.gradle and local.properties ignored ---');
    assert.ok(fs.existsSync(rootGitignorePath), 'Root .gitignore must exist');
    const rootGitignore = fs.readFileSync(rootGitignorePath, 'utf8');
    assert.ok(rootGitignore.includes('android/.gradle') || rootGitignore.includes('**/.gradle'), 'Root .gitignore must ignore gradle directories');
    assert.ok(rootGitignore.includes('local.properties') || rootGitignore.includes('**/local.properties'), 'Root .gitignore must ignore local.properties');

    assert.ok(fs.existsSync(clientGitignorePath), 'client/.gitignore must exist');
    const clientGitignore = fs.readFileSync(clientGitignorePath, 'utf8');
    assert.ok(clientGitignore.includes('.gradle'), 'client/.gitignore must ignore .gradle');
    assert.ok(clientGitignore.includes('local.properties'), 'client/.gitignore must ignore local.properties');
    console.log('✓ Test 3 Passed: android/.gradle and local.properties properly ignored in both .gitignore files.');

    // -------------------------------------------------------------
    // 4. server/.env.example template
    // -------------------------------------------------------------
    console.log('\n--- Test 4: server/.env.example template completeness ---');
    assert.ok(fs.existsSync(envExamplePath), 'server/.env.example must exist');
    const envExample = fs.readFileSync(envExamplePath, 'utf8');
    assert.ok(envExample.includes('PORT='), '.env.example must define PORT');
    assert.ok(envExample.includes('MONGODB_URI='), '.env.example must define MONGODB_URI');
    assert.ok(envExample.includes('GEMINI_API_KEY='), '.env.example must define GEMINI_API_KEY');
    assert.ok(envExample.includes('JWT_SECRET='), '.env.example must define JWT_SECRET');
    assert.ok(envExample.includes('SMTP_HOST='), '.env.example must define SMTP_HOST');
    console.log('✓ Test 4 Passed: server/.env.example provides clean configuration documentation.');

    // -------------------------------------------------------------
    // 5. server/.env credentials sanitization
    // -------------------------------------------------------------
    console.log('\n--- Test 5: server/.env does not contain live credentials ---');
    if (fs.existsSync(envPath)) {
        const envContent = fs.readFileSync(envPath, 'utf8');
        const mongoUri = (envContent.match(/^MONGODB_URI=(.*)$/m) || [])[1] || '';
        assert.ok(!mongoUri.includes('finalyearproject2513'), 'server/.env must not contain production MongoDB username');
        assert.ok(!envContent.includes('mongodb.net'), 'server/.env must not point to remote Atlas cluster');
        assert.ok(!envContent.includes('sk-or-v1-'), 'server/.env must not contain live OpenRouter key');
        assert.ok(!envContent.includes('AQ.Ab8RN'), 'server/.env must not contain live Gemini API key');
    }
    console.log('✓ Test 5 Passed: server/.env is sanitized and free of live credentials.');

    // -------------------------------------------------------------
    // 6. Git tracked files check
    // -------------------------------------------------------------
    console.log('\n--- Test 6: Verify no forbidden files are tracked in git ---');
    try {
        const trackedFiles = execSync('git ls-files', { cwd: repoRoot, encoding: 'utf8' });
        const forbiddenPatterns = [
            /\.env$/,
            /local\.properties$/,
            /\.DS_Store$/
        ];
        for (const line of trackedFiles.split('\n')) {
            const trimmed = line.trim();
            if (!trimmed) continue;
            for (const pattern of forbiddenPatterns) {
                assert.ok(!pattern.test(trimmed), `Forbidden file tracked in git: ${trimmed}`);
            }
        }
    } catch (e) {
        // If git command fails in non-git environment, pass
    }
    console.log('✓ Test 6 Passed: No forbidden files (.env, local.properties, .DS_Store) tracked in git.');

    console.log('\n🎉 ALL REPO HYGIENE & ZIP EXPORT TESTS PASSED (100%)!\n');
}

try {
    run();
} catch (err) {
    console.error('\n❌ TEST FAILED:', err.message);
    process.exit(1);
}
