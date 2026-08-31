enum FcmTokenGestureCorner {
  topLeft,
  topRight;

  static FcmTokenGestureCorner fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'topleft':
      case 'top_left':
      case 'top-left':
        return FcmTokenGestureCorner.topLeft;
      case 'topright':
      case 'top_right':
      case 'top-right':
      default:
        return FcmTokenGestureCorner.topRight;
    }
  }

  String toFirestoreValue() {
    switch (this) {
      case FcmTokenGestureCorner.topLeft:
        return 'topLeft';
      case FcmTokenGestureCorner.topRight:
        return 'topRight';
    }
  }
}
