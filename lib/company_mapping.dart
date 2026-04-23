import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'flavor_config.dart';

class CompanyMapping {
  static String? _cachedCompanyId;

  /// Get company ID from flavor or package identifier
  /// 
  /// Priority:
  /// 1. --dart-define=COMPANY_ID override (for debugging)
  /// 2. Flavor configuration (if initialized)
  /// 3. Package identifier extraction
  /// 
  /// For debugging, use: flutter run --dart-define=COMPANY_ID=test-company
  static Future<String> getCompanyId() async {
    // Return cached value if available
    if (_cachedCompanyId != null) {
      return _cachedCompanyId!;
    }

    // Check for --dart-define override (useful for debugging)
    const companyIdOverride = String.fromEnvironment('COMPANY_ID');
    if (companyIdOverride.isNotEmpty) {
      print('[CompanyMapping] Using COMPANY_ID from --dart-define: $companyIdOverride');
      _cachedCompanyId = companyIdOverride;
      return companyIdOverride;
    }

    // Use flavor config if available
    if (FlavorConfig.isInitialized) {
      final companyId = FlavorConfig.instance.companyId;
      print('[CompanyMapping] Using company ID from flavor: $companyId');
      _cachedCompanyId = companyId;
      return companyId;
    }

    // Get from package identifier (fallback)
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final packageName = packageInfo.packageName;
      print('[CompanyMapping] Package name: $packageName');

      // Extract company ID from package name
      final companyId = _extractCompanyIdFromPackage(packageName);
      _cachedCompanyId = companyId;
      return companyId;
    } catch (e) {
      print('[CompanyMapping] Failed to get package info: $e');
      // Default fallback
      _cachedCompanyId = 'galeria-kazimierz';
      return _cachedCompanyId!;
    }
  }

  /// Extract company ID from package name
  /// 
  /// Mapping rules (aligned with flavors):
  /// - pl.a2ti.galeriakazimierz -> galeria-kazimierz
  /// - com.skanujwygrywaj.skanuj_wygrywaj -> kazimierz-club-new
  static String _extractCompanyIdFromPackage(String packageName) {
    // Known package mappings (should match flavor configs)
    const Map<String, String> packageMappings = {
      'pl.a2ti.galeriakazimierz': 'galeria-kazimierz',
      'com.skanujwygrywaj.skanuj_wygrywaj': 'kazimierz-club-new',
      'com.polbau.polbau_demo': 'polbau-demo',
      'com.wislanka.wislanka': 'wislanka',
      'com.starybrowar.stary_browar': 'stary-browar',
      // Add more mappings as needed
    };

    // Check if we have a direct mapping
    if (packageMappings.containsKey(packageName)) {
      return packageMappings[packageName]!;
    }

    // Try to extract from the last part of the package name
    final parts = packageName.split('.');
    if (parts.isNotEmpty) {
      final lastPart = parts.last;
      // Convert camelCase to kebab-case
      final kebabCase = _camelToKebab(lastPart);
      print('[CompanyMapping] Extracted company ID from package: $kebabCase');
      return kebabCase;
    }

    // Ultimate fallback
    print('[CompanyMapping] Could not extract company ID, using default');
    return 'galeria-kazimierz';
  }

  /// Convert camelCase or PascalCase to kebab-case
  /// 
  /// Examples:
  /// - galeriakazimierz -> galeria-kazimierz (if we can't detect word boundaries, return as-is)
  /// - galeriaKazimierz -> galeria-kazimierz
  /// - GaleriaKazimierz -> galeria-kazimierz
  static String _camelToKebab(String input) {
    if (input.isEmpty) return input;

    // Insert hyphens before uppercase letters and convert to lowercase
    final result = input.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)}-${match.group(2)}',
    ).toLowerCase();

    return result;
  }

  /// Clear cached company ID (useful for testing)
  static void clearCache() {
    _cachedCompanyId = null;
  }

  /// Set company ID manually (useful for testing)
  @visibleForTesting
  static void setCompanyId(String companyId) {
    _cachedCompanyId = companyId;
  }
}

