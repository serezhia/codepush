import 'package:postgres/postgres.dart';
import 'package:self_hosted_server/src/repositories/pg_helpers.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// Data access layer for apps.
class AppRepository {
  const AppRepository(this._pool);

  final Pool _pool;

  /// Creates a new app. Returns the app with generated UUID.
  Future<App> create({
    required String displayName,
    required int organizationId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        '''INSERT INTO apps (display_name, organization_id)
           VALUES (@displayName, @orgId)
           RETURNING id, display_name''',
      ),
      parameters: {'displayName': displayName, 'orgId': organizationId},
    );
    final cols = result.first.toColumnMap();
    return App(
      id: decodeColumn(cols['id']),
      displayName: cols['display_name']! as String,
    );
  }

  /// Returns all apps visible to a user (through org memberships).
  Future<List<AppMetadata>> getAppsForUser(int userId) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT a.id, a.display_name, a.created_at, a.updated_at,
                  (SELECT version FROM releases WHERE app_id = a.id
                   ORDER BY created_at DESC LIMIT 1) as latest_release_version,
                  (SELECT p.number FROM patches p
                   JOIN releases r ON p.release_id = r.id
                   WHERE r.app_id = a.id
                   ORDER BY p.created_at DESC LIMIT 1) as latest_patch_number
           FROM apps a
           JOIN organizations o ON a.organization_id = o.id
           JOIN organization_memberships om ON o.id = om.organization_id
           WHERE om.user_id = @userId
           ORDER BY a.updated_at DESC''',
      ),
      parameters: {'userId': userId},
    );

    return result.map(_rowToAppMetadata).toList();
  }

  /// Returns all apps for an organization.
  Future<List<AppMetadata>> getAppsByOrganization(int organizationId) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT a.id, a.display_name, a.created_at, a.updated_at,
                  (SELECT version FROM releases WHERE app_id = a.id
                   ORDER BY created_at DESC LIMIT 1) as latest_release_version,
                  (SELECT p.number FROM patches p
                   JOIN releases r ON p.release_id = r.id
                   WHERE r.app_id = a.id
                   ORDER BY p.created_at DESC LIMIT 1) as latest_patch_number
           FROM apps a
           WHERE a.organization_id = @orgId
           ORDER BY a.updated_at DESC''',
      ),
      parameters: {'orgId': organizationId},
    );

    return result.map(_rowToAppMetadata).toList();
  }

  /// Finds an app by id.
  Future<App?> findById(String appId) async {
    final result = await _pool.execute(
      Sql.named('SELECT id, display_name FROM apps WHERE id = @id'),
      parameters: {'id': appId},
    );
    if (result.isEmpty) return null;
    final cols = result.first.toColumnMap();
    return App(
      id: decodeColumn(cols['id']),
      displayName: cols['display_name']! as String,
    );
  }

  /// Returns the organization id for an app.
  Future<int?> getOrganizationId(String appId) async {
    final result = await _pool.execute(
      Sql.named('SELECT organization_id FROM apps WHERE id = @id'),
      parameters: {'id': appId},
    );
    if (result.isEmpty) return null;
    return result.first[0]! as int;
  }

  /// Deletes an app by id.
  Future<void> delete(String appId) async {
    await _pool.execute(
      Sql.named('DELETE FROM apps WHERE id = @id'),
      parameters: {'id': appId},
    );
  }

  /// Returns collaborators for an app.
  Future<List<Map<String, dynamic>>> getCollaborators(String appId) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT ac.id, ac.role, u.id as user_id, u.email, u.display_name
           FROM app_collaborators ac
           JOIN users u ON ac.user_id = u.id
           WHERE ac.app_id = @appId
           ORDER BY u.email''',
      ),
      parameters: {'appId': appId},
    );
    return result.map((row) {
      final cols = row.toColumnMap();
      return {
        'id': cols['id'],
        'role': cols['role'] != null ? decodeColumn(cols['role']) : null,
        'user_id': cols['user_id'],
        'email': cols['email'],
        'display_name': cols['display_name'],
      };
    }).toList();
  }

  /// Adds a collaborator to an app.
  Future<void> addCollaborator({
    required String appId,
    required int userId,
    required String role,
  }) async {
    await _pool.execute(
      Sql.named(
        '''INSERT INTO app_collaborators (app_id, user_id, role)
           VALUES (@appId, @userId, @role)
           ON CONFLICT (app_id, user_id) DO UPDATE SET role = @role''',
      ),
      parameters: {'appId': appId, 'userId': userId, 'role': role},
    );
  }

  /// Updates a collaborator's role.
  Future<void> updateCollaboratorRole({
    required String appId,
    required int userId,
    required String role,
  }) async {
    await _pool.execute(
      Sql.named(
        '''UPDATE app_collaborators SET role = @role
           WHERE app_id = @appId AND user_id = @userId''',
      ),
      parameters: {'appId': appId, 'userId': userId, 'role': role},
    );
  }

  /// Removes a collaborator from an app.
  Future<void> removeCollaborator({
    required String appId,
    required int userId,
  }) async {
    await _pool.execute(
      Sql.named(
        '''DELETE FROM app_collaborators
           WHERE app_id = @appId AND user_id = @userId''',
      ),
      parameters: {'appId': appId, 'userId': userId},
    );
  }

  AppMetadata _rowToAppMetadata(ResultRow row) {
    final cols = row.toColumnMap();
    return AppMetadata(
      appId: decodeColumn(cols['id']),
      displayName: cols['display_name']! as String,
      latestReleaseVersion: cols['latest_release_version'] as String?,
      latestPatchNumber: cols['latest_patch_number'] as int?,
      createdAt: cols['created_at']! as DateTime,
      updatedAt: cols['updated_at']! as DateTime,
    );
  }
}
