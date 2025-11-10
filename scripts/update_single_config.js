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

// Initialize Firebase Admin SDK
try {
    admin.initializeApp({
        projectId: 'development-417611'
    });
    console.log('✓ Firebase Admin SDK initialized');
} catch (error) {
    console.error('✗ Failed to initialize Firebase Admin SDK:', error.message);
    console.error('\nPlease ensure you have authentication set up:');
    console.error('  1. Install: npm install firebase-admin');
    console.error('  2. Auth: gcloud auth application-default login');
    process.exit(1);
}

// Get Firestore instance and configure it to use the skanuj-wygrywaj database
const db = admin.firestore();
db.settings({
    databaseId: 'skanuj-wygrywaj'
});
console.log('✓ Using Firestore database: skanuj-wygrywaj');

// NEW CONFIGURATION (kazimierz-club-new)
const newConfig = {
    companyId: 'kazimierz-club-new',
    firebaseConfigAndroid: {
        apiKey: 'AIzaSyClPTttdsqmbC68z9HxQsWehxcf0Vhb50M',
        appId: '1:159120615271:android:8e46a63c1ab6102f74f1c2',
        messagingSenderId: '159120615271',
        projectId: 'development-417611',
        storageBucket: 'development-417611.firebasestorage.app',
        databaseURL: 'https://development-417611-default-rtdb.firebaseio.com'
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
    isLegacy: false,
    firebaseProject: 'development-417611',
    version: 2
};

async function updateConfig() {
    console.log('\n🔄 Updating galeria-kazimierz to NEW app configuration...\n');

    const documentId = 'kazimierz-club-new';

    try {
        // Show what we're about to change
        console.log('📋 Changes to apply:');
        console.log(`  Document ID: ${documentId}`);
        console.log(`  → companyId: "galeria-kazimierz" → "${newConfig.companyId}"`);
        console.log(`  → isLegacy: true → ${newConfig.isLegacy}`);
        console.log(`  → firebaseProject: "galeria-kazimierz-827d4" → "${newConfig.firebaseProject}"`);
        console.log(`  → webviewUrl: [LEGACY URL] → "${newConfig.webviewUrl}"`);
        console.log(`  → version: 1 → ${newConfig.version}`);
        console.log(`  → Firebase configs: LEGACY → NEW (development-417611)`);
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

