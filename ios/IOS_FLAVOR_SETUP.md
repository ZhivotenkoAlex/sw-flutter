# iOS Flavor Setup - Complete Guide

## ✅ Status: Ready for Xcode Configuration

All flavor files have been created. You just need a **one-time Xcode setup** (10-15 minutes).

## What's Already Done

- ✅ Firebase configs created (at both `ios/` and `ios/Runner/` levels)
- ✅ Info.plist files for app display names
- ✅ xcconfig files with bundle IDs
- ✅ build_flavor.sh supports iOS builds

## Next Steps (One-Time Setup)

### Step 1: Open Project in Xcode

```bash
cd ios
open Runner.xcworkspace
```

**Important:** Open `Runner.xcworkspace`, NOT `Runner.xcodeproj`

### Step 2: Create Build Configurations

1. Select **Runner** project (blue icon at top of left sidebar)
2. Select **Runner** target under TARGETS
3. Go to **Info** tab
4. Under **Configurations**, click **+** button
5. Select **Duplicate "Debug" Configuration**
6. Name it: `Debug-galeriaKazimierz`
7. Repeat to create all:
   - `Debug-galeriaKazimierz`
   - `Debug-kazimierzClub`
   - `Debug-skanujNew`
   - `Release-galeriaKazimierz`
   - `Release-kazimierzClub`
   - `Release-skanujNew`

### Step 3: Link xcconfig Files

For each configuration:

1. Select the configuration (e.g., `Debug-galeriaKazimierz`)
2. In the dropdown next to **Runner** target, select the matching xcconfig:
   - `Debug-galeriaKazimierz` → `Debug-galeriaKazimierz`
   - `Release-galeriaKazimierz` → `Release-galeriaKazimierz`
   - etc.

### Step 4: Create Schemes

1. Menu: `Product` > `Scheme` > `Manage Schemes`
2. Click **+** button
3. Name: `galeriaKazimierz`, Target: **Runner**
4. Repeat for: `kazimierzClub`, `skanujNew`

### Step 5: Configure Each Scheme

For each scheme (galeriaKazimierz, kazimierzClub, skanujNew):

1. Select scheme, click **Edit Scheme**
2. **Run** → Build Configuration: `Debug-{flavorName}`
3. **Archive** → Build Configuration: `Release-{flavorName}`
4. Click **Close**

### Step 6: Add Firebase Config Copy Script

1. Select **Runner** target → **Build Phases** tab
2. Click **+** → **New Run Script Phase**
3. Name: "Copy Firebase Config"
4. Drag BEFORE "Run Script" (Flutter build)
5. Paste script below
6. Check "Show environment variables in build log"

```bash
# Copy Firebase config and merge Info.plist based on flavor
FLAVOR_CONFIG="${CONFIGURATION}"
FLAVOR_NAME="${FLAVOR_CONFIG%%-*}"

echo "🔧 Configuration: ${CONFIGURATION}"
echo "🏷️  Flavor: ${FLAVOR_NAME}"

# Firebase config paths
FLAVOR_DIR_IOS="${SRCROOT}/../${FLAVOR_NAME}"
FLAVOR_DIR_RUNNER="${SRCROOT}/${FLAVOR_NAME}"
DEST_FIREBASE="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"

# Copy Firebase config
if [ -f "$FLAVOR_DIR_IOS/GoogleService-Info.plist" ]; then
  cp "$FLAVOR_DIR_IOS/GoogleService-Info.plist" "$DEST_FIREBASE"
  echo "✅ Firebase: $FLAVOR_DIR_IOS"
elif [ -f "$FLAVOR_DIR_RUNNER/GoogleService-Info.plist" ]; then
  cp "$FLAVOR_DIR_RUNNER/GoogleService-Info.plist" "$DEST_FIREBASE"
  echo "✅ Firebase: $FLAVOR_DIR_RUNNER"
else
  echo "⚠️  Using default Firebase config"
  cp "${SRCROOT}/GoogleService-Info.plist" "$DEST_FIREBASE" 2>/dev/null || true
fi

# Merge flavor-specific Info.plist for app name
FLAVOR_INFO="${SRCROOT}/${FLAVOR_NAME}/Info.plist"
if [ -f "$FLAVOR_INFO" ]; then
  /usr/libexec/PlistBuddy -c "Merge '${FLAVOR_INFO}'" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}" 2>/dev/null || true
  echo "✅ App name merged from: $FLAVOR_INFO"
fi
```

### Step 7: Test

```bash
# Test from command line
flutter run --flavor galeriaKazimierz --dart-define=FLAVOR=galeriaKazimierz
flutter run --flavor skanujNew --dart-define=FLAVOR=skanujNew

# Or use build script
./build_flavor.sh galeriaKazimierz ios debug
```

## Bundle IDs & Firebase

| Flavor | Bundle ID | Firebase Project | App Name |
|--------|-----------|------------------|----------|
| galeriaKazimierz | it.2take.galeriakazimierz | galeria-kazimierz-827d4 | Galeria Kazimierz |
| kazimierzClub | pl.a2ti.kazimierzclub | galeria-kazimierz-827d4 | Kazimierz Club |
| skanujNew | com.skanujwygrywaj.skanujWygrywaj | development-417611 | Skanuj Wygrywaj |

## Verification

After setup, verify:
- [ ] Each scheme appears in Xcode
- [ ] App shows correct name on device
- [ ] Firebase logs show correct project
- [ ] `flutter run --flavor X` works

## Troubleshooting

**Scheme not found**: Re-create in Xcode (Step 4)

**Wrong bundle ID**: Check xcconfig file is linked (Step 3)

**Wrong Firebase**: Verify Run Script order (Step 6)

**App name doesn't change**: Check Info.plist merge in Run Script

## File Structure

```
ios/
├── galeriaKazimierz/GoogleService-Info.plist
├── kazimierzClub/GoogleService-Info.plist
├── skanujNew/GoogleService-Info.plist
├── Flutter/
│   ├── Debug-galeriaKazimierz.xcconfig
│   ├── Release-galeriaKazimierz.xcconfig
│   ├── Debug-kazimierzClub.xcconfig
│   ├── Release-kazimierzClub.xcconfig
│   ├── Debug-skanujNew.xcconfig
│   └── Release-skanujNew.xcconfig
└── Runner/
    ├── galeriaKazimierz/
    │   ├── GoogleService-Info.plist
    │   └── Info.plist
    ├── kazimierzClub/
    │   ├── GoogleService-Info.plist
    │   └── Info.plist
    └── skanujNew/
        ├── GoogleService-Info.plist
        └── Info.plist
```

## Done!

After this one-time setup, iOS flavors work exactly like Android! 🎉
