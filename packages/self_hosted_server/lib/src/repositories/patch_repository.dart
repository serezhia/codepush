import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:self_hosted_server/src/repositories/pg_helpers.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// Data access layer for patches.
class PatchRepository {
  const PatchRepository(this._pool);

  final Pool _pool;

  /// Creates a new patch with auto-incremented number.
  Future<({int id, int number})> create({
    required int releaseId,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        '''INSERT INTO patches (release_id, number, metadata)
           VALUES (
             @releaseId,
             COALESCE(
               (SELECT MAX(number) FROM patches WHERE release_id = @releaseId),
               0
             ) + 1,
             @metadata
           )
           RETURNING id, number''',
      ),
      parameters: {
        'releaseId': releaseId,
        'metadata': metadata != null ? jsonEncode(metadata) : null,
      },
    );
    final cols = result.first.toColumnMap();
    return (id: cols['id']! as int, number: cols['number']! as int);
  }

  /// Returns all patches for a release with their artifacts and channel info.
  Future<List<ReleasePatch>> getByReleaseId(int releaseId) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT p.id, p.number, p.notes, p.is_rolled_back,
                  c.name as channel_name
           FROM patches p
           LEFT JOIN patch_channels pc ON p.id = pc.patch_id
           LEFT JOIN channels c ON pc.channel_id = c.id
           WHERE p.release_id = @releaseId
           ORDER BY p.number DESC''',
      ),
      parameters: {'releaseId': releaseId},
    );

    // Group by patch id to handle multiple channels
    final grouped = <int, _PatchData>{};
    for (final row in result) {
      final cols = row.toColumnMap();
      final patchId = cols['id']! as int;
      grouped.putIfAbsent(
        patchId,
        () => _PatchData(
          id: patchId,
          number: cols['number']! as int,
          notes: cols['notes'] as String?,
          isRolledBack: cols['is_rolled_back']! as bool,
          channel: cols['channel_name'] as String?,
        ),
      );
    }

    // Fetch artifacts for each patch
    final patches = <ReleasePatch>[];
    for (final data in grouped.values) {
      final artifacts = await _getArtifacts(data.id);
      patches.add(
        ReleasePatch(
          id: data.id,
          number: data.number,
          channel: data.channel,
          artifacts: artifacts,
          isRolledBack: data.isRolledBack,
          notes: data.notes,
        ),
      );
    }

    return patches;
  }

  /// Finds the latest patch for a patch check request.
  ///
  /// Returns the latest non-rolled-back patch that:
  /// - Belongs to the given release
  /// - Has an artifact matching the platform and arch
  /// - Is promoted to the given channel
  /// - Has a number greater than [currentPatchNumber]
  Future<Map<String, dynamic>?> findForPatchCheck({
    required int releaseId,
    required ReleasePlatform platform,
    required String arch,
    required String channel,
    int? currentPatchNumber,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT p.id, p.number,
                  pa.hash, pa.hash_signature, pa.storage_path, pa.size
           FROM patches p
           JOIN patch_artifacts pa ON p.id = pa.patch_id
           JOIN patch_channels pc ON p.id = pc.patch_id
           JOIN channels c ON pc.channel_id = c.id
           WHERE p.release_id = @releaseId
             AND p.is_rolled_back = false
             AND pa.platform = @platform
             AND pa.arch = @arch
             AND c.name = @channel
             AND p.number > @currentNumber
           ORDER BY p.number DESC
           LIMIT 1''',
      ),
      parameters: {
        'releaseId': releaseId,
        'platform': platform.name,
        'arch': arch,
        'channel': channel,
        'currentNumber': currentPatchNumber ?? 0,
      },
    );

    if (result.isEmpty) return null;
    return result.first.toColumnMap();
  }

  /// Returns rolled back patch numbers for a release.
  Future<List<int>> getRolledBackNumbers(int releaseId) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT number FROM patches
           WHERE release_id = @releaseId AND is_rolled_back = true
           ORDER BY number''',
      ),
      parameters: {'releaseId': releaseId},
    );
    return result.map((r) => r[0]! as int).toList();
  }

  /// Rolls back a patch.
  Future<void> rollback(int patchId) async {
    await _pool.execute(
      Sql.named(
        'UPDATE patches SET is_rolled_back = true WHERE id = @id',
      ),
      parameters: {'id': patchId},
    );
  }

  /// Updates patch notes.
  Future<void> updateNotes({
    required int patchId,
    required String notes,
  }) async {
    await _pool.execute(
      Sql.named('UPDATE patches SET notes = @notes WHERE id = @id'),
      parameters: {'id': patchId, 'notes': notes},
    );
  }

  Future<List<PatchArtifact>> _getArtifacts(int patchId) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT id, patch_id, arch, platform, hash, size, created_at
           FROM patch_artifacts WHERE patch_id = @patchId''',
      ),
      parameters: {'patchId': patchId},
    );
    return result.map((row) {
      final cols = row.toColumnMap();
      return PatchArtifact(
        id: cols['id']! as int,
        patchId: cols['patch_id']! as int,
        arch: cols['arch']! as String,
        platform: ReleasePlatform.values.byName(
          decodeColumn(cols['platform']),
        ),
        hash: cols['hash']! as String,
        size: cols['size']! as int,
        createdAt: cols['created_at']! as DateTime,
      );
    }).toList();
  }
}

class _PatchData {
  _PatchData({
    required this.id,
    required this.number,
    required this.isRolledBack,
    this.notes,
    this.channel,
  });

  final int id;
  final int number;
  final String? notes;
  final bool isRolledBack;
  final String? channel;
}
