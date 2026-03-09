import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/di/app_dependencies.dart';
import 'package:shorebird_console/features/organizations/domain/organizations_bloc.dart';

class OrganizationsScreen extends StatelessWidget {
  const OrganizationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => OrganizationsBloc(
        apiClient: AppDependencies.of(ctx).apiClient,
      )..add(OrganizationsLoadRequested()),
      child: const _OrganizationsContent(),
    );
  }
}

class _OrganizationsContent extends StatelessWidget {
  const _OrganizationsContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<OrganizationsBloc, OrganizationsState>(
        builder: (context, state) {
          return switch (state) {
            OrganizationsLoading() || OrganizationsInitial() => const Center(
              child: CircularProgressIndicator(),
            ),
            OrganizationsError(:final message) => Center(
              child: Text('Error: $message'),
            ),
            OrganizationsLoaded(:final memberships) => _OrganizationsList(
              memberships: memberships,
            ),
          };
        },
      ),
    );
  }
}

class _OrganizationsList extends StatelessWidget {
  const _OrganizationsList({required this.memberships});
  final List<OrganizationMembership> memberships;

  @override
  Widget build(BuildContext context) {
    if (memberships.isEmpty) {
      return const Center(child: Text('No organizations'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: memberships.length,
      itemBuilder: (context, index) {
        final m = memberships[index];
        final org = m.organization;
        final isAdmin = m.role == Role.owner || m.role == Role.admin;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                org.organizationType == OrganizationType.personal
                    ? Icons.person
                    : Icons.business,
              ),
            ),
            title: Text(org.name),
            subtitle: Text(
              '${org.organizationType.name} · Your role: ${m.role.name}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAdmin)
                  const Chip(
                    label: Text('Admin', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.go('/organizations/${org.id}'),
          ),
        );
      },
    );
  }
}
