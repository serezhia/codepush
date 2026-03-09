import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/di/app_dependencies.dart';
import 'package:shorebird_console/features/apps/domain/apps_bloc.dart';
import 'package:shorebird_console/features/organizations/domain/organizations_bloc.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<AppsBloc, AppsState>(
        builder: (context, state) {
          return switch (state) {
            AppsLoading() || AppsInitial() => const Center(
              child: CircularProgressIndicator(),
            ),
            AppsError(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(message),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        context.read<AppsBloc>().add(AppsLoadRequested()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            AppsLoaded(:final apps) => _AppsList(apps: apps),
          };
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New App'),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final deps = AppDependencies.of(context);
    final appsBloc = context.read<AppsBloc>();

    showDialog<void>(
      context: context,
      builder: (ctx) => BlocProvider(
        create: (_) =>
            OrganizationsBloc(apiClient: deps.apiClient)
              ..add(OrganizationsLoadRequested()),
        child: _CreateAppDialog(
          nameController: nameController,
          appsBloc: appsBloc,
        ),
      ),
    );
  }
}

class _CreateAppDialog extends StatefulWidget {
  const _CreateAppDialog({
    required this.nameController,
    required this.appsBloc,
  });

  final TextEditingController nameController;
  final AppsBloc appsBloc;

  @override
  State<_CreateAppDialog> createState() => _CreateAppDialogState();
}

class _CreateAppDialogState extends State<_CreateAppDialog> {
  int? _selectedOrgId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create App'),
      content: SizedBox(
        width: 360,
        child: BlocBuilder<OrganizationsBloc, OrganizationsState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: widget.nameController,
                  decoration: const InputDecoration(
                    labelText: 'App Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (state is OrganizationsLoaded) ...[
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Organization',
                      border: OutlineInputBorder(),
                    ),
                    items: state.memberships
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.organization.id,
                            child: Text(m.organization.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedOrgId = v),
                  ),
                ] else if (state is OrganizationsLoading) ...[
                  const LinearProgressIndicator(),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = widget.nameController.text.trim();
            if (name.isNotEmpty && _selectedOrgId != null) {
              widget.appsBloc.add(
                AppCreateRequested(
                  displayName: name,
                  organizationId: _selectedOrgId!,
                ),
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _AppsList extends StatelessWidget {
  const _AppsList({required this.apps});
  final List<AppMetadata> apps;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No apps yet. Create your first app!'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.apps)),
            title: Text(app.displayName),
            subtitle: Text(app.appId),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (app.latestReleaseVersion != null)
                  Chip(label: Text('v${app.latestReleaseVersion}')),
                if (app.latestPatchNumber != null) ...[
                  const SizedBox(width: 8),
                  Chip(label: Text('Patch #${app.latestPatchNumber}')),
                ],
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.go('/apps/${app.appId}'),
          ),
        );
      },
    );
  }
}
