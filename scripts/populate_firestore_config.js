#!/usr/bin/env node

/**
 * Firestore Configuration Population Script
 * 
 * This script populates the mobile_configs collection in Firestore
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
        webviewUrl: 'https://login.2take.it?company_name=galeria-kazimierz&d=9e30d60cdabaa8c6859b7ee737cd943b23d727b3&legacy=true',
        googleAuthCompanyId: 'galeria-kazimierz',
        backendUrl: 'https://login.2take.it/',
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
        backendUrl: 'https://europe-central2-development-417611.cloudfunctions.net/kanuj-wygrywaj-backend/',
        googleAuthCompanyId: 'galeria-kazimierz',
        isLegacy: false,
        firebaseProject: 'development-417611',
        version: 1
    },
    'polbau-demo': {
        firebaseConfig: {
            android: {
                // TODO: Replace with actual values from google-services.json
                apiKey: 'YOUR_ANDROID_API_KEY',
                appId: 'YOUR_ANDROID_APP_ID',
                messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
                projectId: 'YOUR_PROJECT_ID',
                storageBucket: 'YOUR_STORAGE_BUCKET',
                databaseURL: 'YOUR_DATABASE_URL'
            },
            ios: {
                // TODO: Replace with actual values from GoogleService-Info.plist
                apiKey: 'YOUR_IOS_API_KEY',
                appId: 'YOUR_IOS_APP_ID',
                messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
                projectId: 'YOUR_PROJECT_ID',
                storageBucket: 'YOUR_STORAGE_BUCKET',
                databaseURL: 'YOUR_DATABASE_URL',
                iosBundleId: 'com.polbau.polbau_demo'
            }
        },
        webviewUrl: 'https://YOUR_WEBVIEW_URL?company_name=polbau-demo',
        backendUrl: 'https://YOUR_BACKEND_URL/',
        googleAuthCompanyId: 'polbau-demo',
        isLegacy: false,
        firebaseProject: 'YOUR_FIREBASE_PROJECT_ID',
        version: 1
    },
    'wislanka': {
        firebaseConfig: {
            android: {
                // TODO: Replace with actual values from google-services.json
                apiKey: 'YOUR_ANDROID_API_KEY',
                appId: 'YOUR_ANDROID_APP_ID',
                messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
                projectId: 'YOUR_PROJECT_ID',
                storageBucket: 'YOUR_STORAGE_BUCKET',
                databaseURL: 'YOUR_DATABASE_URL'
            },
            ios: {
                // TODO: Replace with actual values from GoogleService-Info.plist
                apiKey: 'YOUR_IOS_API_KEY',
                appId: 'YOUR_IOS_APP_ID',
                messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
                projectId: 'YOUR_PROJECT_ID',
                storageBucket: 'YOUR_STORAGE_BUCKET',
                databaseURL: 'YOUR_DATABASE_URL',
                iosBundleId: 'com.wislanka.wislanka'
            }
        },
        webviewUrl: 'https://YOUR_WEBVIEW_URL?company_name=wislanka',
        backendUrl: 'https://YOUR_BACKEND_URL/',
        googleAuthCompanyId: 'wislanka',
        isLegacy: false,
        firebaseProject: 'YOUR_FIREBASE_PROJECT_ID',
        version: 1
    },
    'stary-browar': {
        firebaseConfig: {
            android: {
                // TODO: Replace with actual values from google-services.json
                apiKey: 'YOUR_ANDROID_API_KEY',
                appId: 'YOUR_ANDROID_APP_ID',
                messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
                projectId: 'YOUR_PROJECT_ID',
                storageBucket: 'YOUR_STORAGE_BUCKET',
                databaseURL: 'YOUR_DATABASE_URL'
            },
            ios: {
                // TODO: Replace with actual values from GoogleService-Info.plist
                apiKey: 'YOUR_IOS_API_KEY',
                appId: 'YOUR_IOS_APP_ID',
                messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
                projectId: 'YOUR_PROJECT_ID',
                storageBucket: 'YOUR_STORAGE_BUCKET',
                databaseURL: 'YOUR_DATABASE_URL',
                iosBundleId: 'com.starybrowar.staryBrowar'
            }
        },
        webviewUrl: 'https://YOUR_WEBVIEW_URL?company_name=stary-browar',
        backendUrl: 'https://YOUR_BACKEND_URL/',
        googleAuthCompanyId: 'stary-browar',
        isLegacy: false,
        firebaseProject: 'YOUR_FIREBASE_PROJECT_ID',
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
                backendUrl: config.backendUrl,
                isLegacy: config.isLegacy,
                firebaseProject: config.firebaseProject,
                version: config.version
            };

            await db.collection('mobile_configs').doc(companyId).set(firestoreConfig);
            console.log(`✓ Created/Updated config for: ${companyId}`);
            console.log(`  - Company ID: ${companyId}`);
            console.log(`  - Firebase Project: ${config.firebaseProject}`);
            console.log(`  - Backend URL: ${config.backendUrl}`);
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
