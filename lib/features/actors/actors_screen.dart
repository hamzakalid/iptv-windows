import 'dart:async';

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

enum _ActorSort {
  popularity('Popular', 'popularity'),
  titles('Most titles', 'titles'),
  name('A – Z', 'name');

  const _ActorSort(this.label, this.param);
  final String label;
  final String param;
}

/// Actors credited in the user's movies and series: search, sort, an
/// optional photos-only filter and an infinitely scrolling grid.
class ActorsScreen extends ConsumerStatefulWidget {
  const ActorsScreen({super.key});

  @override
  ConsumerState<ActorsScreen> createState() => _ActorsScreenState();
}

class _ActorsScreenState extends ConsumerState<ActorsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  _ActorSort _sort = _ActorSort.popularity;
  bool _withPhoto = false;
  int? _total;

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {}); // clear button visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && v.trim() != _query) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final pad = context.pagePadding;
    final repo = ref.watch(repositoryProvider);
    final caption = _total == null ? '…' : '${formatCount(_total!)} actor${_total == 1 ? '' : 's'} in your library';

    final controls = <Widget>[
      SizedBox(width: wide ? 240 : double.infinity, child: _searchField()),
      SegmentedControl<_ActorSort>(
        segments: [for (final s in _ActorSort.values) Segment(s, s.label)],
        selected: _sort,
        onChanged: (s) => setState(() => _sort = s),
      ),
      FilterPill(
        'With photo',
        icon: _withPhoto ? PhosphorIconsFill.userCircle : PhosphorIconsRegular.userCircle,
        selected: _withPhoto,
        onTap: () => setState(() => _withPhoto = !_withPhoto),
      ),
    ];

    final header = Padding(
      padding: EdgeInsets.fromLTRB(pad, wide ? 20 : 12, wide ? pad : 8, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Actors', style: wide ? AppText.h3 : AppText.h4),
              const SizedBox(height: 4),
              Text(caption, style: AppText.meta),
            ]),
          ),
          if (wide)
            Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: controls)
          else
            const HeaderActions(),
        ]),
        if (!wide) ...[
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.only(right: 8), child: controls.first),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final c in controls.skip(1)) Padding(padding: const EdgeInsets.only(right: 8), child: c),
            ]),
          ),
        ],
      ]),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          Expanded(
            child: _ActorGrid(
              key: ValueKey((_query, _sort, _withPhoto, repo)),
              fetch: (offset) => repo.actors(q: _query, sort: _sort.param, withPhoto: _withPhoto, offset: offset),
              minItemWidth: wide ? 150 : 108,
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 32),
              emptyMessage: _query.isEmpty
                  ? 'No actors yet. Cast appears here once movie and series details have been fetched from your provider.'
                  : 'No actors match "$_query".',
              onTotal: (t) {
                if (t != _total) setState(() => _total = t);
              },
            ),
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
            hintText: 'Search actors',
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

/// Paged auto-fill grid of [ActorCard]s.
class _ActorGrid extends StatefulWidget {
  const _ActorGrid({
    super.key,
    required this.fetch,
    required this.minItemWidth,
    required this.padding,
    required this.emptyMessage,
    required this.onTotal,
  });

  final Future<Paged<Actor>> Function(int offset) fetch;
  final double minItemWidth;
  final EdgeInsets padding;
  final String emptyMessage;
  final ValueChanged<int> onTotal;

  @override
  State<_ActorGrid> createState() => _ActorGridState();
}

class _ActorGridState extends State<_ActorGrid> {
  final _items = <Actor>[];
  int _total = -1;
  bool _loading = false;
  Object? _error;

  bool get _hasMore => _total < 0 || _items.length < _total;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await widget.fetch(_items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _total = page.items.isEmpty ? _items.length : page.total;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onTotal(_total);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _total = -1;
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _error != null) return ErrorView(error: _error!, onRetry: _refresh);
    if (_items.isEmpty && !_loading && !_hasMore) {
      return Padding(
        padding: widget.padding.copyWith(top: 48),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(widget.emptyMessage, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(builder: (context, c) {
        const gap = 14.0;
        final w = c.maxWidth - widget.padding.horizontal;
        final cols = ((w + gap) / (widget.minItemWidth + gap)).floor().clamp(2, 16);
        final itemWidth = (w - (cols - 1) * gap) / cols;
        final skeleton = _items.isEmpty && _loading;
        return GridView.builder(
          padding: widget.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 18,
            crossAxisSpacing: gap,
            mainAxisExtent: ActorCard.heightFor(itemWidth),
          ),
          itemCount: skeleton ? cols * 3 : _items.length + (_loading ? cols : 0),
          itemBuilder: (context, i) {
            if (skeleton || i >= _items.length) return _ActorSkeleton(width: itemWidth);
            if (i >= _items.length - 12) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
            return ActorCard(actor: _items[i]);
          },
        );
      }),
    );
  }
}

class _ActorSkeleton extends StatelessWidget {
  const _ActorSkeleton({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Column(children: [
        Skeleton(width: width * 0.8, height: width * 0.8, radius: width),
        const SizedBox(height: 10),
        const Skeleton(width: 80, height: 12, radius: 4),
      ]);
}

/// Circle photo (or initials), name and "3 movies · 1 series".
class ActorCard extends StatelessWidget {
  const ActorCard({super.key, required this.actor, this.width});
  final Actor actor;
  final double? width;

  /// Cell height for a column width: 80% circle + name + credits.
  static double heightFor(double w) => w * 0.8 + 56;

  @override
  Widget build(BuildContext context) {
    final id = actor.id;
    return SizedBox(
      width: width,
      child: Hoverable(
        radius: Radii.md,
        ring: const [],
        hoverColor: AppColors.wash(0.05),
        onTap: id == null ? null : () => context.push('/actor/$id'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.neutral900,
                      boxShadow: Shadows.sm,
                    ),
                    child: actor.hasPhoto
                        ? NetImage(actor.profileUrl, label: actor.name, labelSize: 18, memCacheWidth: 300)
                        : LayoutBuilder(
                            builder: (_, c) => Text(initials(actor.name),
                                style: TextStyle(fontSize: c.maxWidth * 0.22, color: AppColors.neutral500)),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(actor.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: AppText.title),
            const SizedBox(height: 1),
            Text(actor.creditsLabel.isEmpty ? (actor.knownFor ?? 'Actor') : actor.creditsLabel,
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: AppText.meta),
          ]),
        ),
      ),
    );
  }
}
