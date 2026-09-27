import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _search = TextEditingController();
  Timer? _debounce;
  bool _shuffling = false;

  bool get _rated => widget.kind != MediaKind.channel;

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
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
  }

  String get _title => switch (widget.kind) {
        MediaKind.movie => 'Movies',
        MediaKind.series => 'Series',
        MediaKind.channel => 'Live TV',
      };

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing matches these filters.')));
      } else {
        openItem(context, item);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _shuffling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(browseIntentProvider, (_, next) {
      if (next != null && next.kind == widget.kind) _applyIntent();
    });
    final playlistId = ref.watch(activePlaylistProvider);
    final repo = ref.watch(repositoryProvider);
    final cats = ref.watch(categoriesProvider(widget.kind)).value;
    final wide = context.isWide;
    final pad = context.pagePadding;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(pad, 16, pad - (wide ? 0 : 8), 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(_group == null ? _title : '$_title · ${_label(_group!)}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineMedium),
          ),
          if (wide) SizedBox(width: 300, child: _searchField()) else const HeaderActions(),
        ]),
        if (!wide) ...[const SizedBox(height: 12), Padding(padding: const EdgeInsets.only(right: 8), child: _searchField())],
        const SizedBox(height: 12),
        _Toolbar(
          filter: _filter,
          rated: _rated,
          shuffling: _shuffling,
          onFilter: (f) => setState(() => _filter = f),
          onSurprise: _surprise,
        ),
      ]),
    );

    final grid = PagedMediaGrid(
      queryKey: (playlistId, _group, _query, _filter, repo),
      kind: widget.kind,
      emptyTitle: _query.isEmpty ? 'No ${_title.toLowerCase()} match these filters' : 'No results for "$_query"',
      header: wide || cats == null ? null : _CategoryChips(cats: cats, selected: _group, onSelect: _select),
      fetch: (offset) => repo.list(widget.kind,
          playlistId: playlistId, group: _group, q: _query, filter: _filter, offset: offset),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          header,
          Expanded(
            child: wide && cats != null
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _CategoryList(cats: cats, selected: _group, onSelect: _select),
                    Expanded(child: grid),
                  ])
                : grid,
          ),
        ]),
      ),
    );
  }

  void _select(String? g) => setState(() => _group = g);

  Widget _searchField() => SizedBox(
        height: 42,
        child: TextField(
          controller: _search,
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: 'Search ${_title.toLowerCase()}',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _search.clear();
                      _onSearch('');
                    },
                  ),
          ),
        ),
      );
}

/// Sort menu, rating pills and the "Surprise me" shuffle.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.filter,
    required this.rated,
    required this.shuffling,
    required this.onFilter,
    required this.onSurprise,
  });

  final ListFilter filter;
  final bool rated;
  final bool shuffling;
  final ValueChanged<ListFilter> onFilter;
  final VoidCallback onSurprise;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final sorts = rated ? SortOption.values : [SortOption.recent, SortOption.name];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        PopupMenuButton<SortOption>(
          tooltip: 'Sort',
          initialValue: filter.sort,
          onSelected: (s) => onFilter(filter.copyWith(sort: s)),
          itemBuilder: (_) => [
            for (final s in sorts)
              PopupMenuItem(
                value: s,
                child: Row(children: [
                  Icon(s == filter.sort ? Icons.check_rounded : null, size: 18),
                  const SizedBox(width: 8),
                  Text(s.label),
                ]),
              ),
          ],
          child: Pill(filter.sort.label, icon: Icons.swap_vert_rounded),
        ),
        if (rated) ...[
          const SizedBox(width: 14),
          for (final (label, value) in [('Any rating', null), ('6+', 6.0), ('7+', 7.0), ('8+', 8.0)])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pill(
                label,
                icon: value == null ? null : Icons.star_rounded,
                selected: filter.minRating == value,
                onTap: () => onFilter(filter.copyWith(minRating: () => value)),
              ),
            ),
        ],
        const SizedBox(width: 6),
        Tooltip(
          message: 'Pick something at random',
          child: Pill(
            wide ? 'Surprise me' : 'Random',
            icon: shuffling ? Icons.hourglass_top_rounded : Icons.casino_rounded,
            onTap: shuffling ? null : onSurprise,
          ),
        ),
      ]),
    );
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
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.pagePadding, vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = entries[i];
          return Pill(g == null ? 'All' : _label(g), selected: g == selected, onTap: () => onSelect(g));
        },
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.cats, required this.selected, required this.onSelect});
  final Categories cats;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = _entries(cats);
    return SizedBox(
      width: 232,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(context.pagePadding, 8, 8, 24),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final g = entries[i];
          final isSel = g == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: isSel ? AppColors.surfaceHover : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                hoverColor: AppColors.surfaceHigh,
                onTap: () => onSelect(g),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    g == null ? 'All' : _label(g),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSel ? AppColors.text : AppColors.textMuted,
                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
