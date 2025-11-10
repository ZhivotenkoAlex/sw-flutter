# 📚 Documentation Index

Quick reference for all project documentation.

## 🎯 Start Here

New to the project? Read these in order:

1. **[README.md](../README.md)** - Project overview, quick start, troubleshooting
2. **[FLAVORS_GUIDE.md](FLAVORS_GUIDE.md)** - Android & iOS flavor setup (required for development)
3. **[FIREBASE_CONFIG.md](FIREBASE_CONFIG.md)** - Firebase configuration and updates
4. **[DYNAMIC_CONFIGURATION.md](DYNAMIC_CONFIGURATION.md)** - Dynamic app configuration (change without release)

---

## 📖 Documentation Files

### [README.md](../README.md)

**Main project documentation**

What you'll find:

- ✅ Project overview and features
- ✅ Quick start installation
- ✅ How to run the app
- ✅ Building for production
- ✅ Common troubleshooting
- ✅ Architecture overview

**Read this:** When starting with the project, need quick reference commands, or encountering common issues.

---

### [FLAVORS_GUIDE.md](FLAVORS_GUIDE.md)

**Complete flavor setup guide for Android & iOS**

What you'll find:

- ✅ What flavors are and why we use them
- ✅ Step-by-step Android flavor setup
- ✅ Step-by-step iOS flavor setup (Xcode configuration)
- ✅ How to add a new flavor
- ✅ Testing flavors checklist
- ✅ Flavor-specific troubleshooting

**Read this:** 

- When setting up the project for the first time
- When adding a new company/flavor
- When iOS flavor commands don't work
- When you need to understand the flavor system

---

### [FIREBASE_CONFIG.md](FIREBASE_CONFIG.md)

**Firebase configuration and management**

What you'll find:

- ✅ Dual Firebase app architecture explanation
- ✅ Firebase project details (galeria-kazimierz-827d4 vs development-417611)
- ✅ Config file locations and structure
- ✅ How to update Firebase configs
- ✅ How to update Firestore configs
- ✅ Firestore database structure
- ✅ Firebase-specific troubleshooting

**Read this:**

- When updating Firebase settings
- When adding new Firebase projects
- When changing API keys or credentials
- When Firebase initialization fails
- When understanding the dual-app system

---

### [scripts/README.md](../scripts/README.md)

**Firestore population scripts**

What you'll find:

- ✅ How to populate Firestore with configs
- ✅ How to verify Firestore data
- ✅ Script prerequisites and setup
- ✅ Troubleshooting script issues

**Read this:** When updating or adding Firestore configurations.

---

### [DYNAMIC_CONFIGURATION.md](DYNAMIC_CONFIGURATION.md)

**Dynamic App Configuration via Firestore**

What you'll find:

- ✅ How to change app behavior without releasing new version
- ✅ Step-by-step instructions for Android & iOS
- ✅ Switching companies and databases dynamically
- ✅ UI theme switching (Legacy/Modern)
- ✅ Gradual rollout and instant rollback scenarios
- ✅ Complete testing guide
- ✅ Production deployment workflow
- ✅ Troubleshooting common issues

**Read this:** When you need to change app configuration, switch companies, or do gradual rollouts without releasing a new app version.

---

## 🗺️ Documentation Map by Task

### "I want to install and run the app"

→ [README.md](../README.md) - Quick Start section

### "I need to set up flavors on Android"

