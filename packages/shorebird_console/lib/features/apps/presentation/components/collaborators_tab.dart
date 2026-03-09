import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/data/dto/dto.dart';
import 'package:shorebird_console/features/apps/domain/app_detail_bloc.dart';

class CollaboratorsTab extends StatelessWidget {
  const CollaboratorsTab({
    required this.collaborators,
    required this.appId,
    super.key,
  });

  final List<AppCollaborator> collaborators;
  final String appId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Collaborators',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: collaborators.isEmpty
              ? const Center(child: Text('No collaborators'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: collaborators.length,
                  itemBuilder: (context, index) {
                    final c = collaborators[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(c.displayName ?? c.email),
                        subtitle: Text(c.email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RoleDropdown(
                              currentRole: c.role,
                              onChanged: (role) {
                                context.read<AppDetailBloc>().add(
                                  AppCollaboratorRoleUpdated(
                                    appId: appId,
                                    userId: c.userId,
                                    role: role,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: Colors.red,
                              tooltip: 'Remove',
                              onPressed: () => _confirmRemove(context, c),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    final bloc = context.read<AppDetailBloc>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Collaborator'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'user@example.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final email = controller.text.trim();
              if (email.isNotEmpty) {
                bloc.add(
                  AppCollaboratorAddRequested(appId: appId, email: email),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context, AppCollaborator collaborator) {
    final bloc = context.read<AppDetailBloc>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: Text(
          'Remove ${collaborator.displayName ?? collaborator.email} '
          'from this app?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              bloc.add(
                AppCollaboratorRemoved(
                  appId: appId,
                  userId: collaborator.userId,
                ),
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

  final AppCollaboratorRole currentRole;
  final ValueChanged<AppCollaboratorRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<AppCollaboratorRole>(
      value: currentRole,
      underline: const SizedBox.shrink(),
      items: AppCollaboratorRole.values
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
