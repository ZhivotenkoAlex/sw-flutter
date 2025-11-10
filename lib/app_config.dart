class AppConfig {
  final String webviewUrl;
  final bool isLegacy;
  final String firebaseProject;
  final DateTime fetchedAt;

  AppConfig({
    required this.webviewUrl,
    required this.isLegacy,
    required this.firebaseProject,
    required this.fetchedAt,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      webviewUrl: json['webviewUrl'] as String,
      isLegacy: json['isLegacy'] as bool,
      firebaseProject: json['firebaseProject'] as String,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'webviewUrl': webviewUrl,
      'isLegacy': isLegacy,
      'firebaseProject': firebaseProject,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  factory AppConfig.fromCachedJson(Map<String, dynamic> json) {
    return AppConfig(
      webviewUrl: json['webviewUrl'] as String,
      isLegacy: json['isLegacy'] as bool,
      firebaseProject: json['firebaseProject'] as String,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }

  bool get isCacheStale {
    final now = DateTime.now();
    final age = now.difference(fetchedAt);
    return age.inHours >= 1; // 1 hour TTL
  }
}

