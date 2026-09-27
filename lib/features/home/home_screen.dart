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
import '../../widgets/media_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recommendationsProvider);
          ref.invalidate(historyProvider);
          ref.invalidate(homeProvider);
          await ref.read(homeProvider.future);
        },
        child: home.when(
          loading: () => const _HomeSkeleton(),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(homeProvider)),
          data: (data) => data.playlistId == null ? const _Onboarding() : _HomeContent(data: data),
        ),
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = context.isWide;
    final poster = wide ? 164.0 : 126.0;
    final posterHeight = poster * 1.5 + 56;
    final channel = wide ? 200.0 : 156.0;
    final becauseRows = ref.watch(becauseYouWatchedProvider);

    // Featured: best-rated first, then newest series/movies; needs artwork.
    final seen = <String>{};
    final heroItems = [...data.topRatedMovies, ...data.recentSeries, ...data.recentMovies]
        .where((m) => m.hasArtwork && seen.add(m.id))
        .take(6)
        .toList();

    void seeAll(int branch, {String? group, MediaKind kind = MediaKind.movie}) {
      if (group != null) ref.read(browseIntentProvider.notifier).set(kind, group);
      StatefulNavigationShell.maybeOf(context)?.goBranch(branch);
    }

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: SafeArea(bottom: false, child: _Greeting(data: data))),
      if (heroItems.isNotEmpty) SliverToBoxAdapter(child: HeroCarousel(items: heroItems)),
      if (data.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.hourglass_top_rounded,
            title: 'Your playlist is syncing',
            message: 'Channels, movies and series will appear here as soon as the import finishes. Pull to refresh.',
          ),
        ),
      SliverList.list(children: [
        const SizedBox(height: 24),
        // On wide screens the sidebar already shows continue-watching.
        if (!wide && data.continueWatching.isNotEmpty)
          MediaRow(
            title: 'Continue watching',
            itemCount: data.continueWatching.length,
            itemWidth: 250,
            height: 250 * 9 / 16 + 16,
            itemBuilder: (_, i) => ContinueCard(entry: data.continueWatching[i], width: 250),
          ),
        if (data.movieCount > 0)
          _CategoryBrowser(poster: poster, height: posterHeight, onSeeAll: (g) => seeAll(1, group: g)),
        for (final row in becauseRows)
          MediaRow(
            title: row.title,
            itemCount: row.items.length,
            itemWidth: poster,
            height: posterHeight,
            itemBuilder: (_, i) => MediaCard(item: row.items[i]),
          ),
        MediaRow(
          title: 'Live now',
          trailing: SeeAllButton(onTap: () => seeAll(3)),
          itemCount: data.liveChannels.length,
          itemWidth: channel,
          height: channel * 10 / 16 + 50,
          itemBuilder: (_, i) => ChannelCard(item: data.liveChannels[i]),
        ),
        MediaRow(
          title: 'Top rated',
          itemCount: data.topRatedMovies.length,
          itemWidth: poster,
          height: posterHeight,
          itemBuilder: (_, i) => PosterCard(item: data.topRatedMovies[i]),
        ),
        MediaRow(
          title: 'New movies',
          trailing: SeeAllButton(onTap: () => seeAll(1)),
          itemCount: data.recentMovies.length,
          itemWidth: poster,
          height: posterHeight,
          itemBuilder: (_, i) => PosterCard(item: data.recentMovies[i]),
        ),
        MediaRow(
          title: 'New series',
          trailing: SeeAllButton(onTap: () => seeAll(2)),
          itemCount: data.recentSeries.length,
          itemWidth: poster,
          height: posterHeight,
          itemBuilder: (_, i) => PosterCard(item: data.recentSeries[i]),
        ),
        const SizedBox(height: 24),
      ]),
    ]);
  }
}

/// Greeting + library counts. Phones also get the header actions here.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final wide = context.isWide;
    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePadding, wide ? 20 : 12, context.pagePadding - (wide ? 0 : 8), 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: (wide ? t.headlineSmall : t.titleLarge)),
            const SizedBox(height: 2),
            Text(
              '${data.channelCount} channels · ${data.movieCount} movies · ${data.seriesCount} series',
              style: t.bodySmall?.copyWith(color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const HeaderActions(),
      ]),
    );
  }
}

