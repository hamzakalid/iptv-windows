import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/paged_grid.dart';
import '../player/player_screen.dart';

enum LibraryTab { list, history }

/// My List (saved titles and favourite channels) and watch History.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryTab _tab = LibraryTab.list;
  String? _routeTab;

  /// null = all kinds.
  MediaKind? _kind;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "History" links deep-link to ?tab=history; follow it when it changes.
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
    final saved = ref.watch(favoritesProvider).value?.length ?? 0;
    final history = ref.watch(historyProvider).value?.where((e) => e.item != null).length ?? 0;

    final tabs = SegmentedControl<LibraryTab>(
      segments: const [
        Segment(LibraryTab.list, 'My List', icon: PhosphorIconsRegular.bookmarkSimple),
        Segment(LibraryTab.history, 'History', icon: PhosphorIconsRegular.clockCounterClockwise),
      ],
      selected: _tab,
      onChanged: (t) => setState(() => _tab = t),
    );
    final kinds = SegmentedControl<MediaKind?>(
      segments: const [
        Segment(null, 'All'),
        Segment(MediaKind.movie, 'Movies'),
        Segment(MediaKind.series, 'Series'),
        Segment(MediaKind.channel, 'Live'),
      ],
      selected: _kind,
      onChanged: (k) => setState(() => _kind = k),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, wide ? 20 : 12, wide ? pad : 8, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Library', style: wide ? AppText.h3 : AppText.h4),
                    const SizedBox(height: 4),
                    Text('$saved saved · $history in history', style: AppText.meta),
                  ]),
                ),
                if (wide) ...[tabs, const SizedBox(width: 12), kinds] else const HeaderActions(),
              ]),
              if (!wide) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [tabs, const SizedBox(width: 8), kinds]),
                ),
              ],
            ]),
          ),
          Expanded(child: _tab == LibraryTab.list ? _MyList(kind: _kind) : _History(kind: _kind)),
        ]),
      ),
    );
  }
}

class _MyList extends ConsumerWidget {
  const _MyList({required this.kind});
  final MediaKind? kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesProvider);
    final pad = context.pagePadding;
    return async.when(
      loading: () => const Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(favoritesProvider)),
      data: (favs) {
        final channels = kind == null || kind == MediaKind.channel
            ? favs.where((f) => f.kind == MediaKind.channel).map((f) => f.item!).toList()
            : const <MediaItem>[];
        final titles = kind == MediaKind.channel
            ? const <MediaItem>[]
            : favs.where((f) => f.kind != MediaKind.channel && (kind == null || f.kind == kind)).map((f) => f.item!).toList();

        return RefreshIndicator(
          onRefresh: () => ref.refresh(favoritesProvider.future),
          child: CustomScrollView(slivers: [
            if (channels.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Eyebrow('Favourite channels', padding: EdgeInsets.fromLTRB(pad, 0, pad, 8)),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      itemCount: channels.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ChannelChip(item: channels[i]),
                    ),
                  ),
                  const SizedBox(height: 22),
                ]),
              ),
            if (titles.isEmpty && kind != MediaKind.channel)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                  child: const Text('Nothing saved here yet. Use the bookmark on any poster to add it.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else if (kind == MediaKind.channel && channels.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                  child: const Text('No favourite channels yet. Use the star on any channel to add it.',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
                sliver: MediaGridSliver(items: titles, kind: MediaKind.movie),
              ),
          ]),
        );
      },
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.kind});
  final MediaKind? kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);
    return async.when(
      loading: () => const Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(historyProvider)),
      data: (events) {
        final rows = events.where((e) => e.item != null && (kind == null || e.kind == kind)).toList();
        if (rows.isEmpty) {
          return Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(context.pagePadding, 8, context.pagePadding, 24),
              child: const Text('Nothing watched yet. Everything you play shows up here so you can pick it back up.',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(historyProvider.future),
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(context.pagePadding - 8, 0, context.pagePadding, 32),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (_, i) => Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: _HistoryRow(event: rows[i])),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event});
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
    final live = event.kind == MediaKind.channel;
    final done = event.completed;
    final left = event.durationSecs == null ? null : event.durationSecs! - event.positionSecs;
    final sub = live
        ? (item.group.isEmpty ? 'Live channel' : item.group)
        : done
            ? 'Finished'
            : event.episodeLabel.isNotEmpty
                ? event.episodeLabel
                : [
                    '${event.progressPct.round()}%',
                    if (left != null && left > 60) '${formatDuration(left)} left',
                  ].join(' · ');
    final (action, icon) = live
        ? ('Watch live', PhosphorIconsRegular.broadcast)
        : done
            ? ('Watch again', PhosphorIconsRegular.arrowCounterClockwise)
            : ('Resume', PhosphorIconsFill.play);
    final wide = context.isWide;

    return Hoverable(
      onTap: () => openItem(context, item),
      hoverColor: AppColors.wash(0.04),
      ring: Shadows.ringFlat,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          SizedBox(
            width: wide ? 160 : 112,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: Stack(fit: StackFit.expand, children: [
                  live
                      ? Container(
                          color: AppColors.neutral900,
                          padding: const EdgeInsets.all(14),
                          child: NetImage(item.logo, fit: BoxFit.contain, label: item.name, labelSize: 12, memCacheWidth: 240),
                        )
                      : NetImage(item.backdrop, label: item.name, labelSize: 12, memCacheWidth: 320),
                  if (!live && (done || event.progressPct > 0)) ArtProgress(done ? 1 : event.progressPct / 100),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(
                  child: Text(live ? channelLabel(item) : item.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                Tag(event.kind.label),
                if (done) ...[
                  const SizedBox(width: 8),
                  const Icon(PhosphorIconsRegular.check, size: 13, color: AppColors.accent300),
                  const SizedBox(width: 4),
                  const Text('Watched', style: TextStyle(fontSize: 12, color: AppColors.accent300)),
                ],
              ]),
              const SizedBox(height: 2),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.neutral300)),
              const SizedBox(height: 2),
              Text(formatWhen(event.watchedAt), style: const TextStyle(fontSize: 11.5, color: AppColors.neutral600)),
            ]),
          ),
          const SizedBox(width: 12),
          if (wide)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 34)),
              onPressed: () => _resume(context),
              icon: Icon(icon),
              label: Text(action),
            )
          else
            IconButton(tooltip: action, onPressed: () => _resume(context), icon: Icon(icon, color: AppColors.accent)),
        ]),
      ),
    );
  }
}
