import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/account.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/nocturne.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.initialScope = 0});
  final String? initialQuery;
  final int initialScope;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery ?? '');
  final _focus = FocusNode();
  Timer? _debounce;
  late String _q = widget.initialQuery?.trim() ?? '';
  late int _scope = widget.initialScope.clamp(0, searchScopes.length - 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    // The branch stays alive, so a new /search?q=…&scope=… arrives here.
    final q = widget.initialQuery;
    if (q != old.initialQuery && q != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setQuery(q);
      });
    }
    if (widget.initialScope != old.initialScope) _scope = widget.initialScope.clamp(0, searchScopes.length - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {}); // clear button visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _q = v.trim());
    });
  }

  void _setQuery(String v) {
    _debounce?.cancel();
    _controller.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    setState(() => _q = v.trim());
  }

  void _commit() => ref.read(recentSearchesProvider.notifier).add(_controller.text);

  void _clear() {
    _commit();
    _setQuery('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchFocusRequestProvider, (_, _) => _focus.requestFocus());
    final wide = context.isWide;
    final pad = context.pagePadding;
    final results = _q.isEmpty ? null : ref.watch(searchProvider(_q)).value;
    final hasText = _controller.text.isNotEmpty;

    String count(int n) => results == null ? '' : '$n';
    final total = results == null ? 0 : results.movies.length + results.series.length + results.channels.length;

    final input = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, minHeight: 46),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _setQuery(v);
          _commit();
        },
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search movies, series, channels and what’s on now',
          hintStyle: const TextStyle(fontSize: 16, color: AppColors.n500),
          contentPadding: const EdgeInsets.fromLTRB(0, 13, 10, 13),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(Ph.magnifyingGlass, size: 20, color: AppColors.n500),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: hasText
              ? Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: NocIconButton(icon: Ph.x, iconSize: 16, tooltip: 'Clear', onPressed: _clear),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 36),
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pad, wide ? 24 : 12, pad, 32),
          children: [
            if (wide)
              Align(alignment: Alignment.centerLeft, child: input)
            else
              Row(children: [
                NocIconButton(
                  icon: Ph.arrowLeft,
                  tooltip: 'Back',
                  onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                ),
                const SizedBox(width: 8),
                Expanded(child: input),
              ]),
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 22),
              child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Seg<int>(
                  options: [
                    SegOption(0, searchScopes[0], count: count(total)),
                    SegOption(1, searchScopes[1], count: count(results?.movies.length ?? 0)),
                    SegOption(2, searchScopes[2], count: count(results?.series.length ?? 0)),
                    SegOption(3, searchScopes[3], count: count(results?.channels.length ?? 0)),
                  ],
                  value: _scope,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  onChanged: (i) => setState(() => _scope = i),
                ),
                Text(
                  _q.isEmpty
                      ? 'Tip: search a channel number, a title, a genre or what’s on now'
                      : results == null
                          ? 'Searching…'
                          : '$total result${total == 1 ? '' : 's'} for “$_q”',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.n500),
                ),
              ]),
            ),
            if (_q.isEmpty)
              _Idle(onSearch: (v) {
                _setQuery(v);
                _commit();
              })
            else
              _Results(query: _q, scope: _scope, onOpen: _commit),
          ],
        ),
      ),
    );
  }
}

/// Recent searches + "Browse by genre" tiles.
class _Idle extends ConsumerWidget {
  const _Idle({required this.onSearch});
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    final genres = (ref.watch(categoriesProvider(MediaKind.movie)).value?.names ?? const <String>[]).take(24).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (recent.isNotEmpty) ...[
        const Overline('Recent searches', padding: EdgeInsets.only(bottom: 8)),
        Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in recent)
              _RecentChip(
                term: r,
                onTap: () => onSearch(r),
                onRemove: () => ref.read(recentSearchesProvider.notifier).remove(r),
              ),
          ]),
        ),
      ],
      if (genres.isNotEmpty) ...[
        const Overline('Browse by genre', padding: EdgeInsets.only(bottom: 8)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: _AutoGrid(
            minWidth: 160,
            gapX: 8,
            gapY: 8,
            children: [
              for (final g in genres)
                HoverRing(
                  ring: Shadows.accentRing,
                  onTap: () => onSearch(g),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Text(g,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
            ],
          ),
        ),
      ],
    ]);
  }
}

