import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// Global middleware: provides DI container, CORS headers, and error handling.
///
/// Initializes [Dependencies] once and injects it into every request context.
/// Catches all unhandled exceptions and returns proper JSON error responses.
Dependencies? _deps;

Handler middleware(Handler handler) {
  return (context) async {
    // Initialize dependencies on first request
    _deps ??= await Dependencies.initialize(ServerConfig.fromEnv());
    final deps = _deps!;

    final enrichedContext = context
        .provide<Dependencies>(() => deps)
        .provide<AuthService>(() => deps.authService)
        .provide<StorageService>(() => deps.storageService)
        .provide<UserRepository>(() => deps.userRepository)
        .provide<OrganizationRepository>(() => deps.organizationRepository)
        .provide<AppRepository>(() => deps.appRepository)
        .provide<ReleaseRepository>(() => deps.releaseRepository)
        .provide<PatchRepository>(() => deps.patchRepository)
        .provide<ChannelRepository>(() => deps.channelRepository)
        .provide<ArtifactRepository>(() => deps.artifactRepository)
        .provide<ServerConfig>(() => deps.config);

    Response response;
    try {
      response = await handler(enrichedContext);
    } catch (e, st) {
      // Log the error for server-side debugging
      stderr.writeln(
        '[ERROR] ${context.request.method.value} '
        '${context.request.uri.path}: $e\n$st',
      );
      // Return proper JSON error response instead of dart_frog's HTML 500
      response = Response.json(
        statusCode: 500,
        body: ErrorResponse(
          code: 'internal_error',
          message: 'An internal server error occurred.',
          details: e.toString(),
        ).toJson(),
      );
    }

    return response.copyWith(
      headers: {
        ...response.headers,
        'Access-Control-Allow-Origin': deps.config.corsOrigins.join(','),
        'Access-Control-Allow-Methods':
            'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'Access-Control-Allow-Headers':
            'Content-Type, Authorization, x-version, x-cli-version',
      },
    );
  };
}
