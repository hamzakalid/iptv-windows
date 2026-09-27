import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/account.dart';
import '../models/media.dart';
import '../state/providers.dart';
import 'common.dart';
import 'media_cards.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon, this.branch, {this.location});
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int branch;
  final String? location;
}

const _mobileDests = [
  _Dest('Home', Icons.home_outlined, Icons.home_rounded, 0),
  _Dest('Movies', Icons.movie_outlined, Icons.movie_rounded, 1),
  _Dest('Series', Icons.video_library_outlined, Icons.video_library_rounded, 2),
  _Dest('Live TV', Icons.live_tv_outlined, Icons.live_tv_rounded, 3),
  _Dest('Library', Icons.bookmark_border_rounded, Icons.bookmark_rounded, 4),
];

const _sidebarMenu = [
  _Dest('Home', Icons.home_outlined, Icons.home_rounded, 0),
  _Dest('Movies', Icons.movie_outlined, Icons.movie_rounded, 1),
  _Dest('Series', Icons.video_library_outlined, Icons.video_library_rounded, 2),
  _Dest('Live TV', Icons.live_tv_outlined, Icons.live_tv_rounded, 3),
];

const _sidebarLibrary = [
  _Dest('My List', Icons.favorite_border_rounded, Icons.favorite_rounded, 4, location: '/library'),
  _Dest('History', Icons.history_rounded, Icons.history_rounded, 4, location: '/library?tab=history'),
];

