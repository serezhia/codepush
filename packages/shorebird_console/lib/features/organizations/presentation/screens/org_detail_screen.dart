import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/di/app_dependencies.dart';
import 'package:shorebird_console/features/organizations/domain/org_detail_bloc.dart';
import 'package:shorebird_console/features/organizations/presentation/components/members_tab.dart';

class OrgDetailScreen extends StatelessWidget {
  const OrgDetailScreen({required this.orgId, super.key});

  final int orgId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => OrgDetailBloc(
        apiClient: AppDependencies.of(ctx).apiClient,
      )..add(OrgDetailLoadRequested(orgId)),
      child: _OrgDetailContent(orgId: orgId),
    );
  }
}

class _OrgDetailContent extends StatelessWidget {
  const _OrgDetailContent({required this.orgId});

  final int orgId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrgDetailBloc, OrgDetailState>(
      builder: (context, state) {
        return switch (state) {
          OrgDetailLoading() || OrgDetailInitial() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          OrgDetailError(:final message) => Scaffold(
            body: Center(child: Text('Error: $message')),
          ),
          OrgDetailLoaded(:final users, :final apps) => DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.people), text: 'Members'),
                  Tab(icon: Icon(Icons.apps), text: 'Apps'),
                ],
              ),
              body: TabBarView(
                children: [
                  MembersTab(users: users, orgId: orgId),
                  _OrgAppsTab(apps: apps),
                ],
              ),
            ),
          ),
        };
      },
    );
  }
}

class _OrgAppsTab extends StatelessWidget {
  const _OrgAppsTab({required this.apps});
  final List<AppMetadata> apps;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return const Center(child: Text('No apps in this organization'));
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
