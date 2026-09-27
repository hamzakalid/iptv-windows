import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/paged_grid.dart';

enum SearchScope { all, movies, series, live }

/// Search across the playlist. Reads `?q=` and `?scope=` so other screens
/// can deep-link into a query.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Timer? _remember;
  String _q = '';
  SearchScope _scope = SearchScope.all;
  String? _routeQuery;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final params = GoRouterState.of(context).uri.queryParameters;
    final q = params['q'];
    if (q != null && q != _routeQuery) {
      _routeQuery = q;
      _controller.text = q;
      _q = q.trim();
      final s = int.tryParse(params['scope'] ?? '') ?? 0;
      _scope = SearchScope.values[s.clamp(0, SearchScope.values.length - 1)];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _remember?.cancel();
    super.dispose();
  }

  void _commit() {
    _remember?.cancel();
    if (_q.isNotEmpty) ref.read(recentSearchesProvider.notifier).add(_q);
  }

  void _changed(String v) {
    setState(() {}); // clear button visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _q = v.trim()));
    // A query left alone for a moment is one worth remembering.
    _remember?.cancel();
    _remember = Timer(const Duration(milliseconds: 2500), _commit);
  }

  void _set(String q) {
    _controller.text = q;
    _debounce?.cancel();
    setState(() => _q = q.trim());
  }

  void _clear() {
    _commit();
    _set('');
    ref.read(searchFocusProvider).requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final results = _q.isEmpty ? null : ref.watch(searchProvider(_q));
    final r = results?.value;
    String count(int Function(SearchResults) f) => r == null ? '' : '${f(r)}';
    final total = r == null ? 0 : r.movies.length + r.series.length + r.channels.length;

    final field = SizedBox(
      height: 46,
      child: TextField(
        controller: _controller,
        focusNode: ref.watch(searchFocusProvider),
        autofocus: context.isWide,
        onChanged: _changed,
        textInputAction: TextInputAction.search,
        onSubmitted: (v) {
          _set(v);
          _commit();
        },
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search movies, series, channels and what\'s on now',
          hintStyle: const TextStyle(fontSize: 16, color: AppColors.neutral500),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(PhosphorIconsRegular.magnifyingGlass, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          suffixIcon: _controller.text.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: IconButton(
                    tooltip: 'Clear',
                    onPressed: _clear,
                    icon: const Icon(PhosphorIconsRegular.x, size: 16),
                  ),
                ),
        ),
      ),
    );

    final summary = _q.isEmpty
        ? 'Tip: search a channel, a title or what\'s on now'
        : results!.isLoading
            ? 'Searching…'
            : '$total result${total == 1 ? '' : 's'} for "$_q"';

    final scopes = SegmentedControl<SearchScope>(
      dense: true,
      segments: [
        Segment(SearchScope.all, 'All', trailing: _q.isEmpty || r == null ? null : '$total'),
        Segment(SearchScope.movies, 'Movies', trailing: count((r) => r.movies.length)),
        Segment(SearchScope.series, 'Series', trailing: count((r) => r.series.length)),
        Segment(SearchScope.live, 'Live TV', trailing: count((r) => r.channels.length)),
      ],
      selected: _scope,
      onChanged: (s) => setState(() => _scope = s),
    );

    final List<Widget> body;
    if (_q.isEmpty) {
      body = [_Idle(onPick: _set)];
    } else if (results!.hasError) {
      body = [
        SliverToBoxAdapter(
          child: ErrorView(error: results.error!, onRetry: () => ref.invalidate(searchProvider(_q))),
        ),
      ];
    } else if (r == null) {
      body = [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ),
      ];
    } else {
      body = _results(r);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, context.isWide ? 24 : 12, pad, 0),
            sliver: SliverToBoxAdapter(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: field),
                    ),
                  ),
                  if (!context.isWide) ...[const SizedBox(width: 4), const HeaderActions()],
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  scopes,
                  Text(summary, style: const TextStyle(fontSize: 12.5, color: AppColors.neutral500)),
                ]),
                const SizedBox(height: 22),
              ]),
            ),
          ),
          for (final s in body) SliverPadding(padding: EdgeInsets.symmetric(horizontal: pad), sliver: s),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ]),
      ),
    );
  }

  List<Widget> _results(SearchResults r) {
    final all = _scope == SearchScope.all;
    final channels = all || _scope == SearchScope.live ? r.channels : const <MediaItem>[];
    final movies = all || _scope == SearchScope.movies ? r.movies : const <MediaItem>[];
    final series = all || _scope == SearchScope.series ? r.series : const <MediaItem>[];
    if (channels.isEmpty && movies.isEmpty && series.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Text(
            all ? 'No results for "$_q". Try a channel name, a title or a shorter search.' : 'Nothing in this section. Try "All".',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      ];
    }

    Widget heading(String title, int n) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(title, style: AppText.h5),
              const SizedBox(width: 8),
              Text('$n', style: const TextStyle(fontSize: 12, color: AppColors.neutral600)),
            ]),
          ),
        );
    const gap = SliverToBoxAdapter(child: SizedBox(height: 28));

    return [
      if (channels.isNotEmpty) ...[
        heading('Channels', channels.length),
        SliverLayoutBuilder(builder: (context, c) {
          final shown = all ? channels.take(6).toList() : channels;
          final cols = ((c.crossAxisExtent + 8) / (280 + 8)).floor().clamp(1, 6);
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 64,
            ),
            delegate: SliverChildBuilderDelegate((_, i) => ChannelResultRow(item: shown[i]), childCount: shown.length),
          );
        }),
        gap,
      ],
      if (movies.isNotEmpty) ...[heading('Movies', movies.length), MediaGridSliver(items: movies, kind: MediaKind.movie), gap],
      if (series.isNotEmpty) ...[heading('Series', series.length), MediaGridSliver(items: series, kind: MediaKind.series)],
    ];
  }
}

