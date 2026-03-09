import 'package:dio/dio.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/data/auth_storage.dart';
import 'package:shorebird_console/data/dto/dto.dart';

/// Typed HTTP client for the self-hosted Shorebird server API.
class ApiClient {
  ApiClient({required String baseUrl, required IAuthStorage authStorage})
    : _authStorage = authStorage,
      _dio = Dio(
        BaseOptions(baseUrl: baseUrl, contentType: 'application/json'),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _authStorage.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final retry = await _dio.fetch<dynamic>(error.requestOptions);
              return handler.resolve(retry);
            }
            _authStorage.clear();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final IAuthStorage _authStorage;

  Future<bool> _tryRefreshToken() async {
    final refreshToken = _authStorage.refreshToken;
    if (refreshToken == null) return false;
    try {
      final response =
          await Dio(
            BaseOptions(baseUrl: _dio.options.baseUrl),
          ).post<Map<String, dynamic>>(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
          );
      final tokens = AuthTokens.fromJson(response.data!);
      _authStorage.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _json(Response<dynamic> r) =>
      r.data! as Map<String, dynamic>;

  List<dynamic> _list(Response<dynamic> r) => r.data! as List<dynamic>;

  // ─── Auth ──────────────────────────────────────────────────

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthTokens.fromJson(_json(r));
  }

  Future<AuthTokens> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'password': password, 'name': name},
    );
    return AuthTokens.fromJson(_json(r));
  }

  // ─── Users ─────────────────────────────────────────────────

  Future<PrivateUser> getCurrentUser() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/v1/users/me');
    return PrivateUser.fromJson(_json(r));
  }

  // ─── Apps ──────────────────────────────────────────────────

  Future<List<AppMetadata>> getApps() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/v1/apps');
    return (_json(r)['apps'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AppMetadata.fromJson)
        .toList();
  }

  Future<App> createApp({
    required String displayName,
    required int organizationId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/v1/apps',
      data: {'display_name': displayName, 'organization_id': organizationId},
    );
    return App.fromJson(_json(r));
  }

  Future<void> deleteApp(String appId) async {
    await _dio.delete<void>('/api/v1/apps/$appId');
  }

  // ─── Channels ──────────────────────────────────────────────

  Future<List<Channel>> getChannels(String appId) async {
    final r = await _dio.get<dynamic>('/api/v1/apps/$appId/channels');
    return _list(r).cast<Map<String, dynamic>>().map(Channel.fromJson).toList();
  }

  Future<Channel> createChannel({
    required String appId,
    required String name,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/v1/apps/$appId/channels',
      data: {'channel': name},
    );
    return Channel.fromJson(_json(r));
  }

  // ─── Releases ──────────────────────────────────────────────

  Future<List<Release>> getReleases(String appId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/v1/apps/$appId/releases',
    );
    return (_json(r)['releases'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Release.fromJson)
        .toList();
  }

  Future<Release> getRelease({
    required String appId,
    required int releaseId,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/v1/apps/$appId/releases/$releaseId',
    );
    return Release.fromJson(_json(r)['release'] as Map<String, dynamic>);
  }

  Future<void> updateRelease({
    required String appId,
    required int releaseId,
    ReleaseStatus? status,
    ReleasePlatform? platform,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (status != null) data['status'] = status.name;
    if (platform != null) data['platform'] = platform.name;
    if (notes != null) data['notes'] = notes;
    await _dio.patch<void>(
      '/api/v1/apps/$appId/releases/$releaseId',
      data: data,
    );
  }

  // ─── Release Artifacts ─────────────────────────────────────

  Future<List<ReleaseArtifact>> getReleaseArtifacts({
    required String appId,
    required int releaseId,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/v1/apps/$appId/releases/$releaseId/artifacts',
    );
    return (_json(r)['artifacts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ReleaseArtifact.fromJson)
        .toList();
  }

  // ─── Patches ───────────────────────────────────────────────

  Future<List<ReleasePatch>> getPatches({
    required String appId,
    required int releaseId,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/v1/apps/$appId/releases/$releaseId/patches',
    );
    return (_json(r)['patches'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ReleasePatch.fromJson)
        .toList();
  }

  Future<void> updatePatchNotes({
    required String appId,
    required int releaseId,
    required int patchId,
    required String notes,
  }) async {
    await _dio.patch<void>(
      '/api/v1/apps/$appId/releases/$releaseId/patches/$patchId',
      data: {'notes': notes},
    );
  }

  Future<void> promotePatch({
    required int patchId,
    required int channelId,
  }) async {
    await _dio.post<void>(
      '/api/v1/patches/promote',
      data: {'patch_id': patchId, 'channel_id': channelId},
    );
  }

  Future<void> rollbackPatch(int patchId) async {
    await _dio.post<void>(
      '/api/v1/patches/rollback',
      data: {'patch_id': patchId},
    );
  }

  // ─── Collaborators ─────────────────────────────────────────

  Future<List<AppCollaborator>> getCollaborators(String appId) async {
    final r = await _dio.get<dynamic>(
      '/api/v1/apps/$appId/collaborators',
    );
    return _list(
      r,
    ).cast<Map<String, dynamic>>().map(AppCollaborator.fromJson).toList();
  }

  Future<void> addCollaborator({
    required String appId,
    required String email,
  }) async {
    await _dio.post<void>(
      '/api/v1/apps/$appId/collaborators',
      data: {'email': email},
    );
  }

  Future<void> updateCollaboratorRole({
    required String appId,
    required int userId,
    required AppCollaboratorRole role,
  }) async {
    await _dio.patch<void>(
      '/api/v1/apps/$appId/collaborators/$userId',
      data: {'role': role.name},
    );
  }

  Future<void> removeCollaborator({
    required String appId,
    required int userId,
  }) async {
    await _dio.delete<void>('/api/v1/apps/$appId/collaborators/$userId');
  }

  // ─── Organizations ────────────────────────────────────────

  Future<List<OrganizationMembership>> getOrganizations() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/v1/organizations');
    return (_json(r)['organizations'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(OrganizationMembership.fromJson)
        .toList();
  }

  Future<List<AppMetadata>> getOrganizationApps(int orgId) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/v1/organizations/$orgId/apps',
    );
    return (_json(r)['apps'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AppMetadata.fromJson)
        .toList();
  }

  Future<List<OrganizationUser>> getOrganizationUsers(int orgId) async {
    final r = await _dio.get<dynamic>(
      '/api/v1/organizations/$orgId/users',
    );
    return _list(
      r,
    ).cast<Map<String, dynamic>>().map(OrganizationUser.fromJson).toList();
  }

  Future<void> addOrganizationMember({
    required int orgId,
    required String email,
    required Role role,
  }) async {
    await _dio.post<void>(
      '/api/v1/organizations/$orgId/users',
      data: {'email': email, 'role': role.name},
    );
  }

  Future<void> updateOrganizationMemberRole({
    required int orgId,
    required int userId,
    required Role role,
  }) async {
    await _dio.patch<void>(
      '/api/v1/organizations/$orgId/users/$userId',
      data: {'role': role.name},
    );
  }

  Future<void> removeOrganizationMember({
    required int orgId,
    required int userId,
  }) async {
    await _dio.delete<void>('/api/v1/organizations/$orgId/users/$userId');
  }
}
