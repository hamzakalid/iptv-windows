import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Catalogue browser shared by Movies, Series and Live TV: a searchable,
/// category-filtered, sortable, infinitely scrolling grid.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key, required this.kind});
  final MediaKind kind;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  String? _group;
  String _query = '';
  ListFilter _filter = const ListFilter();
  bool _favouritesOnly = false;
  int? _total;
  final _search = TextEditingController();
  Timer? _debounce;
  bool _shuffling = false;

  bool get _live => widget.kind == MediaKind.channel;

  @override
  void initState() {
    super.initState();
    // Another screen may have asked for a pre-selected category.
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyIntent());
  }

  void _applyIntent() {
    final intent = ref.read(browseIntentProvider.notifier).take(widget.kind);
    if (intent != null && mounted) setState(() => _group = intent.group);
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {}); // clear button visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
  }

  String get _title => switch (widget.kind) {
        MediaKind.movie => 'Movies',
        MediaKind.series => 'Series',
        MediaKind.channel => 'Live TV',
      };

  List<SortOption> get _sorts => _live ? [SortOption.recent, SortOption.name] : SortOption.values;

  String _sortLabel(SortOption s) => _live && s == SortOption.recent ? 'Channel order' : s.label;

  void _cycleSort() {
    final i = _sorts.indexOf(_filter.sort);
    setState(() => _filter = _filter.copyWith(sort: _sorts[(i + 1) % _sorts.length]));
  }

  Future<void> _surprise() async {
    setState(() => _shuffling = true);
    try {
      final item = await ref.read(repositoryProvider).random(
            widget.kind,
            playlistId: ref.read(activePlaylistProvider),
            group: _group,
            filter: _filter,
          );
      if (!mounted) return;
      if (item == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing matches these filters')));
      } else {
        openItem(context, item);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _shuffling = false);
    }
  }

  void _select(String? g) => setState(() => _group = g);

  String _countLabel(HomeData? home) {
    final all = switch (widget.kind) {
      MediaKind.movie => home?.movieCount,
      MediaKind.series => home?.seriesCount,
      MediaKind.channel => home?.channelCount,
    };
    final noun = _live ? 'channels' : _title.toLowerCase();
    if (_live && _favouritesOnly) return 'Favourites';
    final shown = _total;
    final filtered = _group != null || _query.isNotEmpty || _filter.minRating != null;
    final parts = <String>[
      if (shown != null && all != null && filtered) '${formatCount(shown)} of ${formatCount(all)}'
      else if (all != null) '${formatCount(all)} $noun'
      else if (shown != null) '${formatCount(shown)} $noun',
      if (_group != null) _label(_group!),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(browseIntentProvider, (_, next) {
      if (next != null && next.kind == widget.kind) _applyIntent();
    });
    final playlistId = ref.watch(activePlaylistProvider);
    final repo = ref.watch(repositoryProvider);
    final cats = ref.watch(categoriesProvider(widget.kind)).value;
    final home = ref.watch(homeProvider).value;
    final wide = context.isWide;
    final pad = context.pagePadding;

    final controls = <Widget>[
      SizedBox(width: wide ? (_live ? 300 : 240) : double.infinity, child: _searchField()),
      if (_live)
        SegmentedControl<bool>(
          segments: const [
            Segment(false, 'All', icon: PhosphorIconsRegular.squaresFour),
            Segment(true, 'Favourites', icon: PhosphorIconsRegular.star),
          ],
          selected: _favouritesOnly,
          onChanged: (v) => setState(() => _favouritesOnly = v),
        )
      else
        SegmentedControl<double?>(
          segments: const [
            Segment(null, 'Any'),
            Segment(6.0, '6+', icon: PhosphorIconsFill.star),
            Segment(7.0, '7+', icon: PhosphorIconsFill.star),
            Segment(8.0, '8+', icon: PhosphorIconsFill.star),
          ],
          selected: _filter.minRating,
          onChanged: (v) => setState(() => _filter = _filter.copyWith(minRating: () => v)),
        ),
      if (!_favouritesOnly)
        OutlinedButton.icon(
          onPressed: _cycleSort,
          icon: const Icon(PhosphorIconsRegular.sortAscending),
          label: Text(_sortLabel(_filter.sort)),
        ),
      if (!_live)
        OutlinedButton.icon(
          onPressed: _shuffling ? null : _surprise,
          icon: const Icon(PhosphorIconsRegular.shuffle),
          label: const Text('Surprise me'),
        ),
    ];

    final header = Padding(
      padding: EdgeInsets.fromLTRB(pad, wide ? 20 : 12, wide ? pad : 8, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_title, style: wide ? AppText.h3 : AppText.h4),
              const SizedBox(height: 4),
              Text(_countLabel(home), style: AppText.meta),
            ]),
          ),
          if (wide) Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: controls)
          else const HeaderActions(),
        ]),
        if (!wide) ...[
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.only(right: 8), child: controls.first),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final c in controls.skip(1)) Padding(padding: const EdgeInsets.only(right: 8), child: c)]),
          ),
        ],
      ]),
    );

    final gridPadding = EdgeInsets.fromLTRB(wide ? 12 : pad, 4, pad, 32);
    final extras = _live
        ? _LiveHeader(
            showRecent: _query.isEmpty && !_favouritesOnly,
            title: _favouritesOnly ? 'Favourites' : (_group == null ? 'All channels' : _label(_group!)),
            count: _favouritesOnly ? null : _total,
            padding: gridPadding,
          )
        : null;
    final chips = wide || cats == null || _favouritesOnly
        ? null
        : _CategoryChips(cats: cats, selected: _group, onSelect: _select);

    final Widget grid;
    if (_live && _favouritesOnly) {
      grid = _FavouriteChannels(query: _query, group: _group, padding: gridPadding, header: extras);
    } else {
      grid = PagedMediaGrid(
        queryKey: (playlistId, _group, _query, _filter, repo),
        kind: widget.kind,
        padding: gridPadding,
        onTotal: (t) {
          if (t != _total) setState(() => _total = t);
        },
        emptyTitle: _query.isEmpty ? 'Nothing matches these filters.' : 'No ${_live ? 'channels' : _title.toLowerCase()} match "$_query".',
        header: chips == null && extras == null ? null : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [?chips, ?extras]),
        fetch: (offset) => repo.list(widget.kind,
            playlistId: playlistId, group: _group, q: _query, filter: _filter, offset: offset),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          Expanded(
            child: wide && cats != null
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _CategoryList(
                      title: _live ? 'Categories' : 'Genres',
                      cats: cats,
                      selected: _group,
                      onSelect: _select,
                    ),
                    Expanded(child: grid),
                  ])
                : grid,
          ),
        ]),
      ),
    );
  }

  Widget _searchField() => SizedBox(
        height: 36,
        child: TextField(
          controller: _search,
          onChanged: _onSearch,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: _live ? 'Search channels or programmes' : 'Search ${_title.toLowerCase()}',
            prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 16),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(PhosphorIconsRegular.x, size: 14),
                    onPressed: () {
                      _search.clear();
                      _onSearch('');
                    },
                  ),
          ),
        ),
      );
}

