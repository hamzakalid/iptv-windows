import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_row.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final playlists = ref.watch(playlistsProvider);
    final active = ref.watch(activePlaylistProvider);
    final pad = context.pagePadding;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(playlistsProvider.future),
            child: ListView(padding: EdgeInsets.symmetric(vertical: 16), children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: _AccountCard(email: session?.user?.email ?? '', server: session?.serverUrl ?? ''),
              ),
              const SizedBox(height: 32),
              SectionHeader(
                'Playlists',
                subtitle: 'Your IPTV sources',
                trailing: FilledButton.tonalIcon(
                  onPressed: () => context.push('/settings/add-playlist'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ),
              playlists.when(
                loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(playlistsProvider)),
                data: (list) => list.isEmpty
                    ? const EmptyState(icon: Icons.playlist_add_rounded, title: 'No playlists yet')
                    : Column(children: [
                        for (final p in list)
                          Padding(
                            padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
                            child: _PlaylistCard(
                              playlist: p,
                              // With no explicit choice the backend uses the newest active one.
                              selected: active == null ? p == list.firstWhere((x) => x.status == PlaylistStatus.active, orElse: () => list.first) : active == p.id,
                            ),
                          ),
                      ]),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Sign out?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
                        ],
                      ),
                    );
                    if (ok == true) await ref.read(sessionProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email, required this.server});
  final String email;
  final String server;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [
          AppColors.primary.withValues(alpha: 0.35),
          AppColors.accent.withValues(alpha: 0.2),
        ]),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white.withValues(alpha: 0.15),
          child: Text(email.isEmpty ? '?' : email[0].toUpperCase(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(email, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.dns_outlined, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(server, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: Colors.white70)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _PlaylistCard extends ConsumerWidget {
  const _PlaylistCard({required this.playlist, required this.selected});
  final Playlist playlist;
  final bool selected;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, String done) async {
    try {
      await action();
      ref.invalidate(playlistsProvider);
      ref.invalidate(homeProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = playlist;
    final repo = ref.read(repositoryProvider);
    final t = Theme.of(context).textTheme;
    final (color, label) = switch (p.status) {
      PlaylistStatus.active => (AppColors.success, 'Active'),
      PlaylistStatus.syncing => (AppColors.warning, 'Syncing'),
      PlaylistStatus.pending => (AppColors.warning, 'Pending'),
      PlaylistStatus.error => (AppColors.danger, 'Error'),
    };

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.outline, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          ref.read(activePlaylistProvider.notifier).select(p.id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now watching from "${p.name}"')));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                child: Icon(p.type == PlaylistType.xtream ? Icons.dns_rounded : Icons.link_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(p.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary),
                    ],
                  ]),
                  Text(
                    '${p.type == PlaylistType.xtream ? 'Xtream Codes' : 'M3U'}${p.host != null ? ' · ${p.host}' : ''}',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (p.isBusy)
                    SizedBox.square(dimension: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
                  else
                    Icon(Icons.circle, size: 8, color: color),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              MetaChip('${formatCount(p.channels)} channels', icon: Icons.live_tv_rounded),
              MetaChip('${formatCount(p.movies)} movies', icon: Icons.movie_outlined),
              MetaChip('${formatCount(p.series)} series', icon: Icons.video_library_outlined),
            ]),
            if (p.lastError != null && p.status == PlaylistStatus.error) ...[
              const SizedBox(height: 10),
              Text(p.lastError!, style: t.bodySmall?.copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: 6),
            Row(children: [
              Text('Synced ${timeAgo(p.lastSyncedAt)}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              const Spacer(),
              TextButton.icon(
                onPressed: p.isBusy ? null : () => _run(context, ref, () => repo.syncPlaylist(p.id), 'Sync started'),
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('Sync'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text('Delete "${p.name}"?'),
                      content: const Text('The playlist will be removed from your account.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  if (ref.read(activePlaylistProvider) == p.id) ref.read(activePlaylistProvider.notifier).select(null);
                  await _run(context, ref, () => repo.deletePlaylist(p.id), 'Playlist deleted');
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