/// Before typing: recent searches and genre shortcuts.
class _Idle extends ConsumerWidget {
  const _Idle({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    final genres = ref.watch(categoriesProvider(MediaKind.movie)).value?.names ?? const <String>[];

    void browse(String g) {
      ref.read(browseIntentProvider.notifier).set(MediaKind.movie, g);
      StatefulNavigationShell.maybeOf(context)?.goBranch(1);
    }

    return SliverList.list(children: [
      if (recent.isNotEmpty) ...[
        const Eyebrow('Recent searches', padding: EdgeInsets.only(bottom: 8)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final q in recent)
            _RecentChip(
              query: q,
              onTap: () => onPick(q),
              onRemove: () => ref.read(recentSearchesProvider.notifier).remove(q),
            ),
        ]),
        const SizedBox(height: 26),
      ],
      if (genres.isNotEmpty) ...[
        const Eyebrow('Browse by genre', padding: EdgeInsets.only(bottom: 8)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: LayoutBuilder(builder: (context, c) {
            final cols = ((c.maxWidth + 8) / (160 + 8)).floor().clamp(2, 6);
            final w = (c.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in genres.take(18))
                SizedBox(
                  width: w,
                  child: SurfaceCard(
                    onTap: () => browse(g),
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      const Text('Movies', style: TextStyle(fontSize: 12, color: AppColors.neutral500)),
                    ]),
                  ),
                ),
            ]);
          }),
        ),
      ],
      if (recent.isEmpty && genres.isEmpty)
        const Text('Search across every channel, movie and series in your playlist.',
            style: TextStyle(color: AppColors.textMuted)),
    ]);
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.query, required this.onTap, required this.onRemove});
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(Radii.md)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(PhosphorIconsRegular.clockCounterClockwise, size: 14, color: AppColors.neutral600),
                const SizedBox(width: 6),
                Text(query, style: const TextStyle(fontSize: 13, color: AppColors.neutral300)),
              ]),
            ),
          ),
          InkWell(
            onTap: onRemove,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(Radii.md)),
            child: const Tooltip(
              message: 'Remove',
              child: Padding(
                padding: EdgeInsets.fromLTRB(4, 7, 8, 7),
                child: Icon(PhosphorIconsRegular.x, size: 13, color: AppColors.neutral600),
              ),
            ),
          ),
        ]),
      );
}
