import 'dart:typed_data';

import 'package:minio/minio.dart';

/// Service for MinIO/S3-compatible object storage operations.
///
/// Handles artifact upload URL generation, download URL generation,
/// and direct upload/download proxying.
class StorageService {
  StorageService({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    required this.bucket,
    bool useSSL = false,
    this.publicEndpoint,
  }) : _minio = Minio(
         endPoint: Uri.parse(endpoint).host,
         port: Uri.parse(endpoint).port,
         accessKey: accessKey,
         secretKey: secretKey,
         useSSL: useSSL,
       );

  final Minio _minio;
  final String bucket;

  /// Public endpoint for generating download URLs accessible by devices.
  /// If null, the MinIO endpoint is used.
  final String? publicEndpoint;

  /// Ensures the bucket exists.
  Future<void> ensureBucket() async {
    final exists = await _minio.bucketExists(bucket);
    if (!exists) {
      await _minio.makeBucket(bucket);
    }
  }

  /// Generates a presigned URL for uploading an artifact.
  Future<String> getUploadUrl(String storagePath) async {
    return _minio.presignedPutObject(bucket, storagePath, expires: 3600);
  }

  /// Generates a presigned URL for downloading an artifact.
  Future<String> getDownloadUrl(String storagePath) async {
    final url = await _minio.presignedGetObject(
      bucket,
      storagePath,
      expires: 3600,
    );

    // If a public endpoint is configured, replace the internal endpoint.
    if (publicEndpoint != null) {
      final parsed = Uri.parse(url);
      final publicUri = Uri.parse(publicEndpoint!);
      return parsed
          .replace(host: publicUri.host, port: publicUri.port)
          .toString();
    }

    return url;
  }

  /// Uploads data directly to storage.
  Future<void> upload({
    required String storagePath,
    required Stream<Uint8List> data,
    required int size,
  }) async {
    await _minio.putObject(bucket, storagePath, data, size: size);
  }

  /// Downloads an artifact as a byte stream.
  Future<Stream<Uint8List>> download(String storagePath) async {
    final response = await _minio.getObject(bucket, storagePath);
    return response.map(Uint8List.fromList);
  }

  /// Deletes an artifact from storage.
  Future<void> delete(String storagePath) async {
    await _minio.removeObject(bucket, storagePath);
  }

  /// Generates a storage path for a release artifact.
  String releaseArtifactPath({
    required String appId,
    required int releaseId,
    required String arch,
    required String platform,
    required String filename,
  }) {
    return 'apps/$appId/releases/$releaseId/artifacts/$platform/$arch/$filename';
  }

  /// Generates a storage path for a patch artifact.
  String patchArtifactPath({
    required String appId,
    required int releaseId,
    required int patchId,
    required String arch,
    required String platform,
  }) {
    return 'apps/$appId/releases/$releaseId/patches/$patchId/$platform/$arch/patch.bin';
  }
}
