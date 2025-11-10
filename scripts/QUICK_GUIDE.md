# 🚀 Quick Guide - Configuration Changes

## ⚡ Quick Start

### Switch Users to NEW App

```bash
cd scripts
node update_single_config.js
```

**Result:** All `galeria-kazimierz` users will receive on next app launch:
- 🆕 New UI (purple theme)
- 🆕 New database (`kazimierz-club-new`)
- 🆕 New functionality

---

### Rollback to OLD App

```bash
cd scripts
node rollback_to_old_config.js
```

**Result:** All users will return to old version:
- 🔵 Old UI (blue theme)
- 🔵 Old database (`galeria-kazimierz`)
- 🔵 Old functionality

---

## 📋 What Changes in Database?

### When Switching to NEW App (`update_single_config.js`):

| Field              | Before (old)                | After (new)                  |
|--------------------|-----------------------------|-------------------------------|
| `companyId`        | `galeria-kazimierz`         | `kazimierz-club-new`          |
| `isLegacy`         | `true`                      | `false`                       |
| `firebaseProject`  | `galeria-kazimierz-827d4`   | `development-417611`          |
| `webviewUrl`       | `https://login.2take.it/...` | `https://skanuj.staging.web...` |
| `version`          | `1`                         | `2`                           |

---

## 🎯 When to Use?

### `update_single_config.js` ⭐
- ✅ When all data is migrated to new database
- ✅ When new app version is tested
- ✅ When ready to switch all users
- ✅ When gradual migration is needed

### `rollback_to_old_config.js` 🔙
- 🚨 If critical bug found in new version
- 🚨 If users report issues
- 🚨 Emergency rollback needed

---

## ⚠️ IMPORTANT!

### Before Migration Ensure:

1. ✅ **All user data is migrated** to new database `kazimierz-club-new`
2. ✅ **New version is tested** on test device
3. ✅ **Backend API works** with `companyId: kazimierz-club-new`
4. ✅ **Rollback plan exists** (script `rollback_to_old_config.js` is ready)

### After Configuration Change:

1. 📱 **Users must restart the app** (close and reopen)
2. 🔍 **Monitor logs** for errors:
   ```bash
   flutter logs | grep "Loaded companyId"
   # Should show: kazimierz-club-new (after migration)
   ```
3. 📊 **Check metrics** - verify all users successfully switched

---

## 🔍 Verify Configuration

### View Current Configuration in Database:

```bash
cd scripts
node verify_firestore_data.js
```

### Check Configuration in App (logs):

```bash
flutter logs | grep -E "(companyId|isLegacy|UI Mode)"
```

**Expected Result After Migration:**
```
[SecureConfig] Loaded companyId: kazimierz-club-new
[MyApp] UI Mode: Modern Mode (isLegacy=false)
[WebViewScreen] Loading Modern mode, URL: https://skanuj.staging.web.app/...
```

**Expected Result After Rollback:**
```
[SecureConfig] Loaded companyId: galeria-kazimierz
[MyApp] UI Mode: Legacy Mode (isLegacy=true)
[WebViewScreen] Loading Legacy mode, URL: https://login.2take.it/...
```

---

## 🏢 Firebase Console Location

If you want to change manually:

```
Firebase Console
→ Project: development-417611
→ Firestore Database
→ Database: skanuj-wygrywaj
→ Collection: mobile_configs
→ Document: galeria-kazimierz  ← Edit here
```

**But it's recommended to use scripts to avoid errors!**

---

## 📞 Troubleshooting

### Error: "Cannot find module 'firebase-admin'"
```bash
cd scripts
npm install firebase-admin
```

### Error: "Permission denied"
```bash
gcloud auth application-default login
```

### App Shows Old Configuration After Update
1. Verify script executed successfully
2. Run `node verify_firestore_data.js` and check data
3. Fully close app and reopen
4. Check logs: `flutter logs`

---

## 📚 Detailed Documentation

- **Full Documentation:** [scripts/README.md](README.md)
- **Dynamic Configuration:** [docs/DYNAMIC_CONFIGURATION.md](../docs/DYNAMIC_CONFIGURATION.md)
- **Firebase Setup:** [docs/FIREBASE_CONFIG.md](../docs/FIREBASE_CONFIG.md)

---

## 💡 Tips

1. **Test on dev device first** before production migration
2. **Do migration in non-peak hours** (when fewer users online)
3. **Monitor logs** first 15-30 minutes after migration
4. **Keep rollback script ready** in case of issues
5. **Inform users** about need to restart the app

---

**🎯 Main Idea:** Just run the script, and all users will switch to new/old version on next app launch!

