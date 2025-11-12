#!/usr/bin/env node

/**
 * Update Single Firestore Configuration
 * 
 * Updates only the 'galeria-kazimierz' document to use new app configuration
 * 
 * Prerequisites:
 * 1. Install Firebase Admin SDK: npm install firebase-admin
 * 2. Authenticate: gcloud auth application-default login
 * 
 * Usage:
 *   node scripts/update_single_config.js
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

// NEW CONFIGURATION (kazimierz-club-new)
// IMPORTANT: firebaseConfigAndroid MUST match native google-services.json for galeriaKazimierz flavor
// The native config uses galeria-kazimierz-827d4, NOT development-417611
const newConfig = {
    companyId: 'kazimierz-club-new',
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
        apiKey: 'AIzaSyDxIO20bhKa3y5YLfcuZtv2b5qxaPSW_NM',
        appId: '1:159120615271:ios:2ba734d4e96baccf74f1c2',
        messagingSenderId: '159120615271',
        projectId: 'development-417611',
        storageBucket: 'development-417611.firebasestorage.app',
        databaseURL: 'https://development-417611-default-rtdb.firebaseio.com',
        iosBundleId: 'com.skanujwygrywaj.skanujWygrywaj'
    },
    webviewUrl: 'https://skanuj-staging.web.app/?company_name=kazimierz-club-new',
    backendUrl: 'https://europe-central2-development-417611.cloudfunctions.net/kanuj-wygrywaj-backend/',
    isLegacy: false,
    firebaseProject: 'galeria-kazimierz-827d4', // Must match native google-services.json for galeriaKazimierz flavor
    version: 6
};

async function updateConfig() {
    console.log('\n🔄 Updating galeria-kazimierz to NEW app configuration...\n');

    const documentId = 'galeria-kazimierz';

    try {
        // Show what we're about to change
        console.log('📋 Changes to apply:');
        console.log(`  Document ID: ${documentId}`);
        console.log(`  → companyId: "galeria-kazimierz" → "${newConfig.companyId}"`);
        console.log(`  → isLegacy: true → ${newConfig.isLegacy}`);
        console.log(`  → firebaseProject: KEEPS "galeria-kazimierz-827d4" (matches native google-services.json)`);
        console.log(`  → webviewUrl: [LEGACY URL] → "${newConfig.webviewUrl}"`);
        console.log(`  → version: [current] → ${newConfig.version}`);
        console.log(`  → firebaseConfigAndroid: KEEPS galeria-kazimierz-827d4 (matches native google-services.json)`);
        console.log(`  → firebaseConfigIOS: NEW (development-417611)`);
        console.log();

        // Update the document
        await db.collection('mobile_configs').doc(documentId).set(newConfig, { merge: true });

        console.log(`✅ Successfully updated '${documentId}' to NEW configuration!\n`);
        console.log('📱 Next steps:');
        console.log('  1. Restart your app (stop & start again)');
        console.log('  2. Check logs for: "Loaded companyId: kazimierz-club-new"');
        console.log('  3. Verify UI shows "Modern Mode" with purple theme');
        console.log();
        console.log('🔙 To rollback, run: node scripts/rollback_to_old_config.js');
        console.log();

    } catch (error) {
        console.error(`✗ Failed to update config:`, error.message);
        process.exit(1);
    }
}

// Run the script
updateConfig()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error('✗ Script failed:', error);
        process.exit(1);
    });

