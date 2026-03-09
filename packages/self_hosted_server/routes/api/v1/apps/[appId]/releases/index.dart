import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET /api/v1/apps/:appId/releases — List releases.
/// POST /api/v1/apps/:appId/releases — Create a release.
Future<Response> onRequest(RequestContext context, String appId) async {
  return switch (context.request.method) {
    HttpMethod.get => _getReleases(context, appId),
    HttpMethod.post => _createRelease(context, appId),
    _ => Future.value(Response(statusCode: 405)),
  };
}

Future<Response> _getReleases(RequestContext context, String appId) async {
  final releaseRepo = context.read<ReleaseRepository>();
  final releases = await releaseRepo.getByAppId(appId);
  return Response.json(
    body: GetReleasesResponse(releases: releases).toJson(),
  );
}

Future<Response> _createRelease(RequestContext context, String appId) async {
  final releaseRepo = context.read<ReleaseRepository>();

  final body = await context.request.json() as Map<String, dynamic>;
  final version = body['version'] as String?;
  final flutterRevision = body['flutter_revision'] as String?;

  if (version == null || flutterRevision == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'version and flutter_revision are required',
      ).toJson(),
    );
  }

  final release = await releaseRepo.create(
    appId: appId,
    version: version,
    flutterRevision: flutterRevision,
    flutterVersion: body['flutter_version'] as String?,
    displayName: body['display_name'] as String?,
  );

  return Response.json(
    statusCode: 201,
    body: CreateReleaseResponse(release: release).toJson(),
  );
}
