import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// POST /api/v1/patches — Create a new patch.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final patchRepo = context.read<PatchRepository>();

  final body = await context.request.json() as Map<String, dynamic>;
  final releaseId = body['release_id'] as int?;
  final metadata = body['metadata'] as Map<String, dynamic>?;

  if (releaseId == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'release_id is required',
      ).toJson(),
    );
  }

  final patch = await patchRepo.create(
    releaseId: releaseId,
    metadata: metadata,
  );

  return Response.json(
    statusCode: 201,
    body: CreatePatchResponse(
      id: patch.id,
      number: patch.number,
    ).toJson(),
  );
}
