import 'package:postgres/postgres.dart';

/// Data access layer for users.
class UserRepository {
  const UserRepository(this._pool);

  final Pool _pool;

  /// Creates a new user. Returns the created user's id.
  Future<int> create({
    required String email,
    required String displayName,
    required String passwordHash,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        '''INSERT INTO users (email, display_name, password_hash)
           VALUES (@email, @displayName, @passwordHash)
           RETURNING id''',
      ),
      parameters: {
        'email': email,
        'displayName': displayName,
        'passwordHash': passwordHash,
      },
    );
    return result.first[0]! as int;
  }

  /// Finds a user by email. Returns null if not found.
  Future<Map<String, dynamic>?> findByEmail(String email) async {
    final result = await _pool.execute(
      Sql.named('SELECT * FROM users WHERE email = @email'),
      parameters: {'email': email},
    );
    if (result.isEmpty) return null;
    return _rowToMap(result.first);
  }

  /// Finds a user by id. Returns null if not found.
  Future<Map<String, dynamic>?> findById(int id) async {
    final result = await _pool.execute(
      Sql.named('SELECT * FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _rowToMap(result.first);
  }

  /// Deletes a user by id.
  Future<void> delete(int id) async {
    await _pool.execute(
      Sql.named('DELETE FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Map<String, dynamic> _rowToMap(ResultRow row) {
    final schema = row.toColumnMap();
    return {
      'id': schema['id'],
      'email': schema['email'],
      'display_name': schema['display_name'],
      'password_hash': schema['password_hash'],
      'created_at': schema['created_at'],
      'updated_at': schema['updated_at'],
    };
  }
}
