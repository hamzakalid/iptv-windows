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
import '../../widgets/nocturne.dart';
import '../player/player_screen.dart';

enum LibraryTab { list, history }

enum _Kind { all, movie, series, live }

/// History rows hidden for this session. The backend has no endpoint to
/// delete watch events, so "Remove from history" is local only.
final _hiddenHistoryProvider = NotifierProvider<_HiddenHistory, Set<String>>(_HiddenHistory.new);

class _HiddenHistory extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void hide(String key) => state = {...state, key};
}

String _eventKey(WatchEvent e) => '${e.contentId}|${e.episodeId ?? ''}';

bool _matches(_Kind k, MediaKind kind) => switch (k) {
      _Kind.all => true,
      _Kind.movie => kind == MediaKind.movie,
      _Kind.series => kind == MediaKind.series,
      _Kind.live => kind == MediaKind.channel,
    };

/// My List (saved titles + favourite channels) and watch History.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryTab _tab = LibraryTab.list;
  String? _routeTab;
  _Kind _kind = _Kind.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Home deep-links to ?tab=history; follow it when it changes.
    final tab = GoRouterState.of(context).uri.queryParameters['tab'];
    if (tab != _routeTab) {
      _routeTab = tab;
      _tab = tab == 'history' ? LibraryTab.history : LibraryTab.list;
    }
  }

  void _setTab(LibraryTab t) {
    setState(() => _tab = t);
    // Keep the URL in sync so a later deep link to the same tab still applies.
    context.go('/library?tab=${t == LibraryTab.history ? 'history' : 'list'}');
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final pad = context.pagePadding;
    final favs = ref.watch(favoritesProvider).value ?? const <Favorite>[];
    final saved = favs.where((f) => f.item != null && f.kind != MediaKind.channel).length;
    final hidden = ref.watch(_hiddenHistoryProvider);
    final history = (ref.watch(historyProvider).value ?? const <WatchEvent>[])
        .where((e) => e.item != null && !hidden.contains(_eventKey(e)))
        .toList();

    final tabs = Seg<LibraryTab>(
      options: const [
        SegOption(LibraryTab.list, 'My List', icon: Ph.bookmarkSimple),
        SegOption(LibraryTab.history, 'History', icon: Ph.clockCounterClockwise),
      ],
      value: _tab,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onChanged: _setTab,
    );
    final kinds = Seg<_Kind>(
      options: const [
        SegOption(_Kind.all, 'All'),
        SegOption(_Kind.movie, 'Movies'),
        SegOption(_Kind.series, 'Series'),
        SegOption(_Kind.live, 'Live'),
      ],
      value: _kind,
      onChanged: (k) => setState(() => _kind = k),
    );
    final title = PageTitle('Library', caption: '$saved saved · ${history.length} in history');

    final header = Padding(
      padding: EdgeInsets.fromLTRB(pad, 20, pad, 18),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              tabs,
              const SizedBox(width: 12),
              kinds,
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: title), const HeaderActions()]),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 10, children: [tabs, kinds]),
            ]),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _tab == LibraryTab.list
              ? ref.refresh(favoritesProvider.future)
              : ref.refresh(historyProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [header, ...(_tab == LibraryTab.list ? _myList(favs) : _historyList(history))],
          ),
        ),
      ),
    );
  }

  List<Widget> _myList(List<Favorite> favs) {
    final pad = context.pagePadding;
    final async = ref.watch(favoritesProvider);
    if (async.isLoading && !async.hasValue) return const [_Loading()];
    if (async.hasError && !async.hasValue) {
      return [ErrorView(error: async.error!, onRetry: () => ref.invalidate(favoritesProvider))];
    }
    final channels = favs.where((f) => f.kind == MediaKind.channel && f.item != null).map((f) => f.item!).toList();
    final items = _kind == _Kind.live
        ? const <MediaItem>[]
        : favs
            .where((f) => f.item != null && f.kind != MediaKind.channel && _matches(_kind, f.kind))
            .map((f) => f.item!)
            .toList();
    final showChannels = (_kind == _Kind.all || _kind == _Kind.live) && channels.isNotEmpty;
    return [
      if (showChannels) ...[
        Overline('Favourite channels', padding: EdgeInsets.fromLTRB(pad, 0, pad, 8)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 22),
          child: Row(children: [
            for (final (i, c) in channels.indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              ChannelChip(item: c),
            ],
          ]),
        ),
      ],
      if (_kind != _Kind.live && items.isEmpty)
        _MutedNote('Nothing saved here yet. Use the bookmark on any poster to add it.')
      else if (_kind == _Kind.live && channels.isEmpty)
        _MutedNote('No favourite channels yet. Star a channel in Live TV to pin it here.'),
      if (items.isNotEmpty)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: _AutoGrid(
            minWidth: context.isWide ? 150 : 110,
            gapX: 14,
            gapY: 18,
            children: [for (final m in items) PosterCard(item: m)],
          ),
        ),
    ];
  }

  List<Widget> _historyList(List<WatchEvent> all) {
    final async = ref.watch(historyProvider);
    if (async.isLoading && !async.hasValue) return const [_Loading()];
    final rows = all.where((e) => _matches(_kind, e.kind)).toList();
    if (rows.isEmpty) {
      return const [_MutedNote('Nothing watched here yet. Everything you play shows up here so you can pick it back up.')];
    }
    return [
      Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.isWide ? 16 : 8),
            child: Column(children: [
              for (final (i, e) in rows.indexed) ...[
                if (i > 0) const SizedBox(height: 2),
                _HistoryRow(
                  key: ValueKey(_eventKey(e)),
                  event: e,
                  onRemove: () {
                    ref.read(_hiddenHistoryProvider.notifier).hide(_eventKey(e));
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Hidden from history for this session.')));
                  },
                ),
              ],
            ]),
          ),
        ),
      ),
    ];
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
}

