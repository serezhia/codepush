import 'dart:io';

import 'package:postgres/postgres.dart';

/// PostgreSQL database connection pool manager.
///
/// Manages connection lifecycle, pool creation, and SQL migration execution.
class Database {
  /// Creates a [Database] from a connection string.
  ///
  /// Expected format: `postgres://user:password@host:port/dbname`
  Database({required String connectionString})
    : _endpoint = _parseConnectionString(connectionString);

  /// Creates a [Database] from pre-defined endpoint.
  Database.fromEndpoint({required Endpoint endpoint}) : _endpoint = endpoint;

  final Endpoint _endpoint;
  Pool? _pool;

  /// Active connection pool.
  Pool get pool {
    final p = _pool;
    if (p == null) throw StateError('Database not initialized. Call open().');
    return p;
  }

  /// Opens the connection pool.
  Future<void> open({int maxConnections = 10}) async {
    _pool = Pool.withEndpoints(
      [_endpoint],
      settings: PoolSettings(
        maxConnectionCount: maxConnections,
        sslMode: SslMode.disable,
      ),
    );
  }

  /// Runs all pending SQL migrations from [migrationsDir].
  Future<void> migrate({String migrationsDir = 'db/migrations'}) async {
    // Ensure _migrations table exists
    await pool.execute('''
      CREATE TABLE IF NOT EXISTS _migrations (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    ''');

    final applied = await pool.execute('SELECT name FROM _migrations');
    final appliedNames = applied.map((r) => r[0]! as String).toSet();

    final dir = Directory(migrationsDir);
    if (!dir.existsSync()) return;

    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final name = file.uri.pathSegments.last;
      if (appliedNames.contains(name)) continue;

      final sql = file.readAsStringSync();
      // postgres package doesn't support multi-statement prepared queries.
      // Strip SQL comments and split on semicolons.
      final cleaned = sql.replaceAll(RegExp(r'--[^\n]*'), '');
      final statements = cleaned
          .split(';')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);
      for (final stmt in statements) {
        await pool.execute(stmt);
      }
      await pool.execute(
        Sql.named('INSERT INTO _migrations (name) VALUES (@name)'),
        parameters: {'name': name},
      );
    }
  }

  /// Closes the connection pool.
  Future<void> close() async {
    await _pool?.close();
    _pool = null;
  }

  static Endpoint _parseConnectionString(String url) {
    final uri = Uri.parse(url);
    return Endpoint(
      host: uri.host,
      port: uri.port == 0 ? 5432 : uri.port,
      database: uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : 'shorebird',
      username: uri.userInfo.contains(':')
          ? uri.userInfo.split(':').first
          : uri.userInfo,
      password: uri.userInfo.contains(':')
          ? uri.userInfo.split(':').last
          : null,
    );
  }
}
