import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mime/mime.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// POST /api/v1/patches/:patchId/artifacts — Create a patch artifact.
Future<Response> onRequest(RequestContext context, String patchId) async {
  if (context.request.method != HttpMethod.post) {
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

  final artifactRepo = context.read<ArtifactRepository>();
  final config = context.read<ServerConfig>();

  // Extract multipart boundary from Content-Type header.
  final contentType = context.request.headers['content-type'] ?? '';
  final boundary = contentType
      .split(';')
      .map((p) => p.trim())
      .where((p) => p.startsWith('boundary='))
      .map((p) => p.substring('boundary='.length))
      .firstOrNull;

  if (boundary == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'Expected multipart/form-data',
      ).toJson(),
    );
  }

  // The CLI sends only metadata fields in the first POST (no file).
  // The actual file is uploaded in a second POST to the returned URL.
  final fields = <String, String>{};
  await for (final part in MimeMultipartTransformer(
    boundary,
  ).bind(context.request.bytes())) {
    final disposition = part.headers['content-disposition'] ?? '';
    final nameMatch = RegExp('name="([^"]+)"').firstMatch(disposition);
    final fileMatch = RegExp('filename="([^"]+)"').firstMatch(disposition);
    // Skip any file parts — only collect text fields.
    if (fileMatch == null && nameMatch != null) {
      final bytes = await part.fold<List<int>>(
        [],
        (acc, chunk) => acc..addAll(chunk),
      );
      fields[nameMatch.group(1)!] = utf8.decode(bytes);
    }
  }

  final arch = fields['arch'];
  final platformStr = fields['platform'];
  final hash = fields['hash'];
  final sizeStr = fields['size'];
  final size = sizeStr != null ? int.tryParse(sizeStr) : null;

  if (arch == null || platformStr == null || hash == null || size == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'arch, platform, hash, and size are required',
      ).toJson(),
    );
  }

  final platform = ReleasePlatform.values.byName(platformStr);
  final storagePath = 'patches/$id/$platform/$arch/patch.bin';

  final artifactId = await artifactRepo.createPatchArtifact(
    patchId: id,
    arch: arch,
    platform: platform,
    hash: hash,
    size: size,
    storagePath: storagePath,
    hashSignature: fields['hash_signature'],
    podfileLockHash: fields['podfile_lock_hash'],
  );

  // The CLI performs a second multipart POST to upload the actual file.
  // Encode the storage path as a query parameter so the upload endpoint
  // knows where to store it in MinIO.
  final uploadDoneUrl =
      '${config.serverUrl}/api/v1/upload?path=${Uri.encodeComponent(storagePath)}';

  return Response.json(
    statusCode: 201,
    body: CreatePatchArtifactResponse(
      id: artifactId,
      patchId: id,
      arch: arch,
      platform: platform,
      hash: hash,
      size: size,
      url: uploadDoneUrl,
    ).toJson(),
  );
}