class _MutedNote extends StatelessWidget {
  const _MutedNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(context.pagePadding),
        child: Text(text, style: TextStyle(color: AppColors.muted)),
      );
}

/// "Today · 17:40", "Yesterday · 22:10", "Sat · 21:15", "12 Sep · 21:15".
String _whenLabel(DateTime? t) {
  if (t == null) return '';
  final local = t.toLocal();
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(local.year, local.month, local.day)).inDays;
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final day = switch (days) {
    <= 0 => 'Today',
    1 => 'Yesterday',
    < 7 => wd[local.weekday - 1],
    _ => '${local.day} ${mo[local.month - 1]}',
  };
  return '$day · ${formatClock(local)}';
}

/// "1h 02m" / "45m".
String _hm(int secs) {
  final min = (secs / 60).round();
  return '${min >= 60 ? '${min ~/ 60}h ' : ''}${(min % 60).toString().padLeft(2, '0')}m';
}

/// One History row: 16:9 thumb with progress, title + kind tag, what/when,
/// then Resume / Watch again / Watch live and a remove button.
class _HistoryRow extends StatefulWidget {
  const _HistoryRow({super.key, required this.event, required this.onRemove});
  final WatchEvent event;
  final VoidCallback onRemove;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hover = false;

  WatchEvent get e => widget.event;

  void _resume() {
    final item = e.item!;
    switch (e.kind) {
      case MediaKind.movie:
        PlayerScreen.open(context, PlayerArgs.movie(item, startAt: e.completed ? 0 : e.positionSecs));
      case MediaKind.series:
        // Episode URLs live on the series detail; open it and let the user pick.
        openItem(context, item);
      case MediaKind.channel:
        PlayerScreen.open(context, PlayerArgs.channel(item));
    }
  }