/// Bottom navigation on phones; sidebar + top bar on tablets and desktop.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    if (context.isWide) {
      return Scaffold(
        body: Row(children: [
          _Sidebar(shell: shell),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(children: [
              const TopBar(),
              Expanded(child: shell),
            ]),
          ),
        ]),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          for (final d in _mobileDests)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = context.isExpanded;
    final t = Theme.of(context).textTheme;
    final location = GoRouterState.of(context).uri.toString();
    final continueWatching = ref.watch(homeProvider).value?.continueWatching ?? const <ContinueItem>[];

    bool isSelected(_Dest d) {
      if (d.branch != shell.currentIndex) return false;
      if (d.location == null) return true;
      final wantsHistory = d.location!.contains('tab=history');
      return location.contains('tab=history') == wantsHistory;
    }

    void go(_Dest d) {
      if (d.location != null) {
        context.go(d.location!);
      } else {
        shell.goBranch(d.branch, initialLocation: d.branch == shell.currentIndex);
      }
    }

    Widget label(String text) => expanded
        ? Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
            child: Text(text.toUpperCase(),
                style: t.labelSmall?.copyWith(color: AppColors.textMuted, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          )
        : const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider());

    return Container(
      width: expanded ? 236 : 84,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Logo(expanded: expanded),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                label('Menu'),
                for (final d in _sidebarMenu)
                  _NavItem(dest: d, selected: isSelected(d), expanded: expanded, onTap: () => go(d)),
                label('Library'),
                for (final d in _sidebarLibrary)
                  _NavItem(dest: d, selected: isSelected(d), expanded: expanded, onTap: () => go(d)),
                if (expanded && continueWatching.isNotEmpty) ...[
                  label('Continue watching'),
                  for (final c in continueWatching.take(4)) _ContinueTile(entry: c),
                ],
              ],
            ),
          ),
          _NavItem(
            dest: const _Dest('Settings', Icons.settings_outlined, Icons.settings_rounded, -1),
            selected: false,
            expanded: expanded,
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.play_arrow_rounded, color: AppColors.bg, size: 22),
          ),
          if (expanded) ...[
            const SizedBox(width: 10),
            Text(appName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
          ],
        ],
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.dest, required this.selected, required this.expanded, required this.onTap});
  final _Dest dest;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Tooltip(
          message: expanded ? '' : dest.label,
          child: Material(
            color: selected ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              hoverColor: AppColors.surfaceHigh,
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0, vertical: 11),
                child: Row(
                  mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    Icon(selected ? dest.selectedIcon : dest.icon,
                        color: selected ? AppColors.text : AppColors.textMuted, size: 21),
                    if (expanded) ...[
                      const SizedBox(width: 12),
                      Text(dest.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? AppColors.text : AppColors.textMuted,
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _ContinueTile extends StatelessWidget {
  const _ContinueTile({required this.entry});
  final ContinueItem entry;

  @override
  Widget build(BuildContext context) {
    final item = entry.item!;
    final t = Theme.of(context).textTheme;
    final subtitle = entry.kind == MediaKind.series && entry.season != null
        ? 'S${entry.season} · E${entry.episode ?? '?'}'
        : '${entry.progressPct.round()}% · ${formatDuration(entry.positionSecs)}';
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.surfaceHigh,
        onTap: () => resumeEntry(context, entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 76,
                height: 46,
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(item.backdrop, label: item.name, memCacheWidth: 200),
                  const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22)),
                  Positioned(left: 0, right: 0, bottom: 0, child: ProgressBar(entry.progressPct / 100, height: 3)),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

const searchScopes = ['All', 'Movies', 'Series', 'Live TV'];

class TopBar extends ConsumerStatefulWidget {
  const TopBar({super.key});

  @override
  ConsumerState<TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<TopBar> {
  final _search = TextEditingController();
  int _scope = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    context.push('/search?q=${Uri.encodeQueryComponent(query)}&scope=$_scope');
    _search.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: Row(children: [
        PopupMenuButton<int>(
          tooltip: 'Search in',
          initialValue: _scope,
          onSelected: (v) => setState(() => _scope = v),
          itemBuilder: (_) => [
            for (var i = 0; i < searchScopes.length; i++) PopupMenuItem(value: i, child: Text(searchScopes[i])),
          ],
          child: Container(
            height: 42,
            padding: const EdgeInsets.only(left: 14, right: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(Radii.input),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(children: [
              Text(searchScopes[_scope], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textMuted),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _search,
              onSubmitted: _submit,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Movies, series, channels…',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  onPressed: () => _submit(_search.text),
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        const WhatsNewButton(),
        const SizedBox(width: 6),
        const _ProfileMenu(),
      ]),
    );
  }
}

/// Bell with a badge for titles added since the last visit.
class WhatsNewButton extends ConsumerWidget {
  const WhatsNewButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(whatsNewProvider);
    return MenuAnchor(
      alignmentOffset: const Offset(-200, 8),
      menuChildren: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text('Nothing new since your last visit', style: TextStyle(color: AppColors.textMuted)),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text('${items.length} new title${items.length == 1 ? '' : 's'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final m in items.take(8))
            MenuItemButton(
              onPressed: () => openItem(context, m),
              leadingIcon: SizedBox(
                width: 30,
                height: 44,
                child: ClipRRect(borderRadius: BorderRadius.circular(6), child: NetImage(m.logo, label: m.name)),
              ),
              child: SizedBox(
                width: 220,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${m.kind.label} · added ${timeAgo(m.createdAt)}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ]),
              ),
            ),
          const Divider(),
          MenuItemButton(
            onPressed: () => ref.read(lastSeenProvider.notifier).markSeen(),
            leadingIcon: const Icon(Icons.done_all_rounded, size: 18),
            child: const Text('Mark all as seen'),
          ),
        ],
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: "What's new",
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: Badge(
          isLabelVisible: items.isNotEmpty,
          label: Text('${items.length}'),
          backgroundColor: AppColors.accent,
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ),
    );
  }
}

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(sessionProvider).value?.user?.email ?? '';
    final playlists = ref.watch(playlistsProvider).value ?? const <Playlist>[];
    final activeId = ref.watch(activePlaylistProvider);
    final active = playlists.where((p) => p.id == activeId).firstOrNull ??
        playlists.where((p) => p.status == PlaylistStatus.active).firstOrNull ??
        playlists.firstOrNull;
    final t = Theme.of(context).textTheme;

    return MenuAnchor(
      alignmentOffset: const Offset(-120, 8),
      menuChildren: [
        if (playlists.length > 1) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text('PLAYLIST', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.textMuted)),
          ),
          for (final p in playlists)
            MenuItemButton(
              onPressed: () => ref.read(activePlaylistProvider.notifier).select(p.id),
              leadingIcon: Icon(p.id == active?.id ? Icons.radio_button_checked : Icons.radio_button_off, size: 18),
              child: Text(p.name),
            ),
          const Divider(),
        ],
        MenuItemButton(
          onPressed: () => context.push('/settings'),
          leadingIcon: const Icon(Icons.settings_outlined, size: 18),
          child: const Text('Settings & playlists'),
        ),
        MenuItemButton(
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          leadingIcon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
          child: const Text('Sign out'),
        ),
      ],
      builder: (context, controller, _) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary,
              child: Text(email.isEmpty ? '?' : email[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            if (context.isExpanded) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(email.split('@').first, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(active?.name ?? 'No playlist', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textMuted),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Search, what's-new and settings actions for phone headers (the top bar
/// covers these on wide screens).
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isWide) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search_rounded)),
      const WhatsNewButton(),
      IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
    ]);
  }
}
