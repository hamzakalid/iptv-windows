import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/account.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/paged_grid.dart';

/// Catalogue browser shared by Movies, Series and Live TV: a searchable,
/// category-filtered, infinitely scrolling grid.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key, required this.kind});
  final MediaKind kind;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  String? _group;
  String _query = '';
  final _search = TextEditingController();
  Timer? _debounce;

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

  @override
  Widget build(BuildContext context) {
    final playlistId = ref.watch(activePlaylistProvider);
    final repo = ref.watch(repositoryProvider);
    final cats = ref.watch(categoriesProvider(widget.kind)).value;
    final wide = context.isWide;
    final pad = context.pagePadding;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(pad, 16, pad - (wide ? 0 : 8), 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_title, style: Theme.of(context).textTheme.headlineMedium)),
          if (wide) SizedBox(width: 320, child: _searchField()) else const HeaderActions(),
        ]),
        if (!wide) ...[const SizedBox(height: 12), Padding(padding: const EdgeInsets.only(right: 8), child: _searchField())],
      ]),
    );

    final grid = PagedMediaGrid(
      queryKey: (playlistId, _group, _query, repo),
      kind: widget.kind,
      emptyTitle: _query.isEmpty ? 'No ${_title.toLowerCase()} here' : 'No results for "$_query"',
      header: wide || cats == null ? null : _CategoryChips(cats: cats, selected: _group, onSelect: _select),
      fetch: (offset) => repo.list(widget.kind, playlistId: playlistId, group: _group, q: _query, offset: offset),
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

  Widget _searchField() => TextField(
        controller: _search,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'Search ${_title.toLowerCase()}',
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
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
      );
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
          final isSel = g == selected;
          return ChoiceChip(
            label: Text(g == null ? 'All' : _label(g)),
            selected: isSel,
            labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.text, fontWeight: FontWeight.w600),
            onSelected: (_) => onSelect(g),
          );
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
      width: 240,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(context.pagePadding, 8, 8, 24),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final g = entries[i];
          final isSel = g == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Material(
              color: isSel ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(g),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    if (isSel)
                      Container(
                        width: 3,
                        height: 16,
                        margin: const EdgeInsets.only(right: 9),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    Expanded(
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
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