/// Outlined chip: clock + term (searches it) and a separate remove ×.
class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.term, required this.onTap, required this.onRemove});
  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Tappable(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Ph.clockCounterClockwise, size: 14, color: AppColors.n600),
                const SizedBox(width: 6),
                Text(term, style: const TextStyle(fontSize: 13, color: AppColors.n300)),
              ]),
            ),
          ),
          Tooltip(
            message: 'Remove',
            child: Tappable(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(4, 5, 8, 5),
                child: Icon(Ph.x, size: 14, color: AppColors.n600),
              ),
            ),
          ),
        ]),
      );
}

class _Results extends ConsumerWidget {
  const _Results({required this.query, required this.scope, required this.onOpen});
  final String query;
  final int scope;

  /// Called when a result is opened (records the term in recent searches).
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchProvider(query));
    final muted = TextStyle(color: AppColors.muted);
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(searchProvider(query))),
      data: (SearchResults r) {
        if (r.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No results for “$query”. Try a channel number, a title or a genre.', style: muted),
          );
        }
        final showCh = r.channels.isNotEmpty && (scope == 0 || scope == 3);
        final showMv = r.movies.isNotEmpty && (scope == 0 || scope == 1);
        final showSe = r.series.isNotEmpty && (scope == 0 || scope == 2);
        if (!showCh && !showMv && !showSe) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No ${searchScopes[scope].toLowerCase()} results for “$query”. Try “All”.', style: muted),
          );
        }
        final channels = scope == 0 ? r.channels.take(6).toList() : r.channels;
        final posterMin = context.isWide ? 150.0 : 110.0;
        Widget tracked(Widget child) => Listener(onPointerUp: (_) => onOpen(), child: child);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showCh) ...[
            _Heading('Channels', r.channels.length),
            _AutoGrid(
              minWidth: 280,
              gapX: 8,
              gapY: 8,
              children: [for (final c in channels) tracked(_ChannelRow(item: c))],
            ),
            const SizedBox(height: 28),
          ],
          if (showMv) ...[
            _Heading('Movies', r.movies.length),
            _AutoGrid(
              minWidth: posterMin,
              gapX: 14,
              gapY: 18,
              children: [for (final m in r.movies) tracked(PosterCard(item: m))],
            ),
            const SizedBox(height: 28),
          ],
          if (showSe) ...[
            _Heading('Series', r.series.length),
            _AutoGrid(
              minWidth: posterMin,
              gapX: 14,
              gapY: 18,
              children: [for (final m in r.series) tracked(PosterCard(item: m))],
            ),
          ],
        ]);
      },
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.count);
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(title, style: NocText.h5),
          const SizedBox(width: 6),
          Text('$count', style: const TextStyle(fontSize: 12, color: AppColors.n600)),
        ]),
      );
}

/// Surface row: 44px logo, "101 · Name", "Now: …", accent play glyph.
class _ChannelRow extends ConsumerWidget {
  const _ChannelRow({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useChannelEpg(ref, item)?.now;
    return HoverRing(
      ring: Shadows.accentRing,
      onTap: () => openItem(context, item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(Radii.md)),
        child: Row(children: [
          LogoTile(
            label: item.name,
            width: 44,
            height: 44,
            fontSize: 12,
            image: item.logo == null
                ? null
                : Padding(
                    padding: const EdgeInsets.all(5),
                    child: NetImage(item.logo, fit: BoxFit.contain, label: item.name, fontSize: 12, memCacheWidth: 120),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(channelLabel(item), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(now == null ? (item.group.isEmpty ? 'Live TV' : item.group) : 'Now: ${now.title}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(width: 12),
          const Icon(PhF.play, size: 16, color: AppColors.accent),
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
