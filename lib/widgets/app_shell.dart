import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/account.dart';
import '../state/providers.dart';
import 'common.dart';
import 'media_cards.dart';
import 'nocturne.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon, this.branch);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int branch;
}

/// Branch indexes, matching the order in router.dart.
abstract final class Branch {
  static const home = 0;
  static const movies = 1;
  static const series = 2;
  static const live = 3;
  static const library = 4;
  static const search = 5;
}

const _railDests = [
  _Dest('Home', Ph.house, PhF.house, Branch.home),
  _Dest('Movies', Ph.filmStrip, PhF.filmStrip, Branch.movies),
  _Dest('Series', Ph.televisionSimple, PhF.televisionSimple, Branch.series),
  _Dest('Live TV', Ph.broadcast, PhF.broadcast, Branch.live),
  _Dest('Library', Ph.bookmarkSimple, PhF.bookmarkSimple, Branch.library),
  _Dest('Search (/)', Ph.magnifyingGlass, PhF.magnifyingGlass, Branch.search),
];

const _mobileDests = [
  _Dest('Home', Ph.house, PhF.house, Branch.home),
  _Dest('Movies', Ph.filmStrip, PhF.filmStrip, Branch.movies),
  _Dest('Series', Ph.televisionSimple, PhF.televisionSimple, Branch.series),
  _Dest('Live TV', Ph.broadcast, PhF.broadcast, Branch.live),
  _Dest('Library', Ph.bookmarkSimple, PhF.bookmarkSimple, Branch.library),
];

/// Opens the Search tab and focuses its field (also bound to `/`).
void goSearch(BuildContext context, WidgetRef ref) {
  context.go('/search');
  ref.read(searchFocusRequestProvider.notifier).request();
}

/// Slim 60px icon rail on tablets and desktop; bottom navigation on phones.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// `/` anywhere outside a text field jumps to Search.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.character != '/') return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        (focused.widget is EditableText || focused.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    goSearch(context, ref);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    if (context.isWide) {
      return Scaffold(
        body: Row(children: [
          _Rail(shell: shell),
          Expanded(child: shell),
        ]),
      );
    }
    final index = shell.currentIndex.clamp(0, _mobileDests.length - 1);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex == Branch.search ? 0 : index,
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
// Rail
// ---------------------------------------------------------------------------

class _Rail extends ConsumerWidget {
  const _Rail({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 60,
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      decoration: BoxDecoration(
        color: AppColors.rail,
        border: Border(right: BorderSide(color: AppColors.text.withValues(alpha: 0.06))),
      ),
      child: Column(children: [
        Tooltip(
          message: appName,
          child: Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: const Icon(PhF.play, size: 16, color: AppColors.accent),
          ),
        ),
        for (final d in _railDests)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _RailButton(
              dest: d,
              selected: shell.currentIndex == d.branch,
              onTap: () {
                if (d.branch == Branch.search) {
                  goSearch(context, ref);
                } else {
                  shell.goBranch(d.branch, initialLocation: d.branch == shell.currentIndex);
                }
              },
            ),
          ),
        const Spacer(),
        _RailButton(
          dest: const _Dest('Settings', Ph.gearSix, PhF.gearSix, -1),
          selected: false,
          onTap: () => context.push('/settings'),
        ),
        const SizedBox(height: 6),
        const _ProfileMenu(),
      ]),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.dest, required this.selected, required this.onTap});
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: dest.label,
        preferBelow: false,
        verticalOffset: 0,
        margin: const EdgeInsets.only(left: 56),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: Tappable(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(selected ? dest.selectedIcon : dest.icon,
                      size: 21, color: selected ? AppColors.accent : AppColors.n500),
                ),
              ),
            ),
            if (selected)
              Positioned(
                left: -8,
                top: 10,
                bottom: 10,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ]),
        ),
      );
}

/// Avatar at the bottom of the rail: switch playlist, settings, sign out.
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

    return MenuAnchor(
      alignmentOffset: const Offset(52, -40),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(email.split('@').first, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(active?.name ?? 'No playlist', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        if (playlists.length > 1) ...[
          const Overline('Playlist', padding: EdgeInsets.fromLTRB(12, 4, 12, 4)),
          for (final p in playlists)
            MenuItemButton(
              onPressed: () => ref.read(activePlaylistProvider.notifier).select(p.id),
              leadingIcon: Icon(p.id == active?.id ? PhF.radioButton : Ph.circle,
                  size: 16, color: p.id == active?.id ? AppColors.accent : AppColors.n500),
              child: Text(p.name),
            ),
          const Divider(),
        ],
        MenuItemButton(
          onPressed: () => context.push('/settings'),
          leadingIcon: const Icon(Ph.gearSix, size: 16),
          child: const Text('Settings & playlists'),
        ),
        MenuItemButton(
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          leadingIcon: const Icon(Ph.signOut, size: 16, color: AppColors.danger),
          child: const Text('Sign out'),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: '${email.split('@').first} · ${active?.name ?? 'No playlist'}',
        child: Tappable(
          radius: 15,
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.a800, shape: BoxShape.circle),
            child: Text(email.isEmpty ? '?' : email[0].toUpperCase(),
                style: const TextStyle(color: AppColors.a100, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared header pieces
// ---------------------------------------------------------------------------

const searchScopes = ['All', 'Movies', 'Series', 'Live TV'];

/// Bell with an accent dot; opens a popover of titles added since the last
/// visit with "Mark all seen".
class WhatsNewButton extends ConsumerWidget {
  const WhatsNewButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(whatsNewProvider);
    return MenuAnchor(
      alignmentOffset: const Offset(-284, 8),
      style: MenuStyle(padding: WidgetStateProperty.all(const EdgeInsets.fromLTRB(8, 12, 8, 8))),
      menuChildren: [
        SizedBox(
          width: 304,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 0, 6),
            child: Row(children: [
              Expanded(
                child: Text(
                  items.isEmpty ? 'Nothing new since your last visit' : '${items.length} new since your last visit',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (items.isNotEmpty)
                NocButton.ghost(
                  label: 'Mark all seen',
                  fontSize: 12.5,
                  onPressed: () => ref.read(lastSeenProvider.notifier).markSeen(),
                ),
            ]),
          ),
        ),
        for (final m in items.take(8))
          MenuItemButton(
            onPressed: () => openItem(context, m),
            leadingIcon: SizedBox(
              width: 30,
              height: 44,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: NetImage(m.logo, label: m.name, fontSize: 10),
              ),
            ),
            child: SizedBox(
              width: 240,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                Text('${m.kind.label} · added ${timeAgo(m.createdAt)}',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ]),
            ),
          ),
      ],
      builder: (context, controller, _) => NocIconButton(
        icon: Ph.bell,
        tooltip: 'What’s new',
        badge: items.isNotEmpty,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Search, what's-new and settings actions for phone headers (the rail
/// covers these on wide screens).
class HeaderActions extends ConsumerWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (context.isWide) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      NocIconButton(icon: Ph.magnifyingGlass, tooltip: 'Search', onPressed: () => goSearch(context, ref)),
      const WhatsNewButton(),
      NocIconButton(icon: Ph.gearSix, tooltip: 'Settings', onPressed: () => context.push('/settings')),
    ]);
  }
}
