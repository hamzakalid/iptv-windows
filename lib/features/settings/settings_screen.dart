import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
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
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PageHeader(
            title: 'Settings',
            caption: 'Account, playlists and session',
            onBack: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(playlistsProvider.future),
              child: ListView(padding: EdgeInsets.fromLTRB(pad, 6, pad, 32), children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Overline('Account', padding: EdgeInsets.only(bottom: 8)),
                      _AccountCard(email: session?.user?.email ?? '', server: session?.serverUrl ?? ''),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          const Overline('Playlists'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Your IPTV sources · tap one to watch from it',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.n600)),
                          ),
                          NocButton(label: 'Add playlist', icon: Ph.plus, height: 32, fontSize: 13, onPressed: addPlaylist),
                        ]),
                      ),
                      playlists.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(playlistsProvider)),
                        data: (list) => list.isEmpty
                            ? _Card(
                                child: EmptyState(
                                  icon: Ph.playlist,
                                  title: 'No playlists yet',
                                  message: 'Add an Xtream Codes account or an M3U link to start watching.',
                                  action: NocButton.primary(label: 'Add playlist', icon: Ph.plus, onPressed: addPlaylist),
                                ),
                              )
                            : Column(children: [
                                for (final p in list)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _PlaylistCard(
                                      playlist: p,
                                      // With no explicit choice the backend uses the newest active one.
                                      selected: active == null
                                          ? p ==
                                              list.firstWhere((x) => x.status == PlaylistStatus.active,
                                                  orElse: () => list.first)
                                          : active == p.id,
                                    ),
                                  ),
                              ]),
                      ),
                      const SizedBox(height: 28),
                      const Overline('Session', padding: EdgeInsets.only(bottom: 8)),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Sign out?'),
                                content: Text('You can sign back in at any time.',
                                    style: TextStyle(fontSize: 14, color: AppColors.muted)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out')),
                                ],
                              ),
                            );
                            if (ok == true) await ref.read(sessionProvider.notifier).signOut();
                          },
                          icon: const Icon(Ph.signOut, color: AppColors.danger),
                          label: const Text('Sign out'),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
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
  Widget build(BuildContext context) => _Card(
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.a900,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent),
            ),
            child: Text(email.isEmpty ? '?' : email[0].toUpperCase(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.a300)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Ph.hardDrives, size: 13, color: AppColors.n500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(server, maxLines: 1, overflow: TextOverflow.ellipsis, style: NocText.muted),
                ),
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
    final (kind, label) = switch (p.status) {
      PlaylistStatus.active => (TagKind.accent, 'Active'),
      PlaylistStatus.syncing => (TagKind.accent, 'Syncing'),
      PlaylistStatus.pending => (TagKind.neutral, 'Pending'),
      PlaylistStatus.error => (TagKind.neutral, 'Error'),
    };
    final xtream = p.type == PlaylistType.xtream;
    final counts = '${formatCount(p.channels)} channels · ${formatCount(p.movies)} movies · '
        '${formatCount(p.series)} series';

    return HoverRing(
      active: selected,
      onTap: () {
        ref.read(activePlaylistProvider.notifier).select(p.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now watching from "${p.name}"')));
      },
      child: _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.n900,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(xtream ? Ph.hardDrives : Ph.link, size: 18,
                  color: selected ? AppColors.accent : AppColors.n400),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    const NocTag('Watching', kind: TagKind.outline, icon: Ph.check),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  '${xtream ? 'Xtream Codes' : 'M3U'}${p.host != null ? ' · ${p.host}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NocText.muted,
                ),
              ]),
            ),
            const SizedBox(width: 10),
            NocTag(
              label,
              kind: kind,
              leading: p.isBusy
                  ? SizedBox.square(
                      dimension: 9,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.4,
                        color: kind == TagKind.accent ? AppColors.a100 : AppColors.n100,
                      ),
                    )
                  : null,
              icon: p.status == PlaylistStatus.error ? Ph.warningCircle : null,
            ),
          ]),
          const SizedBox(height: 12),
          Text(counts,
              style: const TextStyle(fontSize: 13, color: AppColors.n400, fontFeatures: NocText.tabular)),
          if (p.lastError != null && p.status == PlaylistStatus.error) ...[
            const SizedBox(height: 8),
            Text(p.lastError!,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.danger.withValues(alpha: 0.9))),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text('Synced ${timeAgo(p.lastSyncedAt)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: NocText.muted),
            ),
            NocButton(
              label: 'Sync',
              icon: Ph.arrowsClockwise,
              height: 32,
              fontSize: 13,
              onPressed: p.isBusy ? null : () => _run(context, ref, () => repo.syncPlaylist(p.id), 'Sync started'),
            ),
            const SizedBox(width: 4),
            NocIconButton(
              icon: Ph.trash,
              size: 32,
              iconSize: 17,
              color: AppColors.danger,
              tooltip: 'Delete playlist',
              onPressed: () => _delete(context, ref),
            ),
          ]),
        ]),
      ),
    );
  }
}
