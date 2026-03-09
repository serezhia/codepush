import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/di/app_dependencies.dart';
import 'package:shorebird_console/features/apps/domain/app_detail_bloc.dart';
import 'package:shorebird_console/features/apps/presentation/components/collaborators_tab.dart';

class AppDetailScreen extends StatelessWidget {
  const AppDetailScreen({required this.appId, super.key});

  final String appId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AppDetailBloc(
        apiClient: AppDependencies.of(ctx).apiClient,
      )..add(AppDetailLoadRequested(appId)),
      child: _AppDetailContent(appId: appId),
    );
  }
}

class _AppDetailContent extends StatelessWidget {
  const _AppDetailContent({required this.appId});

  final String appId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppDetailBloc, AppDetailState>(
      builder: (context, state) {
        return switch (state) {
          AppDetailLoading() || AppDetailInitial() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          AppDetailError(:final message) => Scaffold(
            body: Center(child: Text('Error: $message')),
          ),
          AppDetailLoaded(
            :final releases,
            :final channels,
            :final collaborators,
          ) =>
            DefaultTabController(
              length: 3,
              child: Scaffold(
                appBar: TabBar(
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.new_releases_outlined),
                      text: 'Releases (${releases.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.track_changes),
                      text: 'Channels (${channels.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.people_outline),
                      text: 'Collaborators (${collaborators.length})',
                    ),
                  ],
                ),
                body: TabBarView(
                  children: [
                    _ReleasesTab(releases: releases, appId: appId),
                    _ChannelsTab(channels: channels, appId: appId),
                    CollaboratorsTab(
                      collaborators: collaborators,
                      appId: appId,
                    ),
                  ],
                ),
              ),
            ),
        };
      },
    );
  }
}

class _ReleasesTab extends StatelessWidget {
  const _ReleasesTab({required this.releases, required this.appId});
  final List<Release> releases;
  final String appId;

  @override
  Widget build(BuildContext context) {
    if (releases.isEmpty) {
      return const Center(child: Text('No releases yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: releases.length,
      itemBuilder: (context, index) {
        final release = releases[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.new_releases),
            title: Text('v${release.version}'),
            subtitle: Text(
              [
                if (release.displayName != null) release.displayName!,
                if (release.flutterVersion != null)
                  'Flutter ${release.flutterVersion}',
              ].join(' · '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._platformChips(release.platformStatuses),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.go(
              '/apps/$appId/releases/${release.id}',
            ),
          ),
        );
      },
    );
  }

  List<Widget> _platformChips(Map<ReleasePlatform, ReleaseStatus> statuses) {
    return statuses.entries.map((e) {
      final color = switch (e.value) {
        ReleaseStatus.active => Colors.green,
        _ => Colors.grey,
      };
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Chip(
          label: Text(e.key.name, style: const TextStyle(fontSize: 11)),
          backgroundColor: color.withValues(alpha: 0.2),
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList();
  }
}

class _ChannelsTab extends StatelessWidget {
  const _ChannelsTab({required this.channels, required this.appId});
  final List<Channel> channels;
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
                'Channels',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showCreateChannelDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Channel'),
              ),
            ],
          ),
        ),
        Expanded(
          child: channels.isEmpty
              ? const Center(child: Text('No channels'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.track_changes),
                        title: Text(channel.name),
                        subtitle: Text('ID: ${channel.id}'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateChannelDialog(BuildContext context) {
    final controller = TextEditingController();
    final deps = AppDependencies.of(context);
    final bloc = context.read<AppDetailBloc>();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Channel'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Channel Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await deps.apiClient.createChannel(
                  appId: appId,
                  name: name,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                bloc.add(AppDetailLoadRequested(appId));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
