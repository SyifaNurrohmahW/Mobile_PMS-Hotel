enum AppFlavor { dev, staging, production }

class AppConfig {
  const AppConfig._();

  static const String appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.18:8000/api/v1',
  );

  static const List<String> fallbackCandidateUrls = [
    'http://192.168.1.18:8000/api/v1',
    'http://192.168.18.123:8000/api/v1',
    'http://192.168.1.155:8000/api/v1',
  ];

  /// Override runtime jika pengguna mengubah IP Server langsung dari dalam aplikasi
  static String? runtimeApiBaseUrl;

  static String get effectiveApiBaseUrl {
    final custom = runtimeApiBaseUrl?.trim();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return apiBaseUrl;
  }

  static String get serverOrigin {
    final uri = Uri.tryParse(effectiveApiBaseUrl);
    if (uri == null) return 'http://192.168.1.18:8000';
    return '${uri.scheme}://${uri.authority}';
  }

  static String get serverHost {
    final uri = Uri.tryParse(effectiveApiBaseUrl);
    if (uri == null || uri.host.isEmpty) return '192.168.1.18';
    return uri.host;
  }

  static String? resolveAssetUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final parsed = Uri.tryParse(trimmed);
      if (parsed != null) {
        if (parsed.host == 'localhost' ||
            parsed.host == '127.0.0.1' ||
            parsed.path.startsWith('/api/assets/uploads') ||
            parsed.path.startsWith('/uploads')) {
          return '$serverOrigin${parsed.path}';
        }
      }
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      return '$serverOrigin$trimmed';
    }
    return '$serverOrigin/$trimmed';
  }

  static AppFlavor get flavor {
    switch (appEnvironment.toLowerCase()) {
      case 'staging':
        return AppFlavor.staging;
      case 'production':
        return AppFlavor.production;
      default:
        return AppFlavor.dev;
    }
  }

  static String get flavorLabel => switch (flavor) {
        AppFlavor.dev => 'Development',
        AppFlavor.staging => 'Staging',
        AppFlavor.production => 'Production',
      };
}
