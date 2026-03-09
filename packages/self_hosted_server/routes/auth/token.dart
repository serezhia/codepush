import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// POST /auth/token — Exchange auth code or refresh token for new tokens.
///
/// Compatible with Shorebird CLI's OAuth loopback flow.
/// Accepts both JSON and form-encoded bodies.
///
/// grant_type=authorization_code: { code: "..." }
/// grant_type=refresh_token: { refresh_token: "..." }
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(statusCode: 204);
  }

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final authService = context.read<AuthService>();

  // Parse body — support both JSON and form-encoded (CLI sends form-encoded).
  final contentType = context.request.headers['content-type'] ?? '';
  Map<String, dynamic> body;
  if (contentType.contains('application/x-www-form-urlencoded')) {
    final raw = await context.request.body();
    body = Uri.splitQueryString(raw);
  } else {
    body = await context.request.json() as Map<String, dynamic>;
  }

  final grantType = body['grant_type'] as String? ?? 'authorization_code';
  final code = body['code'] as String?;
  final refreshToken = body['refresh_token'] as String?;

  if (grantType == 'refresh_token') {
    if (refreshToken == null) {
      return Response.json(
        statusCode: 400,
        body: const ErrorResponse(
          code: 'invalid_request',
          message: 'refresh_token is required',
        ).toJson(),
      );
    }
    final userId = await authService.validateRefreshToken(refreshToken);
    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: const ErrorResponse(
          code: 'invalid_token',
          message: 'Invalid or expired refresh token',
        ).toJson(),
      );
    }
    final userRepo = context.read<UserRepository>();
    final user = await userRepo.findById(userId);
    if (user == null) {
      return Response.json(
        statusCode: 401,
        body: const ErrorResponse(
          code: 'invalid_token',
          message: 'User not found',
        ).toJson(),
      );
    }
    final newAccessToken = authService.createJwt(
      userId: userId,
      email: user['email'] as String,
      displayName: user['display_name'] as String?,
    );
    final newRefreshToken = await authService.createRefreshToken(userId);
    return Response.json(
      body: {
        'access_token': newAccessToken,
        'refresh_token': newRefreshToken,
        'token_type': 'Bearer',
        'expires_in': authService.tokenExpiry.inSeconds,
      },
    );
  }

  // Default: authorization_code grant
  if (code == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'code is required',
      ).toJson(),
    );
  }

  final tokens = await authService.exchangeAuthCode(code);
  if (tokens == null) {
    return Response.json(
      statusCode: 401,
      body: const ErrorResponse(
        code: 'invalid_code',
        message: 'Invalid or expired auth code',
      ).toJson(),
    );
  }

  return Response.json(
    body: {
      'access_token': tokens.accessToken,
      'refresh_token': tokens.refreshToken,
      'token_type': 'Bearer',
      'expires_in': authService.tokenExpiry.inSeconds,
    },
  );
}
