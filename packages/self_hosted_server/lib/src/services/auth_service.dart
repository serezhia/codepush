import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:postgres/postgres.dart';
import 'package:self_hosted_server/src/repositories/user_repository.dart';

/// Service for authentication: password hashing, JWT signing/verification,
/// and refresh token management.
class AuthService {
  AuthService({
    required this.userRepository,
    required this.pool,
    required String jwtSecret,
    required this.serverUrl,
    this.tokenExpiry = const Duration(minutes: 15),
    this.refreshTokenExpiry = const Duration(days: 30),
  }) : _jwtKey = SecretKey(jwtSecret);

  final UserRepository userRepository;
  final Pool pool;
  final SecretKey _jwtKey;
  final String serverUrl;
  final Duration tokenExpiry;
  final Duration refreshTokenExpiry;

  /// Hashes a password using bcrypt.
  String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Verifies a password against a bcrypt hash.
  bool verifyPassword(String password, String hash) {
    return BCrypt.checkpw(password, hash);
  }

  /// Creates a JWT for the given user.
  String createJwt({
    required int userId,
    required String email,
    String? displayName,
  }) {
    final jwt = JWT(
      {
        'email': email,
        if (displayName != null) 'name': displayName,
      },
      issuer: serverUrl,
      subject: userId.toString(),
      audience: Audience.one(serverUrl),
      header: {'kid': 'self-hosted'},
    );

    return jwt.sign(
      _jwtKey,
      expiresIn: tokenExpiry,
    );
  }

  /// Verifies and decodes a JWT. Returns the payload or throws.
  JWT verifyJwt(String token) {
    return JWT.verify(token, _jwtKey, issuer: serverUrl);
  }

  /// Extracts user id from a verified JWT.
  int getUserIdFromJwt(JWT jwt) {
    final sub = jwt.subject;
    if (sub == null) throw const FormatException('JWT missing subject');
    return int.parse(sub);
  }

  /// Creates a refresh token, stores its hash, and returns the raw token.
  Future<String> createRefreshToken(int userId) async {
    final token = _generateSecureToken();
    final tokenHash = _hashToken(token);

    await pool.execute(
      Sql.named(
        '''INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
           VALUES (@userId, @tokenHash, @expiresAt)''',
      ),
      parameters: {
        'userId': userId,
        'tokenHash': tokenHash,
        'expiresAt': DateTime.now().toUtc().add(refreshTokenExpiry),
      },
    );

    return token;
  }

  /// Validates a refresh token and returns the user id.
  /// Deletes the used token (rotation).
  Future<int?> validateRefreshToken(String token) async {
    final tokenHash = _hashToken(token);

    final result = await pool.execute(
      Sql.named(
        '''DELETE FROM refresh_tokens
           WHERE token_hash = @tokenHash AND expires_at > NOW()
           RETURNING user_id''',
      ),
      parameters: {'tokenHash': tokenHash},
    );

    if (result.isEmpty) return null;
    return result.first[0]! as int;
  }

  /// Revokes all refresh tokens for a user.
  Future<void> revokeAllTokens(int userId) async {
    await pool.execute(
      Sql.named('DELETE FROM refresh_tokens WHERE user_id = @userId'),
      parameters: {'userId': userId},
    );
  }

  /// Creates a short-lived auth code for the CLI loopback flow.
  /// The code maps to a user id and is stored as a refresh token with
  /// a very short expiry.
  Future<String> createAuthCode(int userId) async {
    final code = _generateSecureToken(length: 32);
    final codeHash = _hashToken(code);

    await pool.execute(
      Sql.named(
        '''INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
           VALUES (@userId, @codeHash, @expiresAt)''',
      ),
      parameters: {
        'userId': userId,
        'codeHash': codeHash,
        'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 5)),
      },
    );

    return code;
  }

  /// Exchanges an auth code for tokens. Returns null if code is invalid.
  Future<({String accessToken, String refreshToken})?> exchangeAuthCode(
    String code,
  ) async {
    final userId = await validateRefreshToken(code);
    if (userId == null) return null;

    final user = await userRepository.findById(userId);
    if (user == null) return null;

    final accessToken = createJwt(
      userId: userId,
      email: user['email'] as String,
      displayName: user['display_name'] as String?,
    );
    final refreshToken = await createRefreshToken(userId);

    return (accessToken: accessToken, refreshToken: refreshToken);
  }

  String _generateSecureToken({int length = 48}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashToken(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }
}
