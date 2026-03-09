import 'package:dart_frog/dart_frog.dart';
import 'package:self_hosted_server/self_hosted_server.dart';

/// GET /api/v1/download?path=<storage_path>
///
/// Proxies artifact downloads from MinIO to the client. This avoids exposing
/// MinIO presigned URLs (whose HMAC signatures are tied to the internal
/// hostname and would be invalid when rewritten to the public endpoint).
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final storagePath = context.request.uri.queryParameters['path'];
  if (storagePath == null || storagePath.isEmpty) {
    return Response(statusCode: 400);
  }

  final storageService = context.read<StorageService>();

  final stream = await storageService.download(storagePath);

  return Response.stream(
    headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition':
          'attachment; filename="${storagePath.split('/').last}"',
    },
    body: stream,
  );
}