/// Featured carousel: rounded cards with a peek of the next one.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key, required this.items});
  final List<MediaItem> items;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  PageController? _page;
  Timer? _timer;
  int _index = 0;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_hover || _page == null || !_page!.hasClients || widget.items.length < 2) return;
      _go((_index + 1) % widget.items.length);
    });
  }

  void _go(int i) => _page?.animateToPage(i, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);

  @override
  void dispose() {
    _timer?.cancel();
    _page?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final pad = context.pagePadding;
    return LayoutBuilder(builder: (context, c) {
      final fraction = wide ? 0.8 : 0.9;
      _page ??= PageController(viewportFraction: fraction);
      final cardWidth = (c.maxWidth - pad) * fraction - 16;
      final height = (cardWidth * (wide ? 0.44 : 0.62)).clamp(240.0, 430.0);
      return MouseRegion(
        onEnter: (_) => _hover = true,
        onExit: (_) => _hover = false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.only(left: pad),
              child: PageView.builder(
                controller: _page,
                padEnds: false,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: HeroCard(item: widget.items[i], compact: !wide),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: pad),
            child: Row(children: [
              for (var i = 0; i < widget.items.length; i++)
                GestureDetector(
                  onTap: () => _go(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == _index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.text : AppColors.outline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      );
    });
  }
}

/// Category pills ("For you", "Action", …) driving the row beneath them.
class _CategoryBrowser extends ConsumerStatefulWidget {
  const _CategoryBrowser({required this.poster, required this.height, required this.onSeeAll});
  final double poster;
  final double height;
  final ValueChanged<String?> onSeeAll;

  @override
  ConsumerState<_CategoryBrowser> createState() => _CategoryBrowserState();
}

class _CategoryBrowserState extends ConsumerState<_CategoryBrowser> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider(MediaKind.movie)).value?.names ?? const <String>[];
    final labels = ['For you', ...cats];
    if (_selected >= labels.length) _selected = 0;
    final group = _selected == 0 ? null : labels[_selected];

    final List<MediaItem> items;
    final bool loading;
    if (group == null) {
      final recs = ref.watch(recommendationsProvider);
      items = ref.watch(forYouProvider);
      loading = recs.isLoading;
    } else {
      final row = ref.watch(categoryRowProvider(group));
      items = row.value ?? const [];
      loading = row.isLoading;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ChipStrip(labels: labels, selected: _selected, onSelect: (i) => setState(() => _selected = i)),
        const SizedBox(height: 14),
        if (loading && items.isEmpty)
          SkeletonRow(itemWidth: widget.poster)
        else if (items.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(context.pagePadding, 8, context.pagePadding, 20),
            child: Text(
              group == null
                  ? 'Watch a few titles and personalised picks will appear here.'
                  : 'Nothing in $group yet.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          )
        else
          MediaRow(
            title: group ?? 'Recommended for you',
            subtitle: group == null ? 'Based on what you watch' : null,
            trailing: SeeAllButton(onTap: () => widget.onSeeAll(group)),
            itemCount: items.length,
            itemWidth: widget.poster,
            height: widget.height,
            itemBuilder: (_, i) => MediaCard(item: items[i]),
          ),
      ]),
    );
  }
}

class _Onboarding extends StatelessWidget {
  const _Onboarding();

  @override
  Widget build(BuildContext context) => CustomScrollView(slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(
            child: Column(children: [
              const Align(alignment: Alignment.topRight, child: HeaderActions()),
              Expanded(
                child: EmptyState(
                  icon: Icons.playlist_add_rounded,
                  title: 'Add your first playlist',
                  message: 'Connect an Xtream Codes account or an M3U link to start watching live TV, movies and series.',
                  action: GradientButton(
                    label: 'Add playlist',
                    icon: Icons.add_rounded,
                    onPressed: () => context.push('/settings/add-playlist'),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]);
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: 24),
      children: [
        Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const Skeleton(width: 220, height: 28)),
        const SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.only(left: pad),
          child: Skeleton(height: context.isWide ? 380 : 260, radius: Radii.hero),
        ),
        const SizedBox(height: 32),
        const SkeletonRow(),
        const SkeletonRow(),
      ],
    );
  }
}
