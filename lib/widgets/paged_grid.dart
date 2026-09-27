import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/account.dart';
import '../models/media.dart';
import 'common.dart';
import 'media_cards.dart';

typedef PageFetcher = Future<Paged<MediaItem>> Function(int offset);

/// Infinite-scrolling CSS-style `repeat(auto-fill, minmax(min, 1fr))` grid.
/// Changing [queryKey] resets it.
class PagedMediaGrid extends StatefulWidget {
  const PagedMediaGrid({
    super.key,
    required this.queryKey,
    required this.fetch,
    this.itemBuilder,
    this.itemHeight = posterHeight,
    this.skeleton = posterSkeleton,
    this.minItemWidth = 150,
    this.mainAxisSpacing = 18,
    this.crossAxisSpacing = 14,
    this.padding,
    this.headerSlivers = const [],
    this.onTotal,
    this.transform,
    this.emptyMessage = 'Nothing here yet.',
  });

  final Object queryKey;
  final PageFetcher fetch;

  /// Card for one item; defaults to [PosterCard].
  final Widget Function(BuildContext context, MediaItem item)? itemBuilder;

  /// Cell height for a given column width (cards sit in fixed-height cells).
  final double Function(double width) itemHeight;
  final Widget Function(BuildContext context) skeleton;
  final double minItemWidth;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  /// Around the grid; defaults to the page padding.
  final EdgeInsets? padding;

  /// Slivers scrolled above the grid (headings, chip rows).
  final List<Widget> headerSlivers;

  /// (loaded, total) — total is null until the first page arrives.
  final void Function(int loaded, int? total)? onTotal;

  /// Client-side reorder of the loaded items.
  final List<MediaItem> Function(List<MediaItem> items)? transform;

  /// Compact muted line shown when nothing matches.
  final String emptyMessage;

  /// 2:3 art + 6 gap + title + meta line.
  static double posterHeight(double w) => w * 3 / 2 + 44;

  static Widget posterSkeleton(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 2 / 3, child: Skeleton()),
          SizedBox(height: 8),
          Skeleton(height: 12, width: 90, radius: 4),
        ],
      );

  @override
  State<PagedMediaGrid> createState() => _PagedMediaGridState();
}

class _PagedMediaGridState extends State<PagedMediaGrid> {
  final _items = <MediaItem>[];
  int _total = -1;
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  bool get _hasMore => _total < 0 || _items.length < _total;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PagedMediaGrid old) {
    super.didUpdateWidget(old);
    if (old.queryKey != widget.queryKey) {
      _reset();
      _load();
    }
  }

  void _reset() {
    _generation++;
    _items.clear();
    _total = -1;
    _error = null;
    _loading = false;
    _report();
  }

  // Deferred so parents may setState from the callback at any point.
  void _report() {
    final cb = widget.onTotal;
    if (cb == null) return;
    final loaded = _items.length;
    final total = _total < 0 ? null : _total;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cb(loaded, total);
    });
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    setState(() => _loading = true);
    try {
      final page = await widget.fetch(_items.length);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.items.isEmpty ? _items.length : page.total;
      });
      _report();
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(_reset);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.padding ?? EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, 32);
    final items = widget.transform?.call(_items) ?? _items;

    Widget body;
    if (_items.isEmpty && _error != null) {
      body = SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: _error!, onRetry: _refresh));
    } else if (_items.isEmpty && !_loading && !_hasMore) {
      body = SliverPadding(
        padding: EdgeInsets.fromLTRB(pad.left, 48, pad.right, 48),
        sliver: SliverToBoxAdapter(
          child: Text(widget.emptyMessage, style: TextStyle(fontSize: 14, color: AppColors.muted)),
        ),
      );
    } else {
      body = SliverPadding(
        padding: pad,
        sliver: SliverLayoutBuilder(builder: (context, constraints) {
          final w = constraints.crossAxisExtent;
          final gap = widget.crossAxisSpacing;
          final cols = ((w + gap) / (widget.minItemWidth + gap)).floor().clamp(1, 16);
          final itemWidth = (w - (cols - 1) * gap) / cols;
          final showSkeleton = _items.isEmpty && _loading;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: widget.mainAxisSpacing,
              crossAxisSpacing: gap,
              mainAxisExtent: widget.itemHeight(itemWidth),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (showSkeleton) return widget.skeleton(context);
                if (i >= items.length - 12) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
                final item = items[i];
                return widget.itemBuilder?.call(context, item) ?? PosterCard(item: item);
              },
              childCount: showSkeleton ? cols * 3 : items.length,
            ),
          );
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(slivers: [
        ...widget.headerSlivers,
        body,
        if (_loading && _items.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          ),
      ]),
    );
  }
}
