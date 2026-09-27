import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/nocturne.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final playlists = ref.watch(playlistsProvider);
    final active = ref.watch(activePlaylistProvider);
    final pad = context.pagePadding;
    void addPlaylist() => context.push('/settings/add-playlist');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back (Esc)',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
        ),
        title: const Text('Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(playlistsProvider.future),
            child: ListView(padding: const EdgeInsets.symmetric(vertical: 16), children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: _AccountCard(email: session?.user?.email ?? '', server: session?.serverUrl ?? ''),
              ),
              const SizedBox(height: 28),
              SectionHeader(
                'Playlists',
                subtitle: 'Your IPTV sources',
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
                trailing: OutlinedButton.icon(
                  onPressed: () => context.push('/settings/add-playlist'),
                  icon: const Icon(PhosphorIconsRegular.plus),
                  label: const Text('Add playlist'),
                ),
              ),
              playlists.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                ),
                error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(playlistsProvider)),
                data: (list) => list.isEmpty
                    ? const EmptyState(icon: PhosphorIconsRegular.playlist, title: 'No playlists yet')
                    : Column(children: [
                        for (final p in list)
                          Padding(
                            padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
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
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, iconColor: AppColors.danger),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Sign out?'),
                        actions: [
                          OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
                        ],
                      ),
                    );
                    if (ok == true) await ref.read(sessionProvider.notifier).signOut();
                  },
                  icon: const Icon(PhosphorIconsRegular.signOut),
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

/// Pushed-route page header: back button + PageTitle, padding 20/24/14.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.caption, required this.onBack});
  final String title;
  final String caption;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad - 8, 20, pad, 14),
      child: Row(children: [
        NocIconButton(icon: Ph.arrowLeft, tooltip: 'Back', onPressed: onBack),
        const SizedBox(width: 6),
        Expanded(child: PageTitle(title, caption: caption)),
      ]),
    );
  }
}

/// `.card` — surface, radius md, ~14 padding.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.md)),
        child: child,
      );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.email, required this.server});
  final String email;
  final String server;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.md)),
        child: Row(children: [
          Avatar(email, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(email, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(PhosphorIconsRegular.hardDrives, size: 14, color: AppColors.neutral500),
                const SizedBox(width: 6),
                Expanded(child: Text(server, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta)),
              ]),
            ]),
          ),
        ]),
      );
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final p = playlist;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete "${p.name}"?'),
        content: Text('The playlist will be removed from your account.',
            style: TextStyle(fontSize: 14, color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.6)),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (ref.read(activePlaylistProvider) == p.id) ref.read(activePlaylistProvider.notifier).select(null);
    await _run(context, ref, () => ref.read(repositoryProvider).deletePlaylist(p.id), 'Playlist deleted');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = playlist;
    final repo = ref.read(repositoryProvider);
    final (color, label) = switch (p.status) {
      PlaylistStatus.active => (AppColors.success, 'Active'),
      PlaylistStatus.syncing => (AppColors.warning, 'Syncing'),
      PlaylistStatus.pending => (AppColors.warning, 'Pending'),
      PlaylistStatus.error => (AppColors.danger, 'Error'),
    };

    return Hoverable(
      color: AppColors.surface,
      ring: Shadows.ringFlat,
      onTap: () {
        ref.read(activePlaylistProvider.notifier).select(p.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now watching from "${p.name}"')));
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: selected ? AppColors.accent : Colors.transparent),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.neutral900, borderRadius: BorderRadius.circular(Radii.md)),
              child: Icon(p.type == PlaylistType.xtream ? PhosphorIconsRegular.hardDrives : PhosphorIconsRegular.link,
                  size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    const Tag('Watching', tone: TagTone.accent),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  '${p.type == PlaylistType.xtream ? 'Xtream Codes' : 'M3U'}${p.host != null ? ' · ${p.host}' : ''}',
                  style: AppText.meta,
                ),
              ]),
            ),
            const SizedBox(width: 8),
            if (p.isBusy)
              SizedBox.square(dimension: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
            else
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
            const SizedBox(width: 6),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Tag('${formatCount(p.channels)} channels', icon: PhosphorIconsRegular.broadcast),
            Tag('${formatCount(p.movies)} movies', icon: PhosphorIconsRegular.filmStrip),
            Tag('${formatCount(p.series)} series', icon: PhosphorIconsRegular.televisionSimple),
          ]),
          if (p.lastError != null && p.status == PlaylistStatus.error) ...[
            const SizedBox(height: 10),
            Text(p.lastError!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
          ],
          const SizedBox(height: 4),
          Row(children: [
            Text('Synced ${timeAgo(p.lastSyncedAt)}', style: AppText.meta),
            const Spacer(),
            TextButton.icon(
              onPressed: p.isBusy ? null : () => _run(context, ref, () => repo.syncPlaylist(p.id), 'Sync started'),
              icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
              label: const Text('Sync'),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger, iconColor: AppColors.danger),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text('Delete "${p.name}"?'),
                    content: const Text('The playlist will be removed from your account.'),
                    actions: [
                      OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                        ),
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
              icon: const Icon(PhosphorIconsRegular.trash),
              label: const Text('Delete'),
            ),
          ]),
        ]),
      ),
    );
  }
}
