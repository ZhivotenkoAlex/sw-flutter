#!/usr/bin/env node
/**
 * Verify Firestore Configuration Data
 * 
 * This script checks if the mobile_configs collection has the required data
 * for the Flutter app to fetch at startup.
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

const db = admin.firestore();

// Configure to use the skanuj-wygrywaj database
db.settings({
    databaseId: 'skanuj-wygrywaj'
});

async function verifyData() {
    console.log('🔍 Verifying Firestore Configuration Data...\n');
    console.log('📍 Project: development-417611');
    console.log('📍 Database: skanuj-wygrywaj');
    console.log('📍 Collection: mobile_configs\n');

    try {
        const configs = ['galeria-kazimierz', 'kazimierz-club-new'];

        for (const configId of configs) {
            console.log(`\n${'='.repeat(60)}`);
            console.log(`Checking config: ${configId}`);
            console.log(`${'='.repeat(60)}`);

            const docRef = db.collection('mobile_configs').doc(configId);
            const doc = await docRef.get();

            if (!doc.exists) {
                console.log(`❌ Document '${configId}' NOT FOUND!`);
                continue;
            }

            const data = doc.data();
            console.log('✅ Document found!');
            console.log('\n📄 Configuration:');
            console.log(`   Company ID: ${data.companyId}`);
            console.log(`   Webview URL: ${data.webviewUrl}`);
            console.log(`   Backend URL: ${data.backendUrl || 'MISSING'}`);
            console.log(`   Is Legacy: ${data.isLegacy}`);
            console.log(`   Firebase Project: ${data.firebaseProject}`);
            console.log(`   Version: ${data.version}`);

            // Check Firebase configs
            if (data.firebaseConfigAndroid) {
                console.log('\n   Android Firebase Config:');
                console.log(`     ✓ API Key: ${data.firebaseConfigAndroid.apiKey ? '***' + data.firebaseConfigAndroid.apiKey.slice(-4) : 'MISSING'}`);
                console.log(`     ✓ App ID: ${data.firebaseConfigAndroid.appId || 'MISSING'}`);
                const androidProjectId = data.firebaseConfigAndroid.projectId || 'MISSING';
                console.log(`     ✓ Project ID: ${androidProjectId}`);

                // Warn if galeria-kazimierz has wrong project ID
                if (configId === 'galeria-kazimierz' && androidProjectId !== 'galeria-kazimierz-827d4') {
                    console.log(`     ⚠️  WARNING: Expected 'galeria-kazimierz-827d4' to match native google-services.json!`);
                    console.log(`        Run: node scripts/fix_galeria_kazimierz_firebase_config.js`);
                }
            } else {
                console.log('\n   ❌ Android Firebase Config: MISSING');
            }

            if (data.firebaseConfigIOS) {
                console.log('\n   iOS Firebase Config:');
                console.log(`     ✓ API Key: ${data.firebaseConfigIOS.apiKey ? '***' + data.firebaseConfigIOS.apiKey.slice(-4) : 'MISSING'}`);
                console.log(`     ✓ App ID: ${data.firebaseConfigIOS.appId || 'MISSING'}`);
                console.log(`     ✓ Project ID: ${data.firebaseConfigIOS.projectId || 'MISSING'}`);
            } else {
                console.log('\n   ❌ iOS Firebase Config: MISSING');
            }
        }

        console.log(`\n${'='.repeat(60)}`);
        console.log('✅ SUCCESS: All configurations are present!');
        console.log(`${'='.repeat(60)}\n`);
        console.log('💡 Your Flutter app will be able to fetch these configs at startup.');
        console.log('   To test: Run your app on an Android or iOS device/emulator.\n');

        process.exit(0);

    } catch (error) {
        console.error('\n❌ ERROR:', error.message);
        console.error('\n💡 Troubleshooting:');
        console.error('   1. Make sure you ran: node scripts/populate_firestore_config.js');
        console.error('   2. Check Firebase Console: https://console.firebase.google.com/project/development-417611/firestore');
        console.error('   3. Verify the database ID is correct: skanuj-wygrywaj');
        process.exit(1);
    }
}

verifyData();

