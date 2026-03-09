import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/data/api_client.dart';
import 'package:shorebird_console/data/auth_storage.dart';

/// Repository for auth operations.
class AuthRepository {
  const AuthRepository({
    required ApiClient apiClient,
    required IAuthStorage authStorage,
  }) : _apiClient = apiClient,
       _authStorage = authStorage;

  final ApiClient _apiClient;
  final IAuthStorage _authStorage;

  bool get isAuthenticated => _authStorage.isAuthenticated;

  Future<PrivateUser> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _apiClient.login(email: email, password: password);
    _authStorage.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return _apiClient.getCurrentUser();
  }

  Future<PrivateUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final tokens = await _apiClient.register(
      email: email,
      password: password,
      name: name,
    );
    _authStorage.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    return _apiClient.getCurrentUser();
  }

  Future<PrivateUser?> tryRestoreSession() async {
    if (!isAuthenticated) return null;
    try {
      return await _apiClient.getCurrentUser();
    } catch (_) {
      _authStorage.clear();
      return null;
    }
  }

  void logout() => _authStorage.clear();
}
