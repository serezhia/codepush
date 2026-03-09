import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// POST /auth/refresh — Refresh JWT using a refresh token.
///
/// Uses refresh token rotation: old token is consumed, new pair is issued.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(statusCode: 204);
  }

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final authService = context.read<AuthService>();
  final userRepo = context.read<UserRepository>();

  final body = await context.request.json() as Map<String, dynamic>;
  final token = body['refresh_token'] as String?;

  if (token == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'refresh_token is required',
      ).toJson(),
    );
  }

  final userId = await authService.validateRefreshToken(token);
  if (userId == null) {
    return Response.json(
      statusCode: 401,
      body: const ErrorResponse(
        code: 'invalid_token',
        message: 'Invalid or expired refresh token',
      ).toJson(),
    );
  }

  final user = await userRepo.findById(userId);
  if (user == null) {
    return Response.json(
      statusCode: 401,
      body: const ErrorResponse(
        code: 'user_not_found',
        message: 'User not found',
      ).toJson(),
    );
  }

  final accessToken = authService.createJwt(
    userId: userId,
    email: user['email'] as String,
    displayName: user['display_name'] as String?,
  );
  final newRefreshToken = await authService.createRefreshToken(userId);

  return Response.json(
    body: {
      'access_token': accessToken,
      'refresh_token': newRefreshToken,
      'token_type': 'Bearer',
      'expires_in': authService.tokenExpiry.inSeconds,
    },
  );
}
