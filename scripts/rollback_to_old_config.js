#!/usr/bin/env node

/**
 * Rollback to OLD Configuration
 * 
 * Reverts 'galeria-kazimierz' document back to old app configuration
 * 
 * Prerequisites:
 * 1. Install Firebase Admin SDK: npm install firebase-admin
 * 2. Authenticate: gcloud auth application-default login
 * 
 * Usage:
 *   node scripts/rollback_to_old_config.js
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
// Try service account key first, fallback to gcloud auth
let initialized = false;
const serviceAccountPath = process.env.SERVICE_ACCOUNT_KEY || path.join(__dirname, 'firebase-service-account.json');

// Try service account key
if (fs.existsSync(serviceAccountPath)) {
    try {
        const serviceAccount = require(serviceAccountPath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            projectId: 'development-417611'
        });
        console.log(`✓ Firebase Admin SDK initialized with service account: ${serviceAccountPath}`);
        initialized = true;
    } catch (error) {
        console.warn(`⚠ Failed to use service account: ${error.message}`);
        console.warn('  Falling back to gcloud auth...');
    }
}

// Fallback to gcloud auth (Application Default Credentials)
if (!initialized) {
    try {
        admin.initializeApp({
            projectId: 'development-417611'
        });
        console.log('✓ Firebase Admin SDK initialized with gcloud auth');
        initialized = true;
    } catch (error) {
        console.error('✗ Failed to initialize Firebase Admin SDK:', error.message);
        console.error('\nPlease set up authentication:');
        console.error('  Option 1: Service account key');
        console.error('    1. Download from Firebase Console → Project Settings → Service Accounts');
        console.error('    2. Save as: scripts/firebase-service-account.json');
        console.error('    3. Or set SERVICE_ACCOUNT_KEY environment variable');
        console.error('  Option 2: gcloud auth');
        console.error('    Run: gcloud auth application-default login');
        process.exit(1);
    }
}

// Get Firestore instance and configure it to use the skanuj-wygrywaj database
const db = admin.firestore();
db.settings({
    databaseId: 'skanuj-wygrywaj'
});
console.log('✓ Using Firestore database: skanuj-wygrywaj');

// OLD CONFIGURATION (galeria-kazimierz legacy)
const oldConfig = {
    companyId: 'galeria-kazimierz',
    googleAuthCompanyId: 'galeria-kazimierz',
    firebaseConfigAndroid: {
        apiKey: 'AIzaSyA1BUbvKpPjTkgLxMOVwawaDW67_f-mhrY',
        appId: '1:839029981684:android:f1773609d3cb500e5e39a1',
        messagingSenderId: '839029981684',
        projectId: 'galeria-kazimierz-827d4',
        storageBucket: 'galeria-kazimierz-827d4.firebasestorage.app',
        databaseURL: 'https://galeria-kazimierz-827d4.firebaseio.com'
    },
    firebaseConfigIOS: {
        apiKey: 'AIzaSyBo14c6d4SZshTAP-YvqMcHcTTJsXz9F1I',
        appId: '1:839029981684:ios:b33dc71b2f7551e05e39a1',
        messagingSenderId: '839029981684',
        projectId: 'galeria-kazimierz-827d4',
        storageBucket: 'galeria-kazimierz-827d4.firebasestorage.app',
        databaseURL: 'https://galeria-kazimierz-827d4.firebaseio.com',
        iosBundleId: 'it.2take.galeriakazimierz'
    },
    webviewUrl: 'https://login.2take.it?company_name=galeria-kazimierz&d=9e30d60cdabaa8c6859b7ee737cd943b23d727b3&legacy=true',
    backendUrl: 'https://login.2take.it/',
    isLegacy: true,
    firebaseProject: 'galeria-kazimierz-827d4',
    version: 7
};

async function rollbackConfig() {
    console.log('\n⏪ Rolling back galeria-kazimierz to OLD app configuration...\n');

    const documentId = 'galeria-kazimierz';

    try {
        // Show what we're about to change
        console.log('📋 Rollback changes:');
        console.log(`  Document ID: ${documentId}`);
        console.log(`  → companyId: "kazimierz-club-new" → "${oldConfig.companyId}"`);
        console.log(`  → isLegacy: false → ${oldConfig.isLegacy}`);
        console.log(`  → firebaseProject: "development-417611" → "${oldConfig.firebaseProject}"`);
        console.log(`  → webviewUrl: [NEW URL] → "${oldConfig.webviewUrl}"`);
        console.log(`  → version: 2 → ${oldConfig.version}`);
        console.log(`  → Firebase configs: NEW → LEGACY (galeria-kazimierz-827d4)`);
        console.log();

        // Update the document
        await db.collection('mobile_configs').doc(documentId).set(oldConfig, { merge: true });

        console.log(`✅ Successfully rolled back '${documentId}' to OLD configuration!\n`);
        console.log('📱 Next steps:');
        console.log('  1. Restart your app (stop & start again)');
        console.log('  2. Check logs for: "Loaded companyId: galeria-kazimierz"');
        console.log('  3. Verify UI shows "Legacy Mode" with blue theme');
        console.log();

    } catch (error) {
        console.error(`✗ Failed to rollback config:`, error.message);
        process.exit(1);
    }
}

// Run the script
rollbackConfig()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error('✗ Script failed:', error);
        process.exit(1);
    });