/// Recently watched channels plus the grid's title and count.
class _LiveHeader extends ConsumerWidget {
  const _LiveHeader({required this.showRecent, required this.title, required this.count, required this.padding});
  final bool showRecent;
  final String title;
  final int? count;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = showRecent ? ref.watch(recentChannelsProvider) : const <MediaItem>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(padding.left, 4, 0, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (recent.isNotEmpty) ...[
          const Eyebrow('Recently watched', padding: EdgeInsets.only(bottom: 6)),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.only(right: padding.right),
              itemCount: recent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChannelChip(item: recent[i]),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(title, style: AppText.h5),
          const SizedBox(width: 10),
          if (count != null) Text(formatCount(count!), style: const TextStyle(fontSize: 12, color: AppColors.neutral600)),
        ]),
        const SizedBox(height: 6),
      ]),
    );
  }
}

/// Favourite channels, filtered locally.
class _FavouriteChannels extends ConsumerWidget {
  const _FavouriteChannels({required this.query, required this.group, required this.padding, this.header});
  final String query;
  final String? group;
  final EdgeInsets padding;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.toLowerCase();
    final favs = (ref.watch(favoritesProvider).value ?? const <Favorite>[])
        .where((f) => f.kind == MediaKind.channel)
        .map((f) => f.item!)
        .where((c) => group == null || c.group == group || (group == Categories.uncategorized && c.group.isEmpty))
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || (c.epg.now?.title.toLowerCase().contains(q) ?? false))
        .toList();
    return CustomScrollView(slivers: [
      if (header != null) SliverToBoxAdapter(child: header),
      SliverPadding(
        padding: padding,
        sliver: favs.isEmpty
            ? SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    q.isEmpty ? 'No favourite channels yet. Use the star on any channel to add it.' : 'No favourites match "$query".',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            : MediaGridSliver(items: favs, kind: MediaKind.channel),
      ),
    ]);
  }
}

String _label(String g) => g == Categories.uncategorized ? 'Uncategorized' : g;

List<String?> _entries(Categories c) => [null, ...c.names, if (c.hasUncategorized) Categories.uncategorized];

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.cats, required this.selected, required this.onSelect});
  final Categories cats;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = _entries(cats);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, 8),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final g = entries[i];
          return FilterPill(g == null ? 'All' : _label(g), selected: g == selected, onTap: () => onSelect(g));
        },
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.title, required this.cats, required this.selected, required this.onSelect});
  final String title;
  final Categories cats;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = _entries(cats);
    return SizedBox(
      width: 212,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(context.pagePadding, 4, 12, 24),
        itemCount: entries.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return Eyebrow(title, padding: const EdgeInsets.fromLTRB(10, 6, 10, 6));
          final g = entries[i - 1];
          final sel = g == selected;
          return SideListItem(
            selected: sel,
            onTap: () => onSelect(g),
            child: SideListLabel(g == null ? 'All' : _label(g), selected: sel),
          );
        },
      ),
    );
  }
}
