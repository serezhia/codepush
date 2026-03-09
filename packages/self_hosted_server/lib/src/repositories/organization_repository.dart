import 'package:postgres/postgres.dart';
import 'package:self_hosted_server/src/repositories/pg_helpers.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';

/// Data access layer for organizations and memberships.
class OrganizationRepository {
  const OrganizationRepository(this._pool);

  final Pool _pool;

  /// Creates a new organization. Returns the organization id.
  Future<int> create({
    required String name,
    OrganizationType type = OrganizationType.personal,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        '''INSERT INTO organizations (name, organization_type)
           VALUES (@name, @type)
           RETURNING id''',
      ),
      parameters: {'name': name, 'type': type.name},
    );
    return result.first[0]! as int;
  }

  /// Adds a membership for a user in an organization.
  Future<void> addMembership({
    required int userId,
    required int organizationId,
    required Role role,
  }) async {
    await _pool.execute(
      Sql.named(
        '''INSERT INTO organization_memberships (user_id, organization_id, role)
           VALUES (@userId, @orgId, @role)
           ON CONFLICT (user_id, organization_id) DO UPDATE SET role = @role''',
      ),
      parameters: {
        'userId': userId,
        'orgId': organizationId,
        'role': role.name,
      },
    );
  }

  /// Returns all organizations a user is a member of with their roles.
  Future<List<OrganizationMembership>> getUserOrganizations(int userId) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT o.id, o.name, o.organization_type, o.created_at, o.updated_at,
                  om.role
           FROM organizations o
           JOIN organization_memberships om ON o.id = om.organization_id
           WHERE om.user_id = @userId''',
      ),
      parameters: {'userId': userId},
    );

    return result.map((row) {
      final cols = row.toColumnMap();
      return OrganizationMembership(
        organization: Organization(
          id: cols['id']! as int,
          name: cols['name']! as String,
          organizationType: OrganizationType.values.byName(
            decodeColumn(cols['organization_type']),
          ),
          createdAt: cols['created_at']! as DateTime,
          updatedAt: cols['updated_at']! as DateTime,
        ),
        role: Role.values.byName(decodeColumn(cols['role'])),
      );
    }).toList();
  }

  /// Returns all users in an organization with their roles.
  Future<List<OrganizationUser>> getOrganizationUsers(
    int organizationId,
  ) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT u.id, u.email, u.display_name, om.role
           FROM users u
           JOIN organization_memberships om ON u.id = om.user_id
           WHERE om.organization_id = @orgId''',
      ),
      parameters: {'orgId': organizationId},
    );

    return result.map((row) {
      final cols = row.toColumnMap();
      return OrganizationUser(
        user: PublicUser(
          id: cols['id']! as int,
          email: cols['email']! as String,
          displayName: cols['display_name'] as String?,
        ),
        role: Role.values.byName(decodeColumn(cols['role'])),
      );
    }).toList();
  }

  /// Finds an organization by id.
  Future<Organization?> findById(int id) async {
    final result = await _pool.execute(
      Sql.named('SELECT * FROM organizations WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    final cols = result.first.toColumnMap();
    return Organization(
      id: cols['id']! as int,
      name: cols['name']! as String,
      organizationType: OrganizationType.values.byName(
        decodeColumn(cols['organization_type']),
      ),
      createdAt: cols['created_at']! as DateTime,
      updatedAt: cols['updated_at']! as DateTime,
    );
  }

  /// Removes a membership.
  Future<void> removeMembership({
    required int userId,
    required int organizationId,
  }) async {
    await _pool.execute(
      Sql.named(
        '''DELETE FROM organization_memberships
           WHERE user_id = @userId AND organization_id = @orgId''',
      ),
      parameters: {'userId': userId, 'orgId': organizationId},
    );
  }

  /// Checks if a user has a specific role (or higher) in an organization.
  Future<Role?> getUserRole({
    required int userId,
    required int organizationId,
  }) async {
    final result = await _pool.execute(
      Sql.named(
        '''SELECT role FROM organization_memberships
           WHERE user_id = @userId AND organization_id = @orgId''',
      ),
      parameters: {'userId': userId, 'orgId': organizationId},
    );
    if (result.isEmpty) return null;
    return Role.values.byName(decodeColumn(result.first[0]));
  }
}
