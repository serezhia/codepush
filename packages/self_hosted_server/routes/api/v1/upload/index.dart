import 'dart:typed_data';

import 'package:dart_frog/dart_frog.dart';
import 'package:mime/mime.dart';
import 'package:self_hosted_server/self_hosted_server.dart';

/// POST /api/v1/upload?path=<storage_path>
///
/// Receives a multipart/form-data request with the actual artifact file
/// (field name: "file") and stores it in MinIO at the given storage path.
/// This is step 2 of the CLI's two-step artifact upload flow.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final storagePath = context.request.uri.queryParameters['path'];
  if (storagePath == null || storagePath.isEmpty) {
    return Response(statusCode: 400);
  }

  final storageService = context.read<StorageService>();

  final contentType = context.request.headers['content-type'] ?? '';
  final boundary = contentType
      .split(';')
      .map((p) => p.trim())
      .where((p) => p.startsWith('boundary='))
      .map((p) => p.substring('boundary='.length))
      .firstOrNull;

  if (boundary == null) {
    return Response(statusCode: 400);
  }

  Uint8List? fileBytes;
  await for (final part in MimeMultipartTransformer(
    boundary,
  ).bind(context.request.bytes())) {
    final disposition = part.headers['content-disposition'] ?? '';
    final fileMatch = RegExp('filename="([^"]+)"').firstMatch(disposition);
    if (fileMatch != null && fileBytes == null) {
      final bytes = await part.fold<List<int>>(
        [],
        (acc, chunk) => acc..addAll(chunk),
      );
      fileBytes = Uint8List.fromList(bytes);
    } else {
      // Drain any other parts to fully consume the request body.
      await part.drain<void>();
    }
  }

  if (fileBytes == null) {
    return Response(statusCode: 400);
  }

  await storageService.upload(
    storagePath: storagePath,
    data: Stream.value(fileBytes),
    size: fileBytes.length,
  );

  return Response();
}
