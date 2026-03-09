import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shorebird_code_push_protocol/shorebird_code_push_protocol.dart';
import 'package:shorebird_console/di/app_dependencies.dart';
import 'package:shorebird_console/features/releases/domain/release_detail_bloc.dart';

class ReleaseDetailScreen extends StatelessWidget {
  const ReleaseDetailScreen({
    required this.appId,
    required this.releaseId,
    super.key,
  });

  final String appId;
  final int releaseId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ReleaseDetailBloc(
        apiClient: AppDependencies.of(ctx).apiClient,
      )..add(ReleaseDetailLoadRequested(appId: appId, releaseId: releaseId)),
      child: _ReleaseDetailContent(appId: appId, releaseId: releaseId),
    );
  }
}

class _ReleaseDetailContent extends StatelessWidget {
  const _ReleaseDetailContent({
    required this.appId,
    required this.releaseId,
  });

  final String appId;
  final int releaseId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReleaseDetailBloc, ReleaseDetailState>(
      builder: (context, state) {
        return switch (state) {
          ReleaseDetailLoading() || ReleaseDetailInitial() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          ReleaseDetailError(:final message) => Scaffold(
            body: Center(child: Text('Error: $message')),
          ),
          ReleaseDetailLoaded(
            :final release,
            :final patches,
            :final artifacts,
            :final channels,
          ) =>
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ReleaseInfoCard(release: release),
                  const SizedBox(height: 16),
                  _PlatformStatusSection(
                    release: release,
                    appId: appId,
                    releaseId: releaseId,
                  ),
                  const SizedBox(height: 16),
                  _ArtifactsSection(artifacts: artifacts),
                  const SizedBox(height: 16),
                  _PatchesSection(
                    patches: patches,
                    channels: channels,
                    appId: appId,
                    releaseId: releaseId,
                  ),
                ],
              ),
            ),
        };
      },
    );
  }
}

class _ReleaseInfoCard extends StatelessWidget {
  const _ReleaseInfoCard({required this.release});
  final Release release;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Release v${release.version}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (release.displayName != null)
                  _InfoChip(
                    icon: Icons.label_outline,
                    label: release.displayName!,
                  ),
                if (release.flutterVersion != null)
                  _InfoChip(
                    icon: Icons.flutter_dash,
                    label: 'Flutter ${release.flutterVersion}',
                  ),
                _InfoChip(
                  icon: Icons.code,
                  label: release.flutterRevision.substring(0, 8),
                ),
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: _formatDate(release.createdAt),
                ),
              ],
            ),
            if (release.notes != null) ...[
              const SizedBox(height: 12),
              Text(release.notes!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PlatformStatusSection extends StatelessWidget {
  const _PlatformStatusSection({
    required this.release,
    required this.appId,
    required this.releaseId,
  });

  final Release release;
  final String appId;
  final int releaseId;

  @override
  Widget build(BuildContext context) {
    final statuses = release.platformStatuses;
    if (statuses.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statuses.entries.map((e) {
                return ActionChip(
                  avatar: Icon(
                    e.value == ReleaseStatus.active
                        ? Icons.check_circle
                        : Icons.pause_circle,
                    color: e.value == ReleaseStatus.active
                        ? Colors.green
                        : Colors.orange,
                    size: 18,
                  ),
                  label: Text('${e.key.name}: ${e.value.name}'),
                  onPressed: () {
                    final newStatus = e.value == ReleaseStatus.active
                        ? ReleaseStatus.draft
                        : ReleaseStatus.active;
                    context.read<ReleaseDetailBloc>().add(
                      ReleaseStatusUpdated(
                        appId: appId,
                        releaseId: releaseId,
                        platform: e.key,
                        status: newStatus,
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtifactsSection extends StatelessWidget {
  const _ArtifactsSection({required this.artifacts});
  final List<ReleaseArtifact> artifacts;

  @override
  Widget build(BuildContext context) {
    if (artifacts.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Artifacts (${artifacts.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...artifacts.map(
              (a) => ListTile(
                dense: true,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text('${a.platform.name} / ${a.arch}'),
                subtitle: Text(
                  'Size: ${(a.size / 1024).toStringAsFixed(1)} KB',
                ),
                trailing: Text(
                  a.hash.substring(0, 12),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatchesSection extends StatelessWidget {
  const _PatchesSection({
    required this.patches,
    required this.channels,
    required this.appId,
    required this.releaseId,
  });

  final List<ReleasePatch> patches;
  final List<Channel> channels;
  final String appId;
  final int releaseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patches (${patches.length})',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (patches.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No patches')),
              )
            else
              ...patches.map(
                (p) => _PatchTile(
                  patch: p,
                  channels: channels,
                  appId: appId,
                  releaseId: releaseId,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PatchTile extends StatelessWidget {
  const _PatchTile({
    required this.patch,
    required this.channels,
    required this.appId,
    required this.releaseId,
  });

  final ReleasePatch patch;
  final List<Channel> channels;
  final String appId;
  final int releaseId;

  @override
  Widget build(BuildContext context) {
    final isRolledBack = patch.isRolledBack;

    return Card(
      color: isRolledBack ? Colors.red.withValues(alpha: 0.05) : null,
      child: ExpansionTile(
        leading: Icon(
          isRolledBack ? Icons.undo : Icons.system_update_alt,
          color: isRolledBack ? Colors.red : null,
        ),
        title: Row(
          children: [
            Text('Patch #${patch.number}'),
            if (isRolledBack) ...[
              const SizedBox(width: 8),
              const Chip(
                label: Text('Rolled Back', style: TextStyle(fontSize: 11)),
                backgroundColor: Color(0x20FF0000),
                visualDensity: VisualDensity.compact,
              ),
            ],
            if (patch.channel != null) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  patch.channel!,
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        subtitle: patch.notes != null ? Text(patch.notes!) : null,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (!isRolledBack) ...[
                  FilledButton.tonalIcon(
                    onPressed: () => _confirmRollback(context),
                    icon: const Icon(Icons.undo),
                    label: const Text('Rollback'),
                  ),
                  const SizedBox(width: 8),
                  _PromoteButton(
                    channels: channels,
                    onPromote: (channelId) {
                      context.read<ReleaseDetailBloc>().add(
                        PatchPromoteRequested(
                          appId: appId,
                          releaseId: releaseId,
                          patchId: patch.id,
                          channelId: channelId,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          if (patch.artifacts.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patch Artifacts',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  ...patch.artifacts.map(
                    (a) => ListTile(
                      dense: true,
                      title: Text('${a.platform.name} / ${a.arch}'),
                      subtitle: Text(
                        'Size: ${(a.size / 1024).toStringAsFixed(1)} KB',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmRollback(BuildContext context) {
    final bloc = context.read<ReleaseDetailBloc>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rollback Patch'),
        content: Text(
          'Are you sure you want to rollback Patch #${patch.number}? '
          'This will prevent devices from downloading this patch.',
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
                PatchRollbackRequested(
                  appId: appId,
                  releaseId: releaseId,
                  patchId: patch.id,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Rollback'),
          ),
        ],
      ),
    );
  }
}

class _PromoteButton extends StatelessWidget {
  const _PromoteButton({
    required this.channels,
    required this.onPromote,
  });

  final List<Channel> channels;
  final ValueChanged<int> onPromote;

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<int>(
      itemBuilder: (ctx) => channels
          .map(
            (c) => PopupMenuItem(value: c.id, child: Text(c.name)),
          )
          .toList(),
      onSelected: onPromote,
      child: FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.moving),
        label: const Text('Promote'),
      ),
    );
  }
}
