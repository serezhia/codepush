import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/features/organizations/domain/org_detail_bloc.dart';

/// Admin tab for managing organization members and their roles.
class MembersTab extends StatelessWidget {
  const MembersTab({required this.users, required this.orgId, super.key});

  final List<OrganizationUser> users;
  final int orgId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Members (${users.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showAddMemberDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Member'),
              ),
            ],
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? const Center(child: Text('No members'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final orgUser = users[index];
                    return _MemberTile(
                      orgUser: orgUser,
                      orgId: orgId,
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final emailController = TextEditingController();
    var selectedRole = Role.developer;
    final bloc = context.read<OrgDetailBloc>();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Member'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'user@example.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Role>(
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: selectedRole,
                  items: _assignableRoles
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Row(
                            children: [
                              Icon(_roleIcon(r), size: 18),
                              const SizedBox(width: 8),
                              Text(r.name),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedRole = v);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  bloc.add(
                    OrgMemberAddRequested(
                      orgId: orgId,
                      email: email,
                      role: selectedRole,
                    ),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  static const List<Role> _assignableRoles = [
    Role.admin,
    Role.appManager,
    Role.developer,
    Role.viewer,
  ];

  static IconData _roleIcon(Role role) {
    return switch (role) {
      Role.owner => Icons.star,
      Role.admin => Icons.admin_panel_settings,
      Role.appManager => Icons.apps,
      Role.developer => Icons.code,
      Role.viewer => Icons.visibility,
      Role.none => Icons.block,
    };
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.orgUser, required this.orgId});

  final OrganizationUser orgUser;
  final int orgId;

  @override
  Widget build(BuildContext context) {
    final user = orgUser.user;
    final isOwner = orgUser.role == Role.owner;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
          ),
        ),
        title: Text(user.displayName ?? user.email),
        subtitle: Text(user.email),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              Chip(
                avatar: const Icon(Icons.star, size: 16),
                label: const Text('Owner'),
                visualDensity: VisualDensity.compact,
              )
            else ...[
              _RoleDropdown(
                currentRole: orgUser.role,
                onChanged: (role) {
                  context.read<OrgDetailBloc>().add(
                    OrgMemberRoleUpdated(
                      orgId: orgId,
                      userId: user.id,
                      role: role,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                tooltip: 'Remove member',
                onPressed: () => _confirmRemove(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    final bloc = context.read<OrgDetailBloc>();
    final name = orgUser.user.displayName ?? orgUser.user.email;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $name from this organization?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              bloc.add(
                OrgMemberRemoved(orgId: orgId, userId: orgUser.user.id),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.currentRole, required this.onChanged});

  final Role currentRole;
  final ValueChanged<Role> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<Role>(
      value: currentRole,
      underline: const SizedBox.shrink(),
      items:
          const [
                Role.admin,
                Role.appManager,
                Role.developer,
                Role.viewer,
              ]
              .map(
                (r) => DropdownMenuItem(
                  value: r,
                  child: Text(r.name),
                ),
              )
              .toList(),
      onChanged: (v) {
        if (v != null && v != currentRole) onChanged(v);
      },
    );
  }
}
