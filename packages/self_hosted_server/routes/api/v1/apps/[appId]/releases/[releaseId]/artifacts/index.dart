import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:mime/mime.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// GET /api/v1/apps/:appId/releases/:releaseId/artifacts — Get release artifacts.
/// POST /api/v1/apps/:appId/releases/:releaseId/artifacts — Create release artifact.
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
    HttpMethod.get => _getArtifacts(context, appId, id),
    HttpMethod.post => _createArtifact(context, appId, id),
    _ => Future.value(Response(statusCode: 405)),
  };
}

Future<Response> _getArtifacts(
  RequestContext context,
  String appId,
  int releaseId,
) async {
  final artifactRepo = context.read<ArtifactRepository>();
  final config = context.read<ServerConfig>();

  final params = context.request.uri.queryParameters;
  final arch = params['arch'];
  final platformStr = params['platform'];
  final platform = platformStr != null
      ? ReleasePlatform.values.byName(platformStr)
      : null;

  final artifacts = await artifactRepo.getReleaseArtifacts(
    releaseId: releaseId,
    arch: arch,
    platform: platform,
  );

  // Fetch the stored storage paths for all artifacts in one query.
  final storagePaths = await artifactRepo.getReleaseArtifactStoragePaths(
    releaseId,
  );

  final withUrls = artifacts.map((a) {
    final storagePath = storagePaths[a.id] ?? '';
    final url =
        '${config.serverUrl}/api/v1/download?path=${Uri.encodeComponent(storagePath)}';
    return ReleaseArtifact(
      id: a.id,
      releaseId: a.releaseId,
      arch: a.arch,
      platform: a.platform,
      hash: a.hash,
      size: a.size,
      url: url,
      podfileLockHash: a.podfileLockHash,
      canSideload: a.canSideload,
    );
  }).toList();

  return Response.json(
    body: GetReleaseArtifactsResponse(artifacts: withUrls).toJson(),
  );
}

Future<Response> _createArtifact(
  RequestContext context,
  String appId,
  int releaseId,
) async {
  final artifactRepo = context.read<ArtifactRepository>();
  final storageService = context.read<StorageService>();
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
  final filename = fields['filename'] ?? 'artifact';
  final storagePath = storageService.releaseArtifactPath(
    appId: appId,
    releaseId: releaseId,
    arch: arch,
    platform: platform.name,
    filename: filename,
  );

  final artifactId = await artifactRepo.createReleaseArtifact(
    releaseId: releaseId,
    arch: arch,
    platform: platform,
    hash: hash,
    size: size,
    storagePath: storagePath,
    podfileLockHash: fields['podfile_lock_hash'],
    canSideload: fields['can_sideload'] == 'true',
  );

  // The CLI performs a second multipart POST to upload the actual file.
  // Encode the storage path as a query parameter so the upload endpoint
  // knows where to store it in MinIO.
  final uploadDoneUrl =
      '${config.serverUrl}/api/v1/upload?path=${Uri.encodeComponent(storagePath)}';

  return Response.json(
    statusCode: 201,
    body: CreateReleaseArtifactResponse(
      id: artifactId,
      releaseId: releaseId,
      arch: arch,
      platform: platform,
      hash: hash,
      size: size,
      url: uploadDoneUrl,
    ).toJson(),
  );
}
