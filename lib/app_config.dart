class AppConfig {
  final String webviewUrl;
  final bool isLegacy;
  final String firebaseProject;
  final DateTime fetchedAt;
  final String? backendUrl;

  AppConfig({
    required this.webviewUrl,
    required this.isLegacy,
    required this.firebaseProject,
    required this.fetchedAt,
    this.backendUrl,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      webviewUrl: json['webviewUrl'] as String,
      isLegacy: json['isLegacy'] as bool,
      firebaseProject: json['firebaseProject'] as String,
      fetchedAt: DateTime.now(),
      backendUrl: json['backendUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'webviewUrl': webviewUrl,
      'isLegacy': isLegacy,
      'firebaseProject': firebaseProject,
      'fetchedAt': fetchedAt.toIso8601String(),
      'backendUrl': backendUrl,
    };
  }

  factory AppConfig.fromCachedJson(Map<String, dynamic> json) {
    return AppConfig(
      webviewUrl: json['webviewUrl'] as String,
      isLegacy: json['isLegacy'] as bool,
      firebaseProject: json['firebaseProject'] as String,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      backendUrl: json['backendUrl'] as String?,
    );
  }

  bool get isCacheStale {
    final now = DateTime.now();
    final age = now.difference(fetchedAt);
    return age.inHours >= 1; // 1 hour TTL
  }
}

