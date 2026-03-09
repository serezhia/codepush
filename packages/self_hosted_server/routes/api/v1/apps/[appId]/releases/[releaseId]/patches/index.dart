import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET /api/v1/apps/:appId/releases/:releaseId/patches — Get patches for a release.
Future<Response> onRequest(
  RequestContext context,
  String appId,
  String releaseId,
) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

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

  final patchRepo = context.read<PatchRepository>();
  final patches = await patchRepo.getByReleaseId(id);

  return Response.json(
    body: GetReleasePatchesResponse(patches: patches).toJson(),
  );
}
