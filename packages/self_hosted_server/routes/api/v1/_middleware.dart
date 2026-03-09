import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';

/// Middleware for /api/v1/* — requires valid JWT.
///
/// Extracts `Authorization: Bearer <token>`, verifies JWT,
/// and provides [AuthenticatedUser] to downstream handlers.
///
/// The `/api/v1/patches/check` endpoint is excluded from auth (device endpoint).
Handler middleware(Handler handler) {
  return (context) async {
    final request = context.request;

    // Allow OPTIONS for CORS preflight
    if (request.method == HttpMethod.options) {
      return Response(statusCode: 204);
    }

    // Skip auth for public endpoints
    final path = request.uri.path;
    if (path.endsWith('/patches/check') ||
        path.startsWith('/api/v1/download')) {
      return handler(context);
    }

    final authHeader =
        request.headers['Authorization'] ?? request.headers['authorization'];

    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.json(
        statusCode: 401,
        body: {
          'code': 'unauthorized',
          'message': 'Missing or invalid Authorization header',
        },
      );
    }

    final token = authHeader.substring(7); // Remove 'Bearer '
    final authService = context.read<AuthService>();

    try {
      final jwt = authService.verifyJwt(token);
      final userId = authService.getUserIdFromJwt(jwt);
      final email =
          (jwt.payload as Map<String, dynamic>)['email'] as String? ?? '';

      final authenticatedContext = context.provide<AuthenticatedUser>(
        () => AuthenticatedUser(id: userId, email: email),
      );

      return handler(authenticatedContext);
    } catch (_) {
      return Response.json(
        statusCode: 401,
        body: {'code': 'invalid_token', 'message': 'Invalid or expired token'},
      );
    }
  };
}