  String _sub() {
    final item = e.item!;
    if (e.kind == MediaKind.channel) {
      // The programme that was on when it was watched, if the cached EPG covers it.
      final t = e.watchedAt;
      final epg = cachedEpg(item);
      final entries = [?epg?.now, ?epg?.next, ...?epg?.upcoming];
      final prog = t == null
          ? null
          : entries
              .where((p) => p.start != null && p.end != null && !t.isBefore(p.start!) && t.isBefore(p.end!))
              .firstOrNull;
      return prog != null ? 'Watched ${prog.title}' : (item.group.isEmpty ? 'Live TV' : item.group);
    }
    if (e.completed) return 'Finished';
    if (e.kind == MediaKind.series) {
      if (e.season == null) return 'Started';
      return 'S${e.season} · E${e.episode ?? '?'}${e.episodeTitle != null ? ' — ${e.episodeTitle}' : ''}';
    }
    final dur = e.durationSecs;
    final pct = '${e.progressPct.round()}%';
    return dur != null && dur > e.positionSecs ? '$pct · ${_hm(dur - e.positionSecs)} left' : pct;
  }

  @override
  Widget build(BuildContext context) {
    final item = e.item!;
    final live = e.kind == MediaKind.channel;
    final wide = context.isWide;
    final pct = e.completed ? 1.0 : (live ? 0.0 : e.progressPct / 100);
    final (action, icon) = live
        ? ('Watch live', Ph.broadcast)
        : e.completed
            ? ('Watch again', Ph.arrowCounterClockwise)
            : ('Resume', PhF.play);
    final kind = switch (e.kind) {
      MediaKind.movie => 'Movie',
      MediaKind.series => 'Series',
      MediaKind.channel => 'Live',
    };

    final thumb = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _resume,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: SizedBox(
            width: wide ? 160 : 112,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                if (live)
                  ArtPlaceholder(
                    label: item.name,
                    fontSize: 12,
                    child: item.logo == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                            child: NetImage(item.logo,
                                fit: BoxFit.contain, label: item.name, fontSize: 12, memCacheWidth: 200),
                          ),
                  )
                else
                  NetImage(item.backdrop, label: item.name, fontSize: 12, memCacheWidth: 320),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ProgressLine(pct, height: 3, track: AppColors.text.withValues(alpha: 0.12)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _hover ? AppColors.text.withValues(alpha: 0.04) : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(children: [
          thumb,
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(
                  child: Text(live ? channelLabel(item) : item.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 8),
                NocTag(kind),
                if (e.completed && !live) ...[
                  const SizedBox(width: 8),
                  const Icon(Ph.check, size: 12, color: AppColors.a300),
                  const SizedBox(width: 4),
                  const Text('Watched', style: TextStyle(fontSize: 12, color: AppColors.a300)),
                ],
              ]),
              const SizedBox(height: 2),
              Text(_sub(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.n300)),
              const SizedBox(height: 2),
              Text(_whenLabel(e.watchedAt),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.n600, fontFeatures: NocText.tabular)),
            ]),
          ),
          const SizedBox(width: 14),
          wide
              ? NocButton.primary(label: action, icon: icon, height: 34, onPressed: _resume)
              : NocIconButton(icon: icon, color: AppColors.accent, tooltip: action, onPressed: _resume),
          const SizedBox(width: 6),
          NocIconButton(
            icon: Ph.x,
            iconSize: 16,
            color: AppColors.n500,
            tooltip: 'Remove from history',
            onPressed: widget.onRemove,
          ),
        ]),
      ),
    );
  }
}

/// CSS `repeat(auto-fill, minmax(min, 1fr))` with row/column gaps.
class _AutoGrid extends StatelessWidget {
  const _AutoGrid({required this.minWidth, required this.gapX, required this.gapY, required this.children});
  final double minWidth;
  final double gapX;
  final double gapY;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = ((c.maxWidth + gapX) / (minWidth + gapX)).floor().clamp(1, 99);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var r = 0; r * cols < children.length; r++) ...[
            if (r > 0) SizedBox(height: gapY),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < cols; i++) ...[
                if (i > 0) SizedBox(width: gapX),
                Expanded(child: r * cols + i < children.length ? children[r * cols + i] : const SizedBox.shrink()),
              ],
            ]),
          ],
        ]);
      });
}
