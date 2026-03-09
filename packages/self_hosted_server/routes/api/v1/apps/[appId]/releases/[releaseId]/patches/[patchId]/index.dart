import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// PATCH /api/v1/apps/:appId/releases/:releaseId/patches/:patchId — Update a patch.
Future<Response> onRequest(
  RequestContext context,
  String appId,
  String releaseId,
  String patchId,
) async {
  if (context.request.method != HttpMethod.patch) {
    return Response(statusCode: 405);
  }

  final id = int.tryParse(patchId);
  if (id == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'Invalid patchId',
      ).toJson(),
    );
  }

  final patchRepo = context.read<PatchRepository>();
  final body = await context.request.json() as Map<String, dynamic>;
  final notes = body['notes'] as String?;

  if (notes != null) {
    await patchRepo.updateNotes(patchId: id, notes: notes);
  }

  return Response(statusCode: 204);
}
