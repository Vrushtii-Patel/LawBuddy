/**
 * CI/CD Workflows Configuration Test Suite (Item 46).
 *
 * Verifies that:
 * 1. backend-tests.yml does not request excessive permissions (contents: write),
 *    restricting to least privilege (contents: read).
 * 2. backend-tests.yml does not perform auto-commit/push actions on test runs.
 * 3. flutter_deploy.yml does NOT duplicate backend-ci test jobs.
 * 4. flutter_deploy.yml does NOT trigger on or deploy personal branches like 'Jiya'.
 * 5. flutter_deploy.yml deployment to GitHub Pages is strictly conditioned on the 'main' branch.
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '../../');
const backendTestsPath = path.join(repoRoot, '.github/workflows/backend-tests.yml');
const flutterDeployPath = path.join(repoRoot, '.github/workflows/flutter_deploy.yml');

function run() {
    console.log('=== Starting CI/CD Workflows Verification Test Suite (Item 46) ===\n');

    assert.ok(fs.existsSync(backendTestsPath), 'backend-tests.yml must exist');
    assert.ok(fs.existsSync(flutterDeployPath), 'flutter_deploy.yml must exist');

    const backendTestsContent = fs.readFileSync(backendTestsPath, 'utf8');
    const flutterDeployContent = fs.readFileSync(flutterDeployPath, 'utf8');

    // -------------------------------------------------------------
    // 1. backend-tests.yml Least Privilege Permissions
    // -------------------------------------------------------------
    console.log('--- Test 1: backend-tests.yml least-privilege permissions ---');
    assert.ok(
        !/permissions:\s*[\r\n]+\s*contents:\s*write/.test(backendTestsContent),
        'backend-tests.yml must NOT request contents: write permissions globally'
    );
    assert.ok(
        /permissions:\s*[\r\n]+\s*contents:\s*read/.test(backendTestsContent),
        'backend-tests.yml must specify contents: read'
    );
    assert.ok(
        !backendTestsContent.includes('git commit') && !backendTestsContent.includes('git push'),
        'backend-tests.yml must not contain git commit or git push steps'
    );
    console.log('✓ Test 1 Passed: backend-tests.yml permissions are strictly contents: read with no write/commit steps.');

    // -------------------------------------------------------------
    // 2. flutter_deploy.yml No Duplicate Backend CI
    // -------------------------------------------------------------
    console.log('\n--- Test 2: flutter_deploy.yml removes duplicate backend CI ---');
    assert.ok(
        !flutterDeployContent.includes('backend-ci:'),
        'flutter_deploy.yml must not duplicate the backend-ci job (backend-tests.yml handles backend testing)'
    );
    assert.ok(
        !flutterDeployContent.includes('needs: [backend-ci]'),
        'flutter-ci-and-deploy must not depend on a duplicate backend-ci job'
    );
    console.log('✓ Test 2 Passed: Duplicate backend-ci job removed from flutter_deploy.yml.');

    // -------------------------------------------------------------
    // 3. flutter_deploy.yml Does Not Deploy 'Jiya' Branch
    // -------------------------------------------------------------
    console.log('\n--- Test 3: flutter_deploy.yml does not trigger or deploy Jiya branch ---');
    assert.ok(
        !/-\s*Jiya\b/.test(flutterDeployContent),
        'flutter_deploy.yml must not list the Jiya branch in push triggers'
    );
    assert.ok(
        !/-\s*Jiya\b/.test(backendTestsContent),
        'backend-tests.yml must not list the Jiya branch'
    );
    console.log('✓ Test 3 Passed: Jiya branch is removed from workflow push triggers.');

    // -------------------------------------------------------------
    // 4. flutter_deploy.yml Scopes Deploy to Main Only
    // -------------------------------------------------------------
    console.log('\n--- Test 4: Deployment to GitHub Pages scoped strictly to main branch ---');
    assert.ok(
        flutterDeployContent.includes("github.ref == 'refs/heads/main'"),
        'Deployment steps in flutter_deploy.yml must check github.ref == refs/heads/main'
    );
    assert.ok(
        flutterDeployContent.includes('peaceiris/actions-gh-pages'),
        'flutter_deploy.yml must retain the GitHub Pages deploy action'
    );
    console.log('✓ Test 4 Passed: Deploy step guarded by main branch check.');

    console.log('\n🎉 ALL CI/CD WORKFLOW VERIFICATION TESTS PASSED (100%)!\n');
}

try {
    run();
} catch (err) {
    console.error('\n❌ TEST FAILED:', err.message);
    process.exit(1);
}
