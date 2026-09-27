import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _q = v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.only(right: pad),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(
              hintText: 'Search movies, series, channels…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  setState(() => _q = '');
                },
              ),
            ),
          ),
        ),
      ),
      body: _q.isEmpty ? const _Suggestions() : _Results(query: _q),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchProvider(query));
    return async.when(
      loading: () => ListView(children: const [SizedBox(height: 16), SkeletonRow(), SkeletonRow()]),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(searchProvider(query))),
      data: (r) {
        if (r.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No results for "$query"',
            message: 'Try a different spelling or a shorter search.',
          );
        }
        final w = context.isWide ? 160.0 : 124.0;
        final cw = context.isWide ? 210.0 : 160.0;
        return ListView(padding: const EdgeInsets.only(top: 16), children: [
          MediaRow(
            title: 'Channels',
            itemCount: r.channels.length,
            itemWidth: cw,
            height: cw * 10 / 16 + 44,
            itemBuilder: (_, i) => ChannelCard(item: r.channels[i]),
          ),
          MediaRow(
            title: 'Movies',
            itemCount: r.movies.length,
            itemWidth: w,
            height: w * 1.5 + 50,
            itemBuilder: (_, i) => PosterCard(item: r.movies[i]),
          ),
          MediaRow(
            title: 'Series',
            itemCount: r.series.length,
            itemWidth: w,
            height: w * 1.5 + 50,
            itemBuilder: (_, i) => PosterCard(item: r.series[i]),
          ),
        ]);
      },
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recommendationsProvider).value ?? const <MediaItem>[];
    if (recs.isEmpty) {
      return const EmptyState(
        icon: Icons.travel_explore_rounded,
        title: 'Find something to watch',
        message: 'Search across every channel, movie and series in your playlist.',
      );
    }
    final w = context.isWide ? 160.0 : 124.0;
    return ListView(padding: const EdgeInsets.only(top: 16), children: [
      MediaRow(
        title: 'Recommended for you',
        itemCount: recs.length,
        itemWidth: w,
        height: w * 1.5 + 50,
        itemBuilder: (_, i) => MediaCard(item: recs[i]),
      ),
    ]);
  }
}
