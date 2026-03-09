/// Interface for persisting auth tokens.
abstract interface class IAuthStorage {
  String? get accessToken;
  String? get refreshToken;
  bool get isAuthenticated;
  void save({required String accessToken, required String refreshToken});
  void clear();
}

/// In-memory implementation. Replace with SharedPreferences for persistence.
class AuthStorage implements IAuthStorage {
  String? _accessToken;
  String? _refreshToken;

  @override
  String? get accessToken => _accessToken;

  @override
  String? get refreshToken => _refreshToken;

  @override
  bool get isAuthenticated => _accessToken != null;

  @override
  void save({required String accessToken, required String refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  void clear() {
    _accessToken = null;
    _refreshToken = null;
  }
}
