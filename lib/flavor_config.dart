enum FlavorType {
  galeriaKazimierz,
  galeriaKazimierzNew,
  polbauDemo,
  wislanka,
  staryBrowar,
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
      case 'polbaudemo':
      case 'polbau_demo':
      case 'polbau-demo':
        return FlavorType.polbauDemo;
      case 'wislanka':
        return FlavorType.wislanka;
      case 'starybrowar':
      case 'stary_browar':
      case 'stary-browar':
        return FlavorType.staryBrowar;
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

      case FlavorType.polbauDemo:
        return FlavorConfig(
          flavor: FlavorType.polbauDemo,
          name: 'Moja Galeria',
          packageId: 'com.polbau.polbau',
          companyId: 'polbau-demo',
        );

      case FlavorType.wislanka:
        return FlavorConfig(
          flavor: FlavorType.wislanka,
          name: 'Wislanka',
          packageId: 'com.wislanka.wislanka',
          companyId: 'wislanka',
        );

      case FlavorType.staryBrowar:
        return FlavorConfig(
          flavor: FlavorType.staryBrowar,
          name: 'Stary Browar',
          packageId: 'com.starybrowar.stary_browar',
          companyId: 'stary-browar',
        );
    }
  }


  @override
  String toString() {
    return 'FlavorConfig(name: $name, packageId: $packageId, companyId: $companyId)';
  }
}
