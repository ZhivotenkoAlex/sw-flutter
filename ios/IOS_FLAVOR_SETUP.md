# iOS Flavor Setup Instructions

## ⚠️ Manual Setup Required

iOS flavors require one-time manual configuration in Xcode. Follow these steps:

## Step 1: Open Project in Xcode

```bash
cd ios
open Runner.xcworkspace
```

## Step 2: Create Schemes

1. In Xcode menu: `Product` > `Scheme` > `Manage Schemes`
2. Click `+` to add new scheme
3. Duplicate `Runner` scheme
4. Name it: `galeriaKazimierz`
5. Repeat for each flavor:
   - `galeriaKazimierz`
   - `kazimierzClub`
   - `skanujNew`

## Step 3: Configure Bundle IDs

### Option A: Using User-Defined Settings

1. Select `Runner` project in left sidebar
2. Select `Runner` target
3. Go to `Build Settings` tab
4. Search for "Product Bundle Identifier"
5. Expand it and set per-configuration:

```
Debug-galeriaKazimierz: it.2take.galeriakazimierz
Release-galeriaKazimierz: it.2take.galeriakazimierz

Debug-kazimierzClub: pl.a2ti.kazimierzclub
Release-kazimierzClub: pl.a2ti.kazimierzclub

Debug-skanujNew: com.skanujwygrywaj.skanujWygrywaj
Release-skanujNew: com.skanujwygrywaj.skanujWygrywaj
```

### Option B: Using xcconfig Files

Create configuration files for each flavor:

1. Create `ios/Flutter/galeriaKazimierz.xcconfig`:

```
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER = it.2take.galeriakazimierz
```

2. Create `ios/Flutter/kazimierzClub.xcconfig`:

```
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER = pl.a2ti.kazimierzclub
```

3. Create `ios/Flutter/skanujNew.xcconfig`:

```
#include "Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER = com.skanujwygrywaj.skanujWygrywaj
```

## Step 4: Link Firebase Configs

For each flavor, you may need to create a Run Script phase:

1. Select `Runner` target
2. Go to `Build Phases` tab
3. Click `+` > `New Run Script Phase`
4. Add script:

```bash
# Select Firebase config based on flavor
FLAVOR="${CONFIGURATION}"
if [[ $FLAVOR == *"galeriaKazimierz"* ]]; then
    cp "${SRCROOT}/Runner/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
elif [[ $FLAVOR == *"kazimierzClub"* ]]; then
    cp "${SRCROOT}/Runner/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
elif [[ $FLAVOR == *"skanujNew"* ]]; then
    cp "${SRCROOT}/Runner/GoogleService-Info-new.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
fi
```

## Step 5: Test

```bash
# From project root
flutter run --flavor galeriaKazimierz
flutter run --flavor skanujNew
```

## Notes

- iOS flavor configuration is a one-time setup
- Each developer needs to do this in their local Xcode
- Changes are saved in `Runner.xcodeproj` (committed to git)
- Bundle IDs must match Firebase configurations

## Current Bundle IDs

| Flavor           | Bundle ID                           |
| ---------------- | ----------------------------------- |
| galeriaKazimierz | `it.2take.galeriakazimierz`         |
| kazimierzClub    | `pl.a2ti.kazimierzclub`             |
| skanujNew        | `com.skanujwygrywaj.skanujWygrywaj` |

## Troubleshooting

**Issue:** "Scheme not found"

- Solution: Create scheme in Xcode (Step 2)

**Issue:** "Bundle ID mismatch"

- Solution: Check Bundle ID in Build Settings matches Firebase config

**Issue:** "Wrong Firebase config loaded"

- Solution: Verify Run Script Phase selects correct plist file
