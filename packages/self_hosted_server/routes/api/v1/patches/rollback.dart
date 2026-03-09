import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await context.request.json() as Map<String, dynamic>;
  final patchId = body['patch_id'] as int?;
  if (patchId == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'message': 'patch_id is required'},
    );
  }

  final patchRepo = context.read<PatchRepository>();
  await patchRepo.rollback(patchId);

  return Response(statusCode: HttpStatus.noContent);
}
