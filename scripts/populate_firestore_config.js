#!/usr/bin/env node

/**
 * Firestore Configuration Population Script
 * 
 * This script populates the app_configs collection in Firestore
 * with the secure configuration for both flavors.
 * 
 * Prerequisites:
 * 1. Install Firebase Admin SDK: npm install firebase-admin
 * 2. Set up authentication:
 *    - Option A: Set GOOGLE_APPLICATION_CREDENTIALS env var
 *    - Option B: Use gcloud auth application-default login
 * 
 * Usage:
 *   node scripts/populate_firestore_config.js
 * 
 * Or with npx (no install needed):
 *   npx -y firebase-admin && node scripts/populate_firestore_config.js
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

// Configuration data
const configs = {
    'galeria-kazimierz': {
        firebaseConfig: {
            android: {
                apiKey: 'AIzaSyA1BUbvKpPjTkgLxMOVwawaDW67_f-mhrY',
                appId: '1:839029981684:android:f1773609d3cb500e5e39a1',
                messagingSenderId: '839029981684',
                projectId: 'galeria-kazimierz-827d4',
                storageBucket: 'galeria-kazimierz-827d4.firebasestorage.app',
                databaseURL: 'https://galeria-kazimierz-827d4.firebaseio.com'
            },
            ios: {
                apiKey: 'AIzaSyBo14c6d4SZshTAP-YvqMcHcTTJsXz9F1I',
                appId: '1:839029981684:ios:b33dc71b2f7551e05e39a1',
                messagingSenderId: '839029981684',
                projectId: 'galeria-kazimierz-827d4',
                storageBucket: 'galeria-kazimierz-827d4.firebasestorage.app',
                databaseURL: 'https://galeria-kazimierz-827d4.firebaseio.com',
                iosBundleId: 'it.2take.galeriakazimierz'
            }
        },
        webviewUrl: 'https://login.2take.it/?company_name=galeria-kazimierz&legacy=true',
        isLegacy: true,
        firebaseProject: 'galeria-kazimierz-827d4',
        version: 1
    },
    'kazimierz-club-new': {
        firebaseConfig: {
            android: {
                apiKey: 'AIzaSyClPTttdsqmbC68z9HxQsWehxcf0Vhb50M',
                appId: '1:159120615271:android:8e46a63c1ab6102f74f1c2',
                messagingSenderId: '159120615271',
                projectId: 'development-417611',
                storageBucket: 'development-417611.firebasestorage.app',
                databaseURL: 'https://development-417611-default-rtdb.firebaseio.com'
            },
            ios: {
                apiKey: 'AIzaSyDxIO20bhKa3y5YLfcuZtv2b5qxaPSW_NM',
                appId: '1:159120615271:ios:2ba734d4e96baccf74f1c2',
                messagingSenderId: '159120615271',
                projectId: 'development-417611',
                storageBucket: 'development-417611.firebasestorage.app',
                databaseURL: 'https://development-417611-default-rtdb.firebaseio.com',
                iosBundleId: 'com.skanujwygrywaj.skanujWygrywaj'
            }
        },
        webviewUrl: 'https://skanuj-staging.web.app?company_name=kazimierz-club-new',
        isLegacy: false,
        firebaseProject: 'development-417611',
        version: 1
    }
};

async function populateConfigs() {
    console.log('\n📝 Populating Firestore with app configurations...\n');

    for (const [companyId, config] of Object.entries(configs)) {
        try {
            // Flatten the structure for Firestore
            const firestoreConfig = {
                companyId: companyId,
                firebaseConfigAndroid: config.firebaseConfig.android,
                firebaseConfigIOS: config.firebaseConfig.ios,
                webviewUrl: config.webviewUrl,
                isLegacy: config.isLegacy,
                firebaseProject: config.firebaseProject,
                version: config.version
            };

            await db.collection('mobile_configs').doc(companyId).set(firestoreConfig);
            console.log(`✓ Created/Updated config for: ${companyId}`);
            console.log(`  - Company ID: ${companyId}`);
            console.log(`  - Firebase Project: ${config.firebaseProject}`);
            console.log(`  - Legacy Mode: ${config.isLegacy}`);
            console.log(`  - Android Config: ✓`);
            console.log(`  - iOS Config: ✓`);
            console.log(`  - Version: ${config.version}`);
            console.log();
        } catch (error) {
            console.error(`✗ Failed to create config for ${companyId}:`, error.message);
            process.exit(1);
        }
    }

    console.log('✅ All configurations populated successfully!\n');
    console.log('Next steps:');
    console.log('  1. Configure Firestore security rules (see docs/FIRESTORE_CONFIG_SETUP.md)');
    console.log('  2. Enable App Check in Firebase Console');
    console.log('  3. Test the app with: flutter run --dart-define=FLAVOR=galeriaKazimierz');
    console.log();
}

// Run the script
populateConfigs()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error('✗ Script failed:', error);
        process.exit(1);
    });

