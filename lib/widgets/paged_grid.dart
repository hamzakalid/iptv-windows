import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/account.dart';
import '../models/media.dart';
import 'common.dart';
import 'media_cards.dart';

typedef PageFetcher = Future<Paged<MediaItem>> Function(int offset);

/// Column count and tile height for a card grid, matching CSS
/// `repeat(auto-fill, minmax(min, 1fr))`.
({int cols, double extent}) gridMetrics(double width, MediaKind kind, {required bool wide, double gap = 14}) {
  final channel = kind == MediaKind.channel;
  final min = channel ? (wide ? 232.0 : 160.0) : (wide ? 150.0 : 108.0);
  final cols = ((width + gap) / (min + gap)).floor().clamp(2, 14);
  final itemWidth = (width - (cols - 1) * gap) / cols;
  final extent = channel ? itemWidth / 2 + channelCardBodyHeight : itemWidth * 1.5 + posterCaptionHeight;
  return (cols: cols, extent: extent);
}

/// Card grid sliver for a fixed list of items.
class MediaGridSliver extends StatelessWidget {
  const MediaGridSliver({super.key, required this.items, required this.kind});
  final List<MediaItem> items;
  final MediaKind kind;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(builder: (context, c) {
        final m = gridMetrics(c.crossAxisExtent, kind, wide: context.isWide);
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: m.cols,
            mainAxisSpacing: kind == MediaKind.channel ? 14 : 18,
            crossAxisSpacing: 14,
            mainAxisExtent: m.extent,
          ),
          delegate: SliverChildBuilderDelegate((_, i) => MediaCard(item: items[i]), childCount: items.length),
        );
      });
}

/// Infinite-scrolling grid of media cards. Changing [queryKey] resets it.
class PagedMediaGrid extends StatefulWidget {
  const PagedMediaGrid({
    super.key,
    required this.queryKey,
    required this.fetch,
    required this.kind,
    this.header,
    this.padding,
    this.emptyTitle = 'Nothing here yet',
    this.onTotal,
  });

  final Object queryKey;
  final PageFetcher fetch;
  final MediaKind kind;
  final Widget? header;
  final EdgeInsets? padding;
  final String emptyTitle;

  /// Reports the server's total for the current query (for "12 of 340").
  final ValueChanged<int>? onTotal;

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
      widget.onTotal?.call(_total);
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
    final channel = widget.kind == MediaKind.channel;
    final pad = context.pagePadding;
    final padding = widget.padding ?? EdgeInsets.fromLTRB(pad, 4, pad, 32);

    Widget body;
    if (_items.isEmpty && _error != null) {
      body = SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: _error!, onRetry: _refresh));
    } else if (_items.isEmpty && !_loading && !_hasMore) {
      body = SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Text(widget.emptyTitle, style: const TextStyle(color: AppColors.textMuted)),
        ),
      );
    } else {
      body = SliverLayoutBuilder(builder: (context, constraints) {
        final m = gridMetrics(constraints.crossAxisExtent, widget.kind, wide: context.isWide);
        final showSkeleton = _items.isEmpty && _loading;
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: m.cols,
            mainAxisSpacing: channel ? 14 : 18,
            crossAxisSpacing: 14,
            mainAxisExtent: m.extent,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              if (showSkeleton) return const Skeleton();
              if (i >= _items.length - 12) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
              return MediaCard(item: _items[i]);
            },
            childCount: showSkeleton ? m.cols * 3 : _items.length,
          ),
        );
      });
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(slivers: [
        if (widget.header != null) SliverToBoxAdapter(child: widget.header),
        SliverPadding(padding: padding, sliver: body),
        if (_loading && _items.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
      ]),
    );
  }
}