→ [FLAVORS_GUIDE.md](FLAVORS_GUIDE.md#android-flavor-setup)

### "I need to set up flavors on iOS"

→ [FLAVORS_GUIDE.md](FLAVORS_GUIDE.md#ios-flavor-setup)

### "I want to add a new company/flavor"

→ [FLAVORS_GUIDE.md](FLAVORS_GUIDE.md#adding-a-new-flavor)

### "I need to update Firebase credentials"

→ [FIREBASE_CONFIG.md](FIREBASE_CONFIG.md#updating-configs)

### "I need to change the webview URL"

→ [FIREBASE_CONFIG.md](FIREBASE_CONFIG.md#scenario-2-update-firestore-configs)

### "I want to understand the Firebase architecture"

→ [FIREBASE_CONFIG.md](FIREBASE_CONFIG.md#architecture-overview)

### "The app won't build/run"

→ [README.md](../README.md#troubleshooting) first, then flavor-specific guide

### "I'm getting INSTALL_FAILED_CONFLICTING_PROVIDER"

→ [README.md](../README.md#-install_failed_conflicting_provider) or use `./run_flavor.sh`

### "Xcode says no custom schemes"

→ [FLAVORS_GUIDE.md](FLAVORS_GUIDE.md#ios-flavor-setup)

### "Firebase initialization failed"

→ [FIREBASE_CONFIG.md](FIREBASE_CONFIG.md#-firebase-initialization-failed)

### "Config not found in Firestore"

→ [FIREBASE_CONFIG.md](FIREBASE_CONFIG.md#-config-not-found-in-firestore)

### "I want to change app configuration without new release"

→ [DYNAMIC_CONFIGURATION.md](DYNAMIC_CONFIGURATION.md)

### "I need to switch companies or databases"

→ [DYNAMIC_CONFIGURATION.md](DYNAMIC_CONFIGURATION.md#step-by-step-instructions)

### "I need to do a gradual rollout or rollback"

→ [DYNAMIC_CONFIGURATION.md](DYNAMIC_CONFIGURATION.md#production-deployment)

---

## 🚀 Quick Command Reference

```bash
# Run app (recommended method)
./run_flavor.sh galeriaKazimierz android
./run_flavor.sh galeriaKazimierzNew ios

# Build for production
flutter build apk --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz --release
flutter build ios --flavor galeriaKazimierzNew --dart-define=FLAVOR=galeriaKazimierzNew --release

# Populate Firestore configs
cd scripts && node populate_firestore_config.js

# Verify Firestore data
cd scripts && node verify_firestore_data.js

# Clean build
flutter clean && flutter pub get
```

---

## 📁 Key Files to Know

### Configuration Files

```
lib/flavor_config.dart          - Flavor definitions
lib/company_mapping.dart        - Package ID to company mapping
lib/services/secure_config_service.dart  - Firestore config fetching
```

### Android Config

```
android/app/build.gradle.kts    - Flavor definitions
android/app/src/{flavor}/google-services.json  - Firebase configs
```

### iOS Config

```
ios/Runner.xcworkspace          - Open in Xcode
ios/Runner/{flavor}/GoogleService-Info.plist  - Firebase configs
```

### Scripts

```
scripts/populate_firestore_config.js  - Populate Firestore
scripts/verify_firestore_data.js      - Verify Firestore
run_flavor.sh                         - Run helper script
```

---

## ✅ Documentation Checklist for New Developers

When onboarding a new developer, ensure they:

- [ ] Read [README.md](../README.md) - understand project structure
- [ ] Read [FLAVORS_GUIDE.md](FLAVORS_GUIDE.md) - understand flavors
- [ ] Set up Android flavors (if working on Android)
- [ ] Set up iOS flavors in Xcode (if working on iOS)
- [ ] Successfully run both flavors on their platform
- [ ] Read [FIREBASE_CONFIG.md](FIREBASE_CONFIG.md) - understand Firebase architecture
- [ ] Know how to populate/verify Firestore configs
- [ ] Bookmark this DOCUMENTATION.md for quick reference

---

## 🆘 Still Need Help?

1. **Search the documentation:** Use Cmd+F / Ctrl+F in the relevant guide
2. **Check troubleshooting sections:** Each guide has flavor/platform-specific troubleshooting
3. **Verify your setup:**

   ```bash
   # Check config files exist
   ls -la android/app/src/*/google-services.json
   ls -la ios/Runner/*/GoogleService-Info.plist
   
   # Verify Firestore
   cd scripts && node verify_firestore_data.js
   ```

4. **Clean and retry:**
   ```bash
   flutter clean
   flutter pub get
   ./run_flavor.sh [flavor] [platform]
   ```

---

**Documentation Version:** 1.0  
**Last Updated:** November 2025  
**Flavors:** galeriaKazimierz, galeriaKazimierzNew
