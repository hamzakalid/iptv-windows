import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../models/account.dart';
import '../state/providers.dart';
import 'common.dart';
import 'media_cards.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// One per shell branch, in branch order.
const _dests = [
  _Dest('Home', PhosphorIconsRegular.house, PhosphorIconsFill.house),
  _Dest('Movies', PhosphorIconsRegular.filmStrip, PhosphorIconsFill.filmStrip),
  _Dest('Series', PhosphorIconsRegular.televisionSimple, PhosphorIconsFill.televisionSimple),
  _Dest('Live TV', PhosphorIconsRegular.broadcast, PhosphorIconsFill.broadcast),
  _Dest('Library', PhosphorIconsRegular.bookmarkSimple, PhosphorIconsFill.bookmarkSimple),
  _Dest('Search', PhosphorIconsRegular.magnifyingGlass, PhosphorIconsFill.magnifyingGlass),
];

const searchBranch = 5;

/// Focus for the search field, so "/" can jump straight into it.
final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'search');
  ref.onDispose(node.dispose);
  return node;
});

/// Switches branch; landing on Search puts the cursor in its field.
void _goBranch(WidgetRef ref, StatefulNavigationShell shell, int i) {
  shell.goBranch(i, initialLocation: i == shell.currentIndex);
  if (i == searchBranch) {
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(searchFocusProvider).requestFocus());
  }
}

/// Icon rail on tablets and desktop; bottom navigation on phones.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (context.isWide) {
      return Scaffold(
        body: Row(children: [
          _Rail(shell: shell),
          Expanded(child: shell),
        ]),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.wash(0.06)))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => _goBranch(ref, shell, i),
          destinations: [
            for (final d in _dests)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
          ],
        ),
      ),
    );
  }
}

/// App-wide keys outside the player: "/" jumps to search, Esc leaves a
/// detail page. Sits above the navigator so every route bubbles up to it.
class AppKeys extends ConsumerWidget {
  const AppKeys({super.key, required this.router, required this.child});
  final GoRouter router;
  final Widget child;

  static bool get _editing =>
      FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final path = router.state.uri.path;
          if (path == '/player' || path == '/login') return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_editing) {
              FocusManager.instance.primaryFocus?.unfocus();
              return KeyEventResult.handled;
            }
            if (router.canPop()) {
              router.pop();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
          if (event.character == '/' && !_editing) {
            router.go('/search');
            WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(searchFocusProvider).requestFocus());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: child,
      );
}

// ---------------------------------------------------------------------------
// Rail
// ---------------------------------------------------------------------------

class _Rail extends ConsumerWidget {
  const _Rail({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        width: 60,
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
        decoration: BoxDecoration(
          color: AppColors.rail,
          border: Border(right: BorderSide(color: AppColors.wash(0.06))),
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
              child: const Icon(PhosphorIconsFill.play, size: 16, color: AppColors.accent),
            ),
          ),
          for (var i = 0; i < _dests.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _RailButton(
                dest: _dests[i],
                tooltip: i == searchBranch ? 'Search (/)' : _dests[i].label,
                selected: shell.currentIndex == i,
                onTap: () => _goBranch(ref, shell, i),
              ),
            ),
          const Spacer(),
          _RailButton(
            dest: const _Dest('Settings', PhosphorIconsRegular.gearSix, PhosphorIconsFill.gearSix),
            tooltip: 'Settings',
            selected: false,
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 6),
          const ProfileMenu(),
        ]),
      );
}

