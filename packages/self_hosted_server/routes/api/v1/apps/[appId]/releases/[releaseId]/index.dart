import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET /api/v1/apps/:appId/releases/:releaseId — Get release.
/// PATCH /api/v1/apps/:appId/releases/:releaseId — Update release.
Future<Response> onRequest(
  RequestContext context,
  String appId,
  String releaseId,
) async {
  final id = int.tryParse(releaseId);
  if (id == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'Invalid releaseId',
      ).toJson(),
    );
  }

  return switch (context.request.method) {
    HttpMethod.get => _getRelease(context, id),
    HttpMethod.patch => _updateRelease(context, id),
    _ => Future.value(Response(statusCode: 405)),
  };
}

Future<Response> _getRelease(RequestContext context, int releaseId) async {
  final releaseRepo = context.read<ReleaseRepository>();
  final release = await releaseRepo.findById(releaseId);

  if (release == null) {
    return Response.json(
      statusCode: 404,
      body: const ErrorResponse(
        code: 'not_found',
        message: 'Release not found',
      ).toJson(),
    );
  }

  return Response.json(
    body: GetReleaseResponse(release: release).toJson(),
  );
}

Future<Response> _updateRelease(RequestContext context, int releaseId) async {
  final releaseRepo = context.read<ReleaseRepository>();

  final body = await context.request.json() as Map<String, dynamic>;
  final statusStr = body['status'] as String?;
  final platformStr = body['platform'] as String?;
  final notes = body['notes'] as String?;

  if (statusStr != null && platformStr != null) {
    final status = ReleaseStatus.values.byName(statusStr);
    final platform = ReleasePlatform.values.byName(platformStr);
    await releaseRepo.updatePlatformStatus(
      releaseId: releaseId,
      platform: platform,
      status: status,
    );
  }

  if (notes != null) {
    await releaseRepo.updateNotes(releaseId: releaseId, notes: notes);
  }

  return Response(statusCode: 204);
}
