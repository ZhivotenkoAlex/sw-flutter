#!/usr/bin/env node

/**
 * Find Web Client ID from google-services.json
 * 
 * Usage:
 *   node scripts/find_web_client_id.js [path-to-google-services.json]
 */

const fs = require('fs');
const path = require('path');

const filePath = process.argv[2] || path.join(__dirname, '../android/app/src/galeriaKazimierzNew/google-services.json');

console.log(`\n🔍 Searching for Web Client ID in: ${filePath}\n`);

try {
    const content = fs.readFileSync(filePath, 'utf8');
    const config = JSON.parse(content);

    console.log(`📋 Project: ${config.project_info.project_id}`);
    console.log(`📋 Project Number: ${config.project_info.project_number}\n`);

    const webClients = [];

    // Search through all clients
    config.client.forEach((client, index) => {
        console.log(`\n📱 Client ${index + 1}:`);

        // Check oauth_client array
        if (client.oauth_client) {
            client.oauth_client.forEach((oauthClient) => {
                if (oauthClient.client_type === 3) {
                    // client_type: 3 = Web application
                    webClients.push({
                        clientId: oauthClient.client_id,
                        clientInfo: client.client_info
                    });
                    console.log(`  ✅ Web Client ID (type 3): ${oauthClient.client_id}`);
                } else if (oauthClient.client_type === 1) {
                    console.log(`  📱 Android Client (type 1): ${oauthClient.client_id}`);
                } else if (oauthClient.client_type === 2) {
                    console.log(`  🍎 iOS Client (type 2): ${oauthClient.client_id}`);
                }
            });
        }

        // Check services.appinvite_service.other_platform_oauth_client
        if (client.services && client.services.appinvite_service && client.services.appinvite_service.other_platform_oauth_client) {
            client.services.appinvite_service.other_platform_oauth_client.forEach((oauthClient) => {
                if (oauthClient.client_type === 3) {
                    webClients.push({
                        clientId: oauthClient.client_id,
                        clientInfo: client.client_info
                    });
                    console.log(`  ✅ Web Client ID (from appinvite, type 3): ${oauthClient.client_id}`);
                }
            });
        }
    });

    console.log(`\n${'='.repeat(60)}`);
    console.log(`\n🎯 Found ${webClients.length} Web Client ID(s):\n`);

    webClients.forEach((webClient, index) => {
        console.log(`${index + 1}. ${webClient.clientId}`);
    });

    if (webClients.length > 0) {
        console.log(`\n💡 Recommended Web Client ID: ${webClients[0].clientId}`);
        console.log(`\n📝 Use this in populate_firestore_config.js:\n`);
        console.log(`   googleSignInWebClientId: '${webClients[0].clientId}',`);
    } else {
        console.log(`\n⚠️  No Web Client ID found!`);
        console.log(`\n📝 You need to create one in Firebase Console:`);
        console.log(`   1. Go to Firebase Console > Authentication > Sign-in method`);
        console.log(`   2. Enable Google Sign-in`);
        console.log(`   3. Or go to Google Cloud Console > APIs & Services > Credentials`);
        console.log(`   4. Create OAuth 2.0 Client ID with type "Web application"`);
    }

    console.log(`\n`);

} catch (error) {
    console.error(`❌ Error reading file: ${error.message}`);
    process.exit(1);
}

