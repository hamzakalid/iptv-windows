import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../player/player_screen.dart';

enum LibraryTab { list, history }

/// My List (favourites) and watch History, switched with a segmented control.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryTab _tab = LibraryTab.list;
  String? _routeTab;
  MediaKind? _filter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The sidebar deep-links to ?tab=history; follow it when it changes.
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    if (tab != _routeTab) {
      _routeTab = tab;
      _tab = tab == 'history' ? LibraryTab.history : LibraryTab.list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final wide = context.isWide;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 16, pad - (wide ? 0 : 8), 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Library', style: Theme.of(context).textTheme.headlineMedium)),
                if (wide) _tabs(),
                const HeaderActions(),
              ]),
              if (!wide) Padding(padding: const EdgeInsets.only(top: 12), child: _tabs()),
            ]),
          ),
          Expanded(child: _tab == LibraryTab.list ? _myList() : const _History()),
        ]),
      ),
    );
  }

  Widget _tabs() => SegmentedButton<LibraryTab>(
        segments: const [
          ButtonSegment(value: LibraryTab.list, label: Text('My List'), icon: Icon(Icons.favorite_border_rounded, size: 16)),
          ButtonSegment(value: LibraryTab.history, label: Text('History'), icon: Icon(Icons.history_rounded, size: 16)),
        ],
        selected: {_tab},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _tab = s.first),
      );

  Widget _myList() {
    final async = ref.watch(favoritesProvider);
    final pad = context.pagePadding;
    final wide = context.isWide;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 6),
          children: [
            for (final k in <MediaKind?>[null, ...MediaKind.values])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Pill(
                  switch (k) {
                    null => 'All',
                    MediaKind.movie => 'Movies',
                    MediaKind.series => 'Series',
                    MediaKind.channel => 'Channels',
                  },
                  selected: _filter == k,
                  onTap: () => setState(() => _filter = k),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(favoritesProvider)),
          data: (favs) {
            final items = favs.where((f) => _filter == null || f.kind == _filter).map((f) => f.item!).toList();
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Your list is empty',
                message: 'Tap the heart on any movie or series to save it here for later.',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.refresh(favoritesProvider.future),
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: wide ? 186 : 130,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.5,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => items[i].kind == MediaKind.channel
                    ? Align(alignment: Alignment.topCenter, child: ChannelCard(item: items[i]))
                    : PosterCard(item: items[i]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _History extends ConsumerWidget {
  const _History();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(historyProvider)),
      data: (events) {
        final rows = events.where((e) => e.item != null).toList();
        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.history_rounded,
            title: 'Nothing watched yet',
            message: 'Everything you play shows up here so you can pick it back up.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(historyProvider.future),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, 24),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _HistoryTile(event: rows[i]),
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.event});
  final WatchEvent event;

  void _resume(BuildContext context) {
    final item = event.item!;
    switch (event.kind) {
      case MediaKind.movie:
        PlayerScreen.open(context, PlayerArgs.movie(item, startAt: event.completed ? 0 : event.positionSecs));
      case MediaKind.series:
        openItem(context, item);
      case MediaKind.channel:
        PlayerScreen.open(context, PlayerArgs.channel(item));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = event.item!;
    final t = Theme.of(context).textTheme;
    final isLive = event.kind == MediaKind.channel;
    final detail = [
      event.kind.label,
      if (event.episodeLabel.isNotEmpty) event.episodeLabel,
      if (!isLive && event.durationSecs != null && event.durationSecs! > 0)
        event.completed ? 'Watched' : '${formatDuration(event.positionSecs)} of ${formatDuration(event.durationSecs)}',
    ].join('  •  ');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => openItem(context, item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: isLive ? 96 : 60,
                height: isLive ? 60 : 88,
                child: NetImage(item.logo, label: item.name, fit: isLive ? BoxFit.contain : BoxFit.cover, memCacheWidth: 200),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                    child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (event.completed) const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                ]),
                const SizedBox(height: 3),
                Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 3),
                Text(timeAgo(event.watchedAt), style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
                if (!isLive && !event.completed && event.progressPct > 0) ...[
                  const SizedBox(height: 8),
                  ProgressBar(event.progressPct / 100, height: 3),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: event.completed ? 'Watch again' : 'Resume',
              style: IconButton.styleFrom(backgroundColor: AppColors.surfaceHigh),
              onPressed: () => _resume(context),
              icon: Icon(event.completed ? Icons.replay_rounded : Icons.play_arrow_rounded),
            ),
          ]),
        ),
      ),
    );
  }
}
