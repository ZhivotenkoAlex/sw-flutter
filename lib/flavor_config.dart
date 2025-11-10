enum FlavorType {
  galeriaKazimierz,
  galeriaKazimierzNew,
}

class FlavorConfig {
  final FlavorType flavor;
  final String name;
  final String packageId;
  final String companyId;

  FlavorConfig({
    required this.flavor,
    required this.name,
    required this.packageId,
    required this.companyId,
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
    print('[Flavor] DEBUG: fromEnvironment returned: "$flavorEnv" (isEmpty: ${flavorEnv.isEmpty})');
    if (flavorEnv.isNotEmpty) {
      final flavor = _flavorFromString(flavorEnv);
      print('[Flavor] DEBUG: _flavorFromString returned: $flavor');
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
      case 'galeriakazimierznew':
      case 'galeria_kazimierz_new':
      case 'galeria-kazimierz-new':
      case 'kazimierz-club-new':
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
        );

      case FlavorType.galeriaKazimierzNew:
        return FlavorConfig(
          flavor: FlavorType.galeriaKazimierzNew,
          name: 'Galeria Kazimierz New',
          packageId: 'com.skanujwygrywaj.skanuj_wygrywaj',
          companyId: 'kazimierz-club-new',
        );
    }
  }


  @override
  String toString() {
    return 'FlavorConfig(name: $name, packageId: $packageId, companyId: $companyId)';
  }
}
