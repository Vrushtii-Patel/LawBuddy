/**
 * Release-configuration guard. Reads the client's native config files and fails when a
 * setting would ship an insecure or broken release build. No network or database needed.
 *
 * Runs from the server folder (the client folder is its sibling).
 */
const assert = require('assert');
const fs = require('fs');
const path = require('path');

const clientDir = path.resolve(__dirname, '../../client');
const read = (rel) => fs.readFileSync(path.join(clientDir, rel), 'utf8');

/** Removes XML comments so commented-out settings are not counted. */
const stripXmlComments = (xml) => xml.replace(/<!--[\s\S]*?-->/g, '');

/** Returns the attributes text of the <application ...> tag, or null if there is none. */
function applicationTag(xml) {
    const match = /<application\b([^>]*)>/.exec(stripXmlComments(xml)) || /<application\b([^>]*)\/>/.exec(stripXmlComments(xml));
    return match ? match[1] : null;
}


/** Returns the keys that appear more than once inside the same <dict> of a plist. */
function duplicatePlistKeys(plist) {
    const duplicates = [];
    const stack = [];
    const tokens = /<(\/?)(dict|array)>|<key>([^<]*)<\/key>/g;
    let m;
    while ((m = tokens.exec(plist)) !== null) {
        if (m[2]) {
            if (m[1]) stack.pop();
            else stack.push({ isDict: m[2] === 'dict', keys: new Set() });
        } else if (m[3] !== undefined) {
            const top = stack[stack.length - 1];
            if (top && top.isDict) {
                if (top.keys.has(m[3])) duplicates.push(m[3]);
                top.keys.add(m[3]);
            }
        }
    }
    return duplicates;
}

/** Value of a top-level plist string key, or null. */
function plistString(plist, key) {
    const m = new RegExp('<key>' + key + '</key>\\s*<string>([^<]*)</string>').exec(plist);
    return m ? m[1].trim() : null;
}

function run() {
    console.log('--- Release configuration guard ---');

    const main = read('android/app/src/main/AndroidManifest.xml');
    const debug = read('android/app/src/debug/AndroidManifest.xml');
    const profile = read('android/app/src/profile/AndroidManifest.xml');

    // E1: the release app must be able to use the network.
    assert.ok(/<uses-permission[^>]*android\.permission\.INTERNET/.test(stripXmlComments(main)),
        'main AndroidManifest.xml must declare the INTERNET permission');
    console.log('✓ Android release declares the INTERNET permission');

    // Item 5: release builds must not allow plain-HTTP traffic.
    const mainApp = applicationTag(main);
    assert.ok(mainApp, 'main AndroidManifest.xml must contain an <application> tag');
    assert.ok(!/usesCleartextTraffic\s*=\s*"true"/.test(mainApp),
        'main AndroidManifest.xml must NOT set usesCleartextTraffic="true" (it would allow plain HTTP in release builds)');
    assert.ok(!/networkSecurityConfig/.test(mainApp) || !/cleartextTrafficPermitted\s*=\s*"true"/.test(
        fs.existsSync(path.join(clientDir, 'android/app/src/main/res/xml/network_security_config.xml'))
            ? read('android/app/src/main/res/xml/network_security_config.xml') : ''),
        'network_security_config.xml must not permit cleartext traffic in release');
    console.log('✓ Android release blocks plain HTTP traffic');

    // Local development (emulator / debug) still needs plain HTTP to the local server.
    for (const [name, xml] of [['debug', debug], ['profile', profile]]) {
        const app = applicationTag(xml);
        assert.ok(app && /usesCleartextTraffic\s*=\s*"true"/.test(app),
            `${name} AndroidManifest.xml should allow cleartext so the app can reach a local http server while developing`);
    }
    console.log('✓ Debug and profile builds still allow plain HTTP for local development');

    // iOS: no blanket exception to App Transport Security.
    const plist = read('ios/Runner/Info.plist');
    assert.ok(!/NSAllowsArbitraryLoads\s*<\/key>\s*<true\s*\/>/.test(plist),
        'Info.plist must not disable App Transport Security (NSAllowsArbitraryLoads = true)');
    console.log('✓ iOS keeps App Transport Security enabled');

    // Item 7: iOS needs a reason for every protected resource the app uses.
    const pubspec = read('pubspec.yaml');
    if (/^\s*image_picker\s*:/m.test(pubspec)) {
        for (const key of ['NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription']) {
            const text = plistString(plist, key);
            assert.ok(text && text.length >= 20,
                `Info.plist must contain ${key} with a sentence explaining why (the app uses image_picker; without it iOS closes the app when the camera or photos are opened)`);
        }
        console.log('✓ iOS Info.plist explains camera and photo library access');
    }
    const dupes = duplicatePlistKeys(plist);
    assert.deepStrictEqual(dupes, [], `Info.plist has duplicate keys (iOS keeps only one, unpredictably): ${dupes.join(', ')}`);
    console.log('✓ iOS Info.plist has no duplicate keys');

    // Item 6: the Android default must reach the computer running the server from an emulator.
    const api = read('lib/services/api_service.dart');
    const hostMatch = /static\s+String\s+androidHost\s*=\s*const\s+String\.fromEnvironment\(\s*'ANDROID_HOST'\s*,\s*defaultValue:\s*'([^']+)'\s*,?\s*\)/.exec(api);
    assert.ok(hostMatch,
        "api_service.dart must define androidHost = const String.fromEnvironment('ANDROID_HOST', defaultValue: ...) so it can be overridden at build time");
    assert.strictEqual(hostMatch[1], '10.0.2.2:3000',
        `Android default host must be 10.0.2.2:3000 (the emulator's address for your computer), found "${hostMatch[1]}"`);
    assert.ok(/defaultTargetPlatform\s*==\s*TargetPlatform\.android\)\s*\{\s*return\s+'http:\/\/\$androidHost\/api';/.test(api),
        'Android builds without API_URL must use androidHost');
    console.log('✓ Android default API host is 10.0.2.2:3000 and can be overridden with --dart-define=ANDROID_HOST');

    console.log('\nALL RELEASE CONFIG CHECKS PASSED (7/7)');
}

try {
    run();
} catch (err) {
    console.error('\nTEST FAILED:', err.message);
    process.exit(1);
}