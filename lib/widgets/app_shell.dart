import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../state/providers.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _dests = [
  _Dest('Home', Icons.home_outlined, Icons.home_rounded),
  _Dest('Movies', Icons.movie_outlined, Icons.movie_rounded),
  _Dest('Series', Icons.video_library_outlined, Icons.video_library_rounded),
  _Dest('Live TV', Icons.live_tv_outlined, Icons.live_tv_rounded),
  _Dest('My List', Icons.bookmark_border_rounded, Icons.bookmark_rounded),
];

/// Bottom navigation on phones, a sidebar on tablets and desktop.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    if (context.isWide) {
      return Scaffold(
        body: Row(children: [
          _Sidebar(index: shell.currentIndex, onSelect: _go),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ]),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _dests)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(sessionProvider).value?.user?.email ?? '';
    final expanded = context.width >= 1200;
    final t = Theme.of(context).textTheme;

    Widget item(IconData icon, String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Tooltip(
          message: expanded ? '' : label,
          child: Material(
            color: selected ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0, vertical: 12),
                child: Row(
                  mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: selected ? AppColors.text : AppColors.textMuted, size: 22),
                    if (expanded) ...[
                      const SizedBox(width: 14),
                      Text(label,
                          style: TextStyle(
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

    return Container(
      width: expanded ? 232 : 84,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              ),
              if (expanded) ...[const SizedBox(width: 12), Text(appName, style: t.titleLarge)],
            ],
          ),
          const SizedBox(height: 28),
          item(Icons.search_rounded, 'Search', false, () => context.push('/search')),
          const SizedBox(height: 8),
          for (var i = 0; i < _dests.length; i++)
            item(i == index ? _dests[i].selectedIcon : _dests[i].icon, _dests[i].label, i == index, () => onSelect(i)),
          const Spacer(),
          item(Icons.settings_outlined, 'Settings', false, () => context.push('/settings')),
          if (expanded && email.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(email[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Search + settings actions shown in page headers on phones (the sidebar
/// covers them on wide screens).
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.isWide) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search_rounded)),
      IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings_outlined)),
    ]);
  }
}
