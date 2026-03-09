import 'package:postgres/postgres.dart';
import 'package:self_hosted_server/src/repositories/pg_helpers.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// Data access layer for releases.
class ReleaseRepository {
  const ReleaseRepository(this._pool);

  final Pool _pool;

  /// Creates a new release.
  Future<Release> create({
    required String appId,
    required String version,
    required String flutterRevision,
    String? flutterVersion,
    String? displayName,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        '''INSERT INTO releases (app_id, version, flutter_revision,
                                 flutter_version, display_name)
           VALUES (@appId, @version, @flutterRevision,
                   @flutterVersion, @displayName)
           RETURNING id, created_at, updated_at''',
      ),
      parameters: {
        'appId': appId,
        'version': version,
        'flutterRevision': flutterRevision,
        'flutterVersion': flutterVersion,
        'displayName': displayName,
      },
    );

    final cols = result.first.toColumnMap();
    return Release(
      id: cols['id']! as int,
      appId: appId,
      version: version,
      flutterRevision: flutterRevision,
      flutterVersion: flutterVersion,
      displayName: displayName,
      platformStatuses: const {},
      createdAt: cols['created_at']! as DateTime,
      updatedAt: cols['updated_at']! as DateTime,
    );
  }

  /// Returns all releases for an app.
  Future<List<Release>> getByAppId(String appId) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT r.*,
                  array_agg(rps.platform::text) as platforms,
                  array_agg(rps.status::text) as statuses
           FROM releases r
           LEFT JOIN release_platform_statuses rps ON r.id = rps.release_id
           WHERE r.app_id = @appId
           GROUP BY r.id
           ORDER BY r.created_at DESC''',
      ),
      parameters: {'appId': appId},
    );

    return result.map((row) => _rowToRelease(row, appId)).toList();
  }

  /// Finds a release by id.
  Future<Release?> findById(int releaseId) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT r.*,
                  array_agg(rps.platform::text) as platforms,
                  array_agg(rps.status::text) as statuses
           FROM releases r
           LEFT JOIN release_platform_statuses rps ON r.id = rps.release_id
           WHERE r.id = @id
           GROUP BY r.id''',
      ),
      parameters: {'id': releaseId},
    );
    if (result.isEmpty) return null;
    final cols = result.first.toColumnMap();
    return _rowToRelease(result.first, decodeColumn(cols['app_id']));
  }

  /// Finds a release by app id and version.
  Future<Release?> findByVersion({
    required String appId,
    required String version,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT r.*,
                  array_agg(rps.platform::text) as platforms,
                  array_agg(rps.status::text) as statuses
           FROM releases r
           LEFT JOIN release_platform_statuses rps ON r.id = rps.release_id
           WHERE r.app_id = @appId AND r.version = @version
           GROUP BY r.id''',
      ),
      parameters: {'appId': appId, 'version': version},
    );
    if (result.isEmpty) return null;
    return _rowToRelease(result.first, appId);
  }

  /// Updates release platform status.
  Future<void> updatePlatformStatus({
    required int releaseId,
    required ReleasePlatform platform,
    required ReleaseStatus status,
  }) async {
    await _pool.execute(
      Sql.named(
        '''INSERT INTO release_platform_statuses (release_id, platform, status)
           VALUES (@releaseId, @platform, @status)
           ON CONFLICT (release_id, platform) DO UPDATE SET status = @status''',
      ),
      parameters: {
        'releaseId': releaseId,
        'platform': platform.name,
        'status': status.name,
      },
    );
    await _pool.execute(
      Sql.named(
        'UPDATE releases SET updated_at = NOW() WHERE id = @id',
      ),
      parameters: {'id': releaseId},
    );
  }

  /// Updates release notes.
  Future<void> updateNotes({
    required int releaseId,
    required String notes,
  }) async {
    await _pool.execute(
      Sql.named(
        'UPDATE releases SET notes = @notes, updated_at = NOW() WHERE id = @id',
      ),
      parameters: {'id': releaseId, 'notes': notes},
    );
  }

  Release _rowToRelease(ResultRow row, String appId) {
    final cols = row.toColumnMap();

    final platforms = cols['platforms'] as List?;
    final statuses = cols['statuses'] as List?;

    final platformStatuses = <ReleasePlatform, ReleaseStatus>{};
    if (platforms != null && statuses != null) {
      for (var i = 0; i < platforms.length; i++) {
        final p = platforms[i];
        final s = statuses[i];
        if (p != null && s != null) {
          platformStatuses[ReleasePlatform.values.byName(p as String)] =
              ReleaseStatus.values.byName(s as String);
        }
      }
    }

    return Release(
      id: cols['id']! as int,
      appId: appId,
      version: cols['version']! as String,
      flutterRevision: cols['flutter_revision']! as String,
      flutterVersion: cols['flutter_version'] as String?,
      displayName: cols['display_name'] as String?,
      platformStatuses: platformStatuses,
      createdAt: cols['created_at']! as DateTime,
      updatedAt: cols['updated_at']! as DateTime,
      notes: cols['notes'] as String?,
    );
  }
}
