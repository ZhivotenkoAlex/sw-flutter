import 'app_config.dart';

enum FlavorType {
  galeriaKazimierz,
  galeriaKazimierzNew,
}

class FlavorConfig {
  final FlavorType flavor;
  final String name;
  final String packageId;
  final String companyId;
  final bool isLegacyByDefault;
  final String firebaseProject;
  final String defaultWebviewUrl;
  final String? defaultBackendUrl;

  FlavorConfig({
    required this.flavor,
    required this.name,
    required this.packageId,
    required this.companyId,
    required this.isLegacyByDefault,
    required this.firebaseProject,
    required this.defaultWebviewUrl,
    this.defaultBackendUrl,
  });

  static FlavorConfig? _instance;

  static FlavorConfig get instance {
    if (_instance == null) {
      throw StateError('FlavorConfig not initialized. Call FlavorConfig.initialize() first.');
    }
    return _instance!;
  }

  static bool get isInitialized => _instance != null;

  /// Initialize flavor configuration
  /// 
  /// Call this early in main() before anything else
  static void initialize(FlavorType flavor) {
    _instance = _getConfigForFlavor(flavor);
    print('[Flavor] Initialized: ${_instance!.name} (${_instance!.flavor})');
  }

  /// Auto-detect flavor from package ID (fallback)
  static Future<FlavorConfig> autoDetect() async {
    // Try to detect from --dart-define
    const flavorEnv = String.fromEnvironment('FLAVOR');
    if (flavorEnv.isNotEmpty) {
      final flavor = _flavorFromString(flavorEnv);
      if (flavor != null) {
        initialize(flavor);
        return instance;
      }
    }

    // Default to galeriaKazimierz
    print('[Flavor] No flavor specified, defaulting to galeriaKazimierz');
    initialize(FlavorType.galeriaKazimierz);
    return instance;
  }

  static FlavorType? _flavorFromString(String str) {
    switch (str.toLowerCase()) {
      case 'galeriakazimierz':
      case 'galeria_kazimierz':
      case 'galeria-kazimierz':
        return FlavorType.galeriaKazimierz;
      case 'galeriakazimiernew':
      case 'galeria_kazimierz_new':
      case 'galeria-kazimierz-new':
        return FlavorType.galeriaKazimierzNew;
      default:
        return null;
    }
  }

  static FlavorConfig _getConfigForFlavor(FlavorType flavor) {
    switch (flavor) {
      case FlavorType.galeriaKazimierz:
        return FlavorConfig(
          flavor: FlavorType.galeriaKazimierz,
          name: 'Galeria Kazimierz',
          packageId: 'pl.a2ti.galeriakazimierz',
          companyId: 'galeria-kazimierz',
          isLegacyByDefault: true,
          firebaseProject: 'galeria-kazimierz',
          defaultWebviewUrl: 'https://login.2take.it/?company_name=galeria-kazimierz&legacy=true&d=9e30d60cdabaa8c6859b7ee737cd943b23d727b3',
          defaultBackendUrl: 'https://europe-central2-galeria-kazimierz-827d4.cloudfunctions.net/legacy-backend',
        );

      case FlavorType.galeriaKazimierzNew:
        return FlavorConfig(
          flavor: FlavorType.galeriaKazimierzNew,
          name: 'Galeria Kazimierz New',
          packageId: 'com.skanujwygrywaj.skanuj_wygrywaj',
          companyId: 'galeria-kazimierz-new',
          isLegacyByDefault: false,
          firebaseProject: 'development-417611',
          defaultWebviewUrl: 'https://skanuj-staging.web.app?company_name=galeria-kazimierz-new',
          defaultBackendUrl: 'https://europe-central2-development-417611.cloudfunctions.net/kanuj-wygrywaj-backend',
        );
    }
  }

  /// Create a default AppConfig based on flavor
  AppConfig createDefaultAppConfig() {
    return AppConfig(
      webviewUrl: defaultWebviewUrl,
      isLegacy: isLegacyByDefault,
      firebaseProject: firebaseProject,
      fetchedAt: DateTime.now(),
      backendUrl: defaultBackendUrl,
    );
  }

  @override
  String toString() {
    return 'FlavorConfig(name: $name, packageId: $packageId, companyId: $companyId)';
  }
}

