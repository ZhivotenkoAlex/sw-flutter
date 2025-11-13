# FCM Token Testing in Production

This guide explains how to access FCM (Firebase Cloud Messaging) tokens in production builds for testing push notifications.

## Overview

In production builds, console logs are not accessible, making it difficult to retrieve FCM tokens for testing push notifications. This app includes a **secret gesture** mechanism that allows authorized testers to view the FCM token without exposing it to regular users.

## Secret Gesture Access

### How to Access

1. **Locate the secret tap area**: Top-right corner of the screen (100x100 pixels)
2. **Perform the gesture**: Tap 7 times rapidly in the top-right corner
   - **Important**: The time between each consecutive tap must be **less than 1 second**
   - If more than 1 second passes between any two taps, the counter resets to 0
   - Example: Tap 1 → wait up to 1s → Tap 2 → wait up to 1s → Tap 3 → ... → Tap 7
3. **View the token**: A dialog will appear displaying the FCM token

### Gesture Details

| Parameter            | Value                                         |
| -------------------- | --------------------------------------------- |
| **Location**         | Top-right corner (within 100 pixels from right edge, 100 pixels from top) |
| **Required taps**    | 7 consecutive taps                            |
| **Timeout**          | Maximum 1 second between each consecutive tap |
| **Visual indicator** | None (invisible area)                         |

### Security Considerations

- ✅ **Hidden from users**: The tap area is completely invisible
- ✅ **No accidental activation**: Requires precise timing and location
- ✅ **Works in production**: Available in both debug and release builds
- ✅ **Token protection**: Token is shown in a modal dialog, reducing accidental sharing

## Using the Token Dialog

When the secret gesture is successfully performed, a dialog appears with:

- **Token length**: Character count of the FCM token
- **Full token**: Selectable text displaying the complete token
- **Copy button**: Copies the token to clipboard for easy sharing
- **Close button**: Dismisses the dialog

### Copying the Token

1. Tap the **Copy** button in the dialog
2. A confirmation snackbar appears: "Token copied to clipboard"
3. Paste the token where needed (e.g., Firebase Console, testing tool)

## Implementation Details

### Code Location

The secret gesture handler is implemented in:

- **File**: `lib/webview_screen_mobile.dart`
- **Method**: `_handleSecretTap()`
- **Dialog**: `_showFcmTokenDialog()`

### Key Components

```dart
// State variables
int _secretTapCount = 0;
DateTime? _lastTapTime;
static const int _secretTapThreshold = 7;
static const Duration _secretTapTimeout = Duration(seconds: 1);

// Gesture detection
GestureDetector(
  onTapDown: (TapDownDetails details) {
    _handleSecretTap(details.globalPosition, context);
  },
  // ...
)
```

### Token Retrieval

The FCM token is retrieved from:

```dart
FirebaseMessagingService.fcmToken
```

This token is automatically refreshed by Firebase when:

- App is reinstalled
- App data is cleared
- Token expires (rare, typically valid for months)

## Testing Workflow

### Step 1: Obtain Token

1. Launch the production build on a physical device
2. Perform the secret gesture (7 taps in top-right corner)
   - **Note**: Taps must be within 1 second of each other
   - Tap area is within 100 pixels from the right edge and 100 pixels from the top
3. Copy the token from the dialog

### Step 2: Send Test Notification

**Using Firebase Console:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your Firebase project
3. Navigate to **Cloud Messaging**
4. Click **Send your first message**
5. Enter notification title and text
6. Click **Send test message**
7. Paste the FCM token
8. Click **Test**

**Using cURL:**

```bash
curl -X POST https://fcm.googleapis.com/v1/projects/YOUR_PROJECT_ID/messages:send \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "YOUR_FCM_TOKEN",
      "notification": {
        "title": "Test Notification",
        "body": "This is a test message"
      }
    }
  }'
```

### Step 3: Verify Delivery

- Check device for notification
- Verify notification appears in system tray
- Test notification tap behavior (if configured)

## Troubleshooting

### ❌ Gesture Not Working

**Possible causes:**

1. **Tap area incorrect**: Ensure taps are in the exact top-right corner (within 100 pixels from right edge, 100 pixels from top)
2. **Timing too slow**: The time between each consecutive tap must be less than 1 second
3. **Counter reset**: If more than 1 second passes between any two taps, counter resets to 0

**Solution:**

- Tap rapidly and consistently in the top-right corner
- Count taps mentally: 1, 2, 3, 4, 5, 6, 7
- If dialog doesn't appear, start over

### ❌ Token Not Available

**Possible causes:**

1. **Firebase not initialized**: App may not have completed Firebase initialization
2. **Permissions not granted**: Notification permissions may be denied
3. **Token refresh pending**: Token may be refreshing

**Solution:**

- Wait a few seconds after app launch
- Check notification permissions in device settings
- Try the gesture again after a few seconds

### ❌ Token Dialog Shows "Token not available yet"

**Solution:**

- Wait for Firebase Messaging to initialize (usually 1-2 seconds after app launch)
- Ensure notification permissions are granted
- Check device internet connection
- Try the gesture again

## Best Practices

### ✅ DO

- Use this feature only for testing purposes
- Share tokens securely (avoid public channels)
- Test notifications on both Android and iOS
- Verify token validity before sending production notifications
- Document token usage for team reference

### ❌ DON'T

- Don't share tokens publicly
- Don't use production tokens for development testing
- Don't rely on tokens for long-term user identification (they can change)
- Don't expose the secret gesture to end users

## Removing the Feature

If you need to remove this feature for security reasons:

1. Remove the `GestureDetector` wrapper in `lib/webview_screen_mobile.dart`
2. Remove the `_handleSecretTap()` method
3. Remove the `_showFcmTokenDialog()` method
4. Remove state variables: `_secretTapCount`, `_lastTapTime`
5. Remove the invisible `Positioned` widget in the Stack

**Note:** Consider keeping this feature for production testing, as it's hidden from regular users and provides valuable debugging capabilities.

---

## Related Documentation

- [Firebase Configuration Guide](FIREBASE_CONFIG.md) - Firebase setup and configuration
- [Dynamic Configuration Guide](DYNAMIC_CONFIGURATION.md) - Firestore-based dynamic configuration
- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
