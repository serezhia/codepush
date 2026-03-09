import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET /api/v1/users/me — Get current authenticated user.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final user = context.read<AuthenticatedUser>();
  final userRepo = context.read<UserRepository>();
  final userData = await userRepo.findById(user.id);

  if (userData == null) {
    return Response.json(
      statusCode: 404,
      body: const ErrorResponse(
        code: 'not_found',
        message: 'User not found',
      ).toJson(),
    );
  }

  final config = context.read<Dependencies>().config;
  return Response.json(
    body: PrivateUser(
      id: userData['id'] as int,
      email: userData['email'] as String,
      displayName: userData['display_name'] as String?,
      hasActiveSubscription: true, // Always true for self-hosted
      jwtIssuer: config.authIssuer ?? config.serverUrl,
    ).toJson(),
  );
}
