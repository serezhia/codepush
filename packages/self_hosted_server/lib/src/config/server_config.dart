import 'dart:io';

/// Server configuration loaded from environment variables.
class ServerConfig {
  const ServerConfig({
    required this.databaseUrl,
    required this.minioEndpoint,
    required this.minioAccessKey,
    required this.minioSecretKey,
    required this.minioBucket,
    required this.jwtSecret,
    required this.serverUrl,
    this.authIssuer,
    this.minioPublicEndpoint,
    this.port = 8080,
    this.corsOrigins = const ['*'],
  });

  /// Loads configuration from environment variables.
  factory ServerConfig.fromEnv() {
    return ServerConfig(
      databaseUrl: _required('DATABASE_URL'),
      minioEndpoint: _required('MINIO_ENDPOINT'),
      minioAccessKey: _required('MINIO_ACCESS_KEY'),
      minioSecretKey: _required('MINIO_SECRET_KEY'),
      minioBucket: _env('MINIO_BUCKET', 'artifacts'),
      minioPublicEndpoint: Platform.environment['MINIO_PUBLIC_ENDPOINT'],
      jwtSecret: _required('JWT_SECRET'),
      serverUrl: _env('SERVER_URL', 'http://localhost:8080'),
      authIssuer: Platform.environment['AUTH_ISSUER'],
      port: int.parse(_env('PORT', '8080')),
      corsOrigins: _env('CORS_ORIGINS', '*').split(','),
    );
  }

  final String databaseUrl;
  final String minioEndpoint;
  final String minioAccessKey;
  final String minioSecretKey;
  final String minioBucket;
  final String? minioPublicEndpoint;
  final String jwtSecret;
  final String serverUrl;

  /// JWT issuer — must match CLI's AUTH_SERVICE_URL. Defaults to serverUrl.
  final String? authIssuer;
  final int port;
  final List<String> corsOrigins;

  static String _required(String key) {
    final value = Platform.environment[key];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }
    return value;
  }

  static String _env(String key, String defaultValue) {
    return Platform.environment[key] ?? defaultValue;
  }
}