class _RailButton extends StatefulWidget {
  const _RailButton({required this.dest, required this.tooltip, required this.selected, required this.onTap});
  final _Dest dest;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return Tooltip(
      message: widget.tooltip,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap();
            return null;
          }),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 60,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: sel ? AppColors.tint(0.12) : (_hover ? AppColors.wash(0.07) : Colors.transparent),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: _focus ? Border.all(color: AppColors.accent, width: 2) : null,
                ),
                child: Icon(sel ? widget.dest.selectedIcon : widget.dest.icon,
                    size: 21, color: sel ? AppColors.accent : AppColors.neutral500),
              ),
              Positioned(
                left: 0,
                top: 10,
                bottom: 10,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: sel ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile + what's new
// ---------------------------------------------------------------------------

/// Avatar that opens the account menu: playlist switcher, settings, sign out.
class ProfileMenu extends ConsumerWidget {
  const ProfileMenu({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(sessionProvider).value?.user?.email ?? '';
    final playlists = ref.watch(playlistsProvider).value ?? const <Playlist>[];
    final activeId = ref.watch(activePlaylistProvider);
    final active = playlists.where((p) => p.id == activeId).firstOrNull ??
        playlists.where((p) => p.status == PlaylistStatus.active).firstOrNull ??
        playlists.firstOrNull;

    return MenuAnchor(
      alignmentOffset: const Offset(52, -44),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Row(children: [
            Avatar(email, size: 32),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(email.split('@').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title),
                Text(active?.name ?? 'No playlist', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
              ]),
            ),
          ]),
        ),
        if (playlists.length > 1) ...[
          const Eyebrow('Playlist', padding: EdgeInsets.fromLTRB(10, 6, 10, 4)),
          for (final p in playlists)
            MenuItemButton(
              onPressed: () => ref.read(activePlaylistProvider.notifier).select(p.id),
              leadingIcon: Icon(p.id == active?.id ? PhosphorIconsRegular.check : PhosphorIconsRegular.dotOutline,
                  color: p.id == active?.id ? AppColors.accent : AppColors.neutral600),
              child: Text(p.name, style: TextStyle(color: p.id == active?.id ? AppColors.accent : null)),
            ),
        ],
        const Divider(height: 13),
        MenuItemButton(
          onPressed: () => context.push('/settings'),
          leadingIcon: const Icon(PhosphorIconsRegular.gearSix),
          child: const Text('Settings & playlists'),
        ),
        MenuItemButton(
          onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          leadingIcon: const Icon(PhosphorIconsRegular.signOut, color: AppColors.danger),
          child: const Text('Sign out'),
        ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: '${email.split('@').first} · ${active?.name ?? 'No playlist'}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            child: Avatar(email, size: size),
          ),
        ),
      ),
    );
  }
}

/// Bell with an accent dot while there are titles added since the last
/// visit; opens a popover listing them.
class WhatsNewButton extends ConsumerWidget {
  const WhatsNewButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(whatsNewProvider);
    return MenuAnchor(
      alignmentOffset: const Offset(-284, 8),
      style: const MenuStyle(padding: WidgetStatePropertyAll(EdgeInsets.fromLTRB(8, 12, 8, 8))),
      menuChildren: [
        SizedBox(
          width: 304,
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Text('Nothing new since your last visit', style: TextStyle(color: AppColors.textMuted)),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 0, 6),
                    child: Row(children: [
                      Expanded(
                        child: Text('${items.length} new since your last visit',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      TextButton(
                        onPressed: () => ref.read(lastSeenProvider.notifier).markSeen(),
                        style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 12.5)),
                        child: const Text('Mark all seen'),
                      ),
                    ]),
                  ),
                  for (final m in items.take(8))
                    MenuItemButton(
                      onPressed: () => openItem(context, m),
                      style: const ButtonStyle(
                        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                      ),
                      leadingIcon: SizedBox(
                        width: 30,
                        height: 44,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(Radii.sm),
                          child: NetImage(m.logo, label: m.name, labelSize: 10, memCacheWidth: 90),
                        ),
                      ),
                      child: SizedBox(
                        width: 236,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          Text('${m.kind.label} · added ${timeAgo(m.createdAt)}',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                        ]),
                      ),
                    ),
                ]),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: "What's new",
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: Stack(clipBehavior: Clip.none, children: [
          const Icon(PhosphorIconsRegular.bell),
          if (items.isNotEmpty)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              ),
            ),
        ]),
      ),
    );
  }
}

/// What's-new and account actions for phone headers (the rail carries these
/// on wide screens).
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isWide) return const SizedBox.shrink();
    return const Row(mainAxisSize: MainAxisSize.min, children: [
      WhatsNewButton(),
      SizedBox(width: 6),
      ProfileMenu(size: 28),
      SizedBox(width: 8),
    ]);
  }
}
