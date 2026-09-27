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
import '../../widgets/nocturne.dart';
import '../../widgets/paged_grid.dart';

/// Movies / Series catalogue: genre aside, rating + sort filters, search and
/// an infinitely scrolling poster grid.
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
  int _loaded = 0;
  int? _total;
  int? _allTotal;

  @override
  void initState() {
    super.initState();
    // Another screen may have asked for a pre-selected category.
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyIntent());
  }

  void _applyIntent() {
    final intent = ref.read(browseIntentProvider.notifier).take(widget.kind);
    if (intent != null && mounted) {
      setState(() {
        _group = intent.group;
        if (intent.sort != null) _filter = _filter.copyWith(sort: intent.sort);
      });
    }
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
      if (!mounted || v.trim() == _query) return;
      setState(() {
        _query = v.trim();
        _allTotal = null;
      });
    });
  }

  void _setFilter(ListFilter f) => setState(() {
        if (f.minRating != _filter.minRating) _allTotal = null;
        _filter = f;
      });

  String get _title => widget.kind == MediaKind.series ? 'Series' : 'Movies';

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

  void _onTotal(int loaded, int? total) => setState(() {
        _loaded = loaded;
        _total = total;
        if (_group == null && total != null) _allTotal = total;
      });

  @override
  Widget build(BuildContext context) {
    ref.listen(browseIntentProvider, (_, next) {
      if (next != null && next.kind == widget.kind) _applyIntent();
    });
    final playlistId = ref.watch(activePlaylistProvider);
    final repo = ref.watch(repositoryProvider);
    final cats = ref.watch(categoriesProvider(widget.kind)).value;
    final wide = context.isWide;
    final sorts = SortOption.values;

    final caption = _total == null
        ? '…'
        : '$_loaded of $_total${_group == null ? '' : ' · ${categoryLabel(_group!)}'}';

    final header = CatalogHeader(
      title: _title,
      caption: caption,
      controlsWidth: 790,
      search: CatalogSearchField(
        controller: _search,
        hint: 'Search ${_title.toLowerCase()}',
        width: 240,
        onChanged: _onSearch,
      ),
      controls: [
        Seg<double?>(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          options: [
            const SegOption(null, 'Any'),
            for (final r in const [6.0, 7.0, 8.0]) SegOption(r, '${r.toInt()}+', icon: PhF.star),
          ],
          value: _filter.minRating,
          onChanged: (v) => _setFilter(_filter.copyWith(minRating: () => v)),
        ),
        NocButton(
          label: _filter.sort.label,
          icon: Ph.sortAscending,
          tooltip: 'Change sort order',
          onPressed: () => _setFilter(_filter.copyWith(sort: sorts[(sorts.indexOf(_filter.sort) + 1) % sorts.length])),
        ),
        NocButton(
          label: 'Surprise me',
          icon: Ph.shuffle,
          tooltip: 'Pick something at random',
          onPressed: _shuffling ? null : _surprise,
        ),
      ],
    );

    final grid = PagedMediaGrid(
      queryKey: (playlistId, _group, _query, _filter, repo),
      minItemWidth: wide ? 150 : 105,
      padding: wide ? const EdgeInsets.fromLTRB(12, 4, 24, 32) : const EdgeInsets.fromLTRB(16, 4, 16, 32),
      emptyMessage: 'Nothing matches these filters.',
      onTotal: _onTotal,
      headerSlivers: [
        if (!wide && cats != null)
          SliverToBoxAdapter(child: CategoryChips(cats: cats, selected: _group, onSelect: _select)),
      ],
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
                    CategoryAside(
                      title: 'Genres',
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

// ---------------------------------------------------------------------------
// Pieces shared with Live TV
// ---------------------------------------------------------------------------

String categoryLabel(String g) => g == Categories.uncategorized ? 'Uncategorized' : g;

List<String?> categoryEntries(Categories c) => [null, ...c.names, if (c.hasUncategorized) Categories.uncategorized];

/// Page header: title + caption on the left, search and controls on the
/// right (desktop, bottom-aligned, wrapping when tight); stacked on phones.
class CatalogHeader extends StatelessWidget {
  const CatalogHeader({
    super.key,
    required this.title,
    required this.caption,
    required this.search,
    required this.controls,
    required this.controlsWidth,
    this.gap = 12,
  });

  final String title;
  final String caption;
  final Widget search;
  final List<Widget> controls;

  /// Rough width of search + controls, to decide when to wrap.
  final double controlsWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final titleBlock = PageTitle(title, caption: caption);
    if (!context.isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: titleBlock), const HeaderActions()]),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.only(right: 8), child: search),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final (i, c) in controls.indexed) ...[if (i > 0) SizedBox(width: gap - 4), c],
            ]),
          ),
        ]),
      );
    }
    final all = [search, ...controls];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth - controlsWidth >= 200) {
          return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: titleBlock),
            for (final w in all) ...[SizedBox(width: gap), w],
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          titleBlock,
          const SizedBox(height: 12),
          Wrap(spacing: gap, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: all),
        ]);
      }),
    );
  }
}

/// `.input` with a magnifying-glass prefix and a clear button.
class CatalogSearchField extends StatefulWidget {
  const CatalogSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.width,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double? width;

  @override
  State<CatalogSearchField> createState() => _CatalogSearchFieldState();
}

class _CatalogSearchFieldState extends State<CatalogSearchField> {
  @override
  Widget build(BuildContext context) => SizedBox(
        width: context.isWide ? widget.width : null,
        height: 36,
        child: TextField(
          controller: widget.controller,
          onChanged: (v) {
            setState(() {});
            widget.onChanged(v);
          },
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Ph.magnifyingGlass, size: 16),
            prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 34),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 34),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : Tappable(
                    radius: Radii.sm,
                    onTap: () {
                      widget.controller.clear();
                      setState(() {});
                      widget.onChanged('');
                    },
                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Ph.x, size: 14)),
                  ),
          ),
        ),
      );
}

/// 200px aside: overline + category rows. Only "All" carries a count —
/// the API has no per-category totals.
class CategoryAside extends StatelessWidget {
  const CategoryAside({
    super.key,
    required this.title,
    required this.cats,
    required this.selected,
    required this.onSelect,
    this.allCount,
  });

  final String title;
  final Categories cats;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final int? allCount;

  @override
  Widget build(BuildContext context) {
    final entries = categoryEntries(cats);
    return SizedBox(
      width: 200,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 4, 12, 24),
        itemCount: entries.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return Overline(title, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6));
          final g = entries[i - 1];
          return SideListItem(
            label: g == null ? 'All' : categoryLabel(g),
            count: g == null && allCount != null ? '$allCount' : null,
            selected: g == selected,
            onTap: () => onSelect(g),
          );
        },
      ),
    );
  }
}

/// Phone replacement for the aside: a scrolling row of pills.
class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key, required this.cats, required this.selected, required this.onSelect});
  final Categories cats;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final entries = categoryEntries(cats);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = entries[i];
          return Pill(g == null ? 'All' : categoryLabel(g), selected: g == selected, onTap: () => onSelect(g));
        },
      ),
    );
  }
}
