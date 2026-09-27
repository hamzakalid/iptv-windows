import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/account.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../player/player_screen.dart';
import '../../widgets/nocturne.dart';
import '../../widgets/paged_grid.dart';
import '../browse/browse_screen.dart';

enum _LiveSort {
  number('Channel number'),
  name('A–Z'),
  recent('Recently watched');

  const _LiveSort(this.label);
  final String label;
}

/// Live TV: category aside, All / Favourites scope, recently watched chips
/// and a grid of channel cards with now/next from the EPG.
class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  String? _group;
  String _query = '';
  bool _favs = false;
  _LiveSort _sort = _LiveSort.number;
  final _search = TextEditingController();
  Timer? _debounce;
  int? _total;
  int? _allTotal;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyIntent());
  }

  void _applyIntent() {
    final intent = ref.read(browseIntentProvider.notifier).take(MediaKind.channel);
    if (intent != null && mounted) setState(() => _group = intent.group);
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && v.trim() != _query) setState(() => _query = v.trim());
    });
  }

  void _onTotal(int loaded, int? total) => setState(() {
        _total = total;
        if (!_favs && _group == null && _query.isEmpty && total != null) _allTotal = total;
      });

  bool _inGroup(MediaItem c) =>
      _group == null || (_group == Categories.uncategorized ? c.group.isEmpty : c.group == _group);

  bool _matches(MediaItem c) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return c.name.toLowerCase().contains(q) || '${c.number ?? ''}'.contains(q);
  }

  /// Stable reorder: recently watched first (in history order), rest as-is.
  List<MediaItem> _byRecent(List<MediaItem> items, List<MediaItem> recent) {
    final rank = {for (final (i, r) in recent.indexed) r.id: i};
    final indexed = items.indexed.toList()
      ..sort((a, b) {
        final c = (rank[a.$2.id] ?? 1 << 20).compareTo(rank[b.$2.id] ?? 1 << 20);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return [for (final (_, c) in indexed) c];
  }

  List<MediaItem> _sortLocal(List<MediaItem> items, List<MediaItem> recent) => switch (_sort) {
        _LiveSort.number => [...items]..sort((a, b) {
            final an = a.number, bn = b.number;
            if (an != null && bn != null && an != bn) return an.compareTo(bn);
            if ((an == null) != (bn == null)) return an == null ? 1 : -1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }),
        _LiveSort.name => [...items]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
        _LiveSort.recent => _byRecent(items, recent),
      };

  @override
  Widget build(BuildContext context) {
    ref.listen(browseIntentProvider, (_, next) {
      if (next != null && next.kind == MediaKind.channel) _applyIntent();
    });
    final playlistId = ref.watch(activePlaylistProvider);
    final repo = ref.watch(repositoryProvider);
    final cats = ref.watch(categoriesProvider(MediaKind.channel)).value;
    final recent = ref.watch(recentChannelsProvider);
    final wide = context.isWide;

    final favChannels = _favs
        ? [
            for (final f in ref.watch(favoritesProvider).value ?? const <Favorite>[])
              if (f.kind == MediaKind.channel && f.item != null && _inGroup(f.item!) && _matches(f.item!)) f.item!,
          ]
        : const <MediaItem>[];

    final header = CatalogHeader(
      title: 'Live TV',
      caption: _allTotal == null ? '…' : '$_allTotal channels',
      gap: 16,
      controlsWidth: 720,
      search: CatalogSearchField(
        controller: _search,
        hint: 'Search channels or programmes',
        width: 280,
        onChanged: _onSearch,
      ),
      controls: [
        Seg<bool>(
          options: const [
            SegOption(false, 'All', icon: Ph.squaresFour),
            SegOption(true, 'Favourites', icon: Ph.star),
          ],
          value: _favs,
          onChanged: (v) => setState(() => _favs = v),
        ),
        NocButton(
          label: _sort.label,
          icon: Ph.sortAscending,
          tooltip: 'Change sort order',
          onPressed: () => setState(() => _sort = _LiveSort.values[(_sort.index + 1) % _LiveSort.values.length]),
        ),
      ],
    );

    final side = wide ? const (12.0, 24.0) : const (16.0, 16.0);
    final gridTitle = _favs ? 'Favourites' : (_group == null ? 'All channels' : categoryLabel(_group!));
    final showRecent = _query.isEmpty && !_favs && recent.isNotEmpty;

    final headerSlivers = <Widget>[
      if (!wide && cats != null)
        SliverToBoxAdapter(child: CategoryChips(cats: cats, selected: _group, onSelect: _select)),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(side.$1, 4, side.$2, 0),
        sliver: SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (showRecent) ...[
              const Overline('Recently watched'),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  for (final (i, c) in recent.indexed) ...[if (i > 0) const SizedBox(width: 8), ChannelChip(item: c)],
                ]),
              ),
              const SizedBox(height: 18),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Flexible(child: Text(gridTitle, style: NocText.h5, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 10),
                Text(_total == null ? '' : '$_total', style: const TextStyle(fontSize: 12, color: AppColors.n600)),
              ]),
            ),
          ]),
        ),
      ),
    ];

    final grid = PagedMediaGrid(
      queryKey: _favs
          ? ('fav', _group, _query, Object.hashAll(favChannels.map((c) => c.id)))
          : (playlistId, _group, _query, _sort == _LiveSort.name, repo),
      minItemWidth: wide ? 232 : 160,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      // 16:8 art + name, now, progress and time rows.
      itemHeight: (w) => w / 2 + 100,
      skeleton: (_) => const Skeleton(),
      padding: EdgeInsets.fromLTRB(side.$1, 0, side.$2, 32),
      headerSlivers: headerSlivers,
      onTotal: _onTotal,
      emptyMessage: _query.isNotEmpty
          ? 'No channels match “$_query”.'
          : _favs
              ? 'No favourite channels here yet.'
              : 'No channels here.',
      itemBuilder: (context, c) => ChannelCard(
        item: c,
        // Zap within what the user is looking at: favourites, or the category.
        onTap: () => PlayerScreen.open(
          context,
          PlayerArgs.channel(c, channels: _favs ? favChannels : const [], category: _favs ? 'Favourites' : _group),
        ),
      ),
      transform: _favs
          ? (items) => _sortLocal(items, recent)
          : _sort == _LiveSort.recent
              ? (items) => _byRecent(items, recent)
              : null,
      fetch: _favs
          ? (offset) async => Paged(items: offset == 0 ? favChannels : const [], total: favChannels.length, offset: offset)
          : (offset) => repo.list(MediaKind.channel,
              playlistId: playlistId,
              group: _group,
              q: _query,
              filter: ListFilter(sort: _sort == _LiveSort.name ? SortOption.name : SortOption.recent),
              offset: offset),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          header,
          Expanded(
            child: wide && cats != null
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CategoryAside(
                      title: 'Categories',
                      cats: cats,
                      selected: _group,
                      allCount: _allTotal,
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

  void _select(String? g) => setState(() => _group = g);
}
