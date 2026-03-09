import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// POST /api/v1/patches/check — Check for available patches (PUBLIC, no auth).
///
/// Called by devices to check for OTA updates.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final releaseRepo = context.read<ReleaseRepository>();
  final patchRepo = context.read<PatchRepository>();
  final config = context.read<ServerConfig>();

  final body = await context.request.json() as Map<String, dynamic>;

  final appId = body['app_id'] as String?;
  final releaseVersion = body['release_version'] as String?;
  final platformStr = body['platform'] as String?;
  final arch = body['arch'] as String?;
  final channel = body['channel'] as String? ?? 'stable';
  final patchNumber = body['patch_number'] as int?;

  if (appId == null ||
      releaseVersion == null ||
      platformStr == null ||
      arch == null) {
    return Response.json(
      statusCode: 400,
      body: const ErrorResponse(
        code: 'invalid_request',
        message: 'app_id, release_version, platform, and arch are required',
      ).toJson(),
    );
  }

  final platform = ReleasePlatform.values.byName(platformStr);

  // Find the release
  final release = await releaseRepo.findByVersion(
    appId: appId,
    version: releaseVersion,
  );
  if (release == null) {
    return Response.json(
      body: const PatchCheckResponse(patchAvailable: false).toJson(),
    );
  }

  // Find latest available patch
  final patchData = await patchRepo.findForPatchCheck(
    releaseId: release.id,
    platform: platform,
    arch: arch,
    channel: channel,
    currentPatchNumber: patchNumber,
  );

  if (patchData == null) {
    return Response.json(
      body: const PatchCheckResponse(patchAvailable: false).toJson(),
    );
  }

  // Generate proxy download URL (avoids presigned MinIO URL host mismatch)
  final storagePath = patchData['storage_path'] as String;
  final downloadUrl =
      '${config.serverUrl}/api/v1/download?path=${Uri.encodeComponent(storagePath)}';

  // Get rolled back patches
  final rolledBack = await patchRepo.getRolledBackNumbers(release.id);

  return Response.json(
    body: PatchCheckResponse(
      patchAvailable: true,
      patch: PatchCheckMetadata(
        number: patchData['number'] as int,
        downloadUrl: downloadUrl,
        hash: patchData['hash'] as String,
        hashSignature: patchData['hash_signature'] as String?,
      ),
      rolledBackPatchNumbers: rolledBack.isEmpty ? null : rolledBack,
    ).toJson(),
  );
}
