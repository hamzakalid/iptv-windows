import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/account.dart';
import '../models/media.dart';
import 'common.dart';
import 'media_cards.dart';

typedef PageFetcher = Future<Paged<MediaItem>> Function(int offset);

/// Infinite-scrolling grid of media cards. Changing [queryKey] resets it.
class PagedMediaGrid extends StatefulWidget {
  const PagedMediaGrid({
    super.key,
    required this.queryKey,
    required this.fetch,
    required this.kind,
    this.header,
    this.emptyTitle = 'Nothing here yet',
  });

  final Object queryKey;
  final PageFetcher fetch;
  final MediaKind kind;
  final Widget? header;
  final String emptyTitle;

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
      _generation++;
      _items.clear();
      _total = -1;
      _error = null;
      _loading = false;
      _load();
    }
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
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _generation++;
      _items.clear();
      _total = -1;
      _error = null;
      _loading = false;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.kind == MediaKind.channel;
    final wide = context.isWide;
    final maxExtent = channel ? (wide ? 230.0 : 170.0) : (wide ? 190.0 : 130.0);
    final aspect = channel ? 16 / 10 : 2 / 3;
    final pad = context.pagePadding;

    Widget body;
    if (_items.isEmpty && _error != null) {
      body = SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: _error!, onRetry: _refresh));
    } else if (_items.isEmpty && !_loading && !_hasMore) {
      body = SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(icon: Icons.inbox_outlined, title: widget.emptyTitle),
      );
    } else {
      body = SliverPadding(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
        sliver: SliverLayoutBuilder(builder: (context, constraints) {
          final cols = (constraints.crossAxisExtent / maxExtent).ceil().clamp(2, 12);
          final itemWidth = (constraints.crossAxisExtent - (cols - 1) * 14) / cols;
          // Card = artwork + title (+ subtitle for posters).
          final itemHeight = itemWidth / aspect + (channel ? 30 : 48);
          final showSkeleton = _items.isEmpty && _loading;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 18,
              crossAxisSpacing: 14,
              childAspectRatio: itemWidth / itemHeight,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (showSkeleton) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AspectRatio(aspectRatio: aspect, child: const Skeleton(radius: 14)),
                    const SizedBox(height: 8),
                    const Skeleton(height: 12, width: 90, radius: 4),
                  ]);
                }
                if (i >= _items.length - 12) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
                return MediaCard(item: _items[i]);
              },
              childCount: showSkeleton ? cols * 3 : _items.length,
            ),
          );
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(slivers: [
        if (widget.header != null) SliverToBoxAdapter(child: widget.header),
        body,
        if (_loading && _items.isNotEmpty)
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          ),
      ]),
    );
  }
}
