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
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../actors/actors_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(suggestionsProvider);
          ref.invalidate(featuredProvider);
          ref.invalidate(topActorsProvider);
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

double _posterWidth(BuildContext context) => context.isWide ? 150 : 116;
double _posterRowHeight(BuildContext context) => _posterWidth(context) * 1.5 + posterCaptionHeight + 8;

/// Extra line under a poster for a suggestion reason or watch time.
const _noteHeight = 16.0;

/// Library fallback for the hero when `/home/featured` has nothing yet:
/// best-rated first, then the newest series and movies, preferring artwork.
List<FeaturedItem> _libraryFeatured(HomeData data) {
  final seen = <String>{};
  final candidates = [...data.topRatedMovies, ...data.recentSeries, ...data.recentMovies]
      .where((m) => seen.add(m.id))
      .toList();
  final withArt = candidates.where((m) => m.hasArtwork).take(5).toList();
  return (withArt.isNotEmpty ? withArt : candidates.take(5)).map(FeaturedItem.fromMedia).toList();
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = _posterWidth(context);
    final posterHeight = _posterRowHeight(context);
    final becauseRows = ref.watch(becauseYouWatchedProvider);
    final suggestions = ref.watch(suggestionsProvider).value;
    final actors = ref.watch(topActorsProvider).value ?? const <Actor>[];
    final shell = StatefulNavigationShell.maybeOf(context);

    // Titles trending on the internet that exist in the catalogue lead the
    // hero; library picks stand in while they load or when TMDB is off.
    final trending = ref.watch(featuredProvider).value?.items ?? const <FeaturedItem>[];
    final heroItems = trending.isNotEmpty ? trending : _libraryFeatured(data);

    void seeAll(int branch, {String? group, MediaKind kind = MediaKind.movie}) {
      if (group != null) ref.read(browseIntentProvider.notifier).set(kind, group);
      shell?.goBranch(branch);
    }

    Widget posters(String title, List<MediaItem> items, {VoidCallback? onSeeAll}) => MediaRow(
          title: title,
          trailing: onSeeAll == null ? null : RowAction('See all', onTap: onSeeAll),
          itemCount: items.length,
          itemWidth: poster,
          height: posterHeight,
          itemBuilder: (_, i) => MediaCard(item: items[i]),
        );

    Widget noted(String title, List<(MediaItem, String?)> items, {String? subtitle}) => MediaRow(
          title: title,
          subtitle: subtitle,
          itemCount: items.length,
          itemWidth: poster,
          height: posterHeight + _noteHeight,
          arrowInset: 44 + _noteHeight,
          itemBuilder: (_, i) => NotedPoster(item: items[i].$1, note: items[i].$2),
        );

    final fresh = suggestions?.newArrivals ?? const <Suggestion>[];
    final mostWatched = suggestions?.mostWatched ?? const <MostWatched>[];

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: SafeArea(bottom: false, child: _Header(data: data))),
      if (heroItems.isNotEmpty) SliverToBoxAdapter(child: _Hero(items: heroItems, trending: trending.isNotEmpty)),
      if (data.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: PhosphorIconsRegular.hourglassMedium,
            title: 'Your playlist is syncing',
            message: 'Channels, movies and series appear here as soon as the import finishes. Pull to refresh.',
          ),
        ),
      SliverList.list(children: [
        const SizedBox(height: 28),
        if (data.continueWatching.isNotEmpty)
          MediaRow(
            title: 'Continue watching',
            trailing: RowAction('History', onTap: () => context.go('/library?tab=history')),
            itemCount: data.continueWatching.length,
            itemWidth: 280,
            height: 280 * 9 / 16 + posterCaptionHeight + 8,
            itemBuilder: (_, i) => ContinueCard(entry: data.continueWatching[i]),
          ),
        if (data.movieCount > 0)
          _GenreBrowser(poster: poster, height: posterHeight, onSeeAll: (g) => seeAll(1, group: g)),
        if (fresh.isNotEmpty)
          noted(
            'New for you',
            [for (final x in fresh) (x.item, x.reason)],
            subtitle: suggestions!.isPersonalised
                ? 'Newest across your playlists, closest to your taste first'
                : 'Newest across your playlists',
          ),
        if (mostWatched.isNotEmpty)
          noted('Your most watched', [for (final x in mostWatched) (x.item, x.label)],
              subtitle: 'By time watched, across all your playlists'),
        for (final row in becauseRows) posters(row.title, row.items),
        if (data.liveChannels.isNotEmpty)
          MediaRow(
            title: 'Live now',
            trailing: RowAction('Guide', onTap: () => seeAll(3)),
            itemCount: data.liveChannels.length,
            itemWidth: 260,
            height: 76,
            arrowInset: 0,
            itemBuilder: (_, i) => LiveNowCard(item: data.liveChannels[i]),
          ),
        posters('Top rated', data.topRatedMovies, onSeeAll: () => seeAll(1)),
        posters('New movies', data.recentMovies, onSeeAll: () => seeAll(1)),
        posters('New series', data.recentSeries, onSeeAll: () => seeAll(2)),
        if (actors.isNotEmpty)
          MediaRow(
            title: 'Actors in your library',
            trailing: RowAction('See all', onTap: () => shell?.goBranch(actorsBranch)),
            itemCount: actors.length,
            itemWidth: 110,
            height: ActorCard.heightFor(110) + 8,
            arrowInset: 56,
            itemBuilder: (_, i) => ActorCard(actor: actors[i]),
          ),
        const SizedBox(height: 12),
      ]),
    ]);
  }
}

/// Poster card with an extra muted line: why it was suggested, or how much
/// of it was watched.
class NotedPoster extends StatelessWidget {
  const NotedPoster({super.key, required this.item, required this.note});
  final MediaItem item;
  final String? note;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        PosterCard(item: item),
        if (note != null && note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.accent400)),
          ),
      ]);
}

/// Greeting, library counts, the "/" search affordance and the bell.
class _Header extends ConsumerWidget {
  const _Header({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final wide = context.isWide;
    final pad = context.pagePadding;
    final playlists = ref.watch(playlistsProvider).value ?? const <Playlist>[];
    final playlist = playlists.where((p) => p.id == data.playlistId).firstOrNull?.name;
    final counts = [
      '${formatCount(data.channelCount)} channels',
      '${formatCount(data.movieCount)} movies',
      '${formatCount(data.seriesCount)} series',
      ?playlist,
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, wide ? 20 : 12, wide ? pad : 8, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: wide ? AppText.h3 : AppText.h4),
            const SizedBox(height: 4),
            Text(counts, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.meta),
          ]),
        ),
        if (wide) ...[
          const SizedBox(width: 16),
          _SearchButton(onTap: () {
            StatefulNavigationShell.maybeOf(context)?.goBranch(searchBranch);
            WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(searchFocusProvider).requestFocus());
          }),
          const SizedBox(width: 8),
          const WhatsNewButton(),
        ] else
          const HeaderActions(),
      ]),
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 280,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.neutral500,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          ),
          child: const Row(children: [
            Icon(PhosphorIconsRegular.magnifyingGlass, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text('Search movies, series, channels')),
            SizedBox(width: 8),
            Kbd('/'),
          ]),
        ),
      );
}

/// Featured title on a rounded backdrop (TMDB art when the slide is a
/// trending match); rotates every 8 s unless hovered.
class _Hero extends StatefulWidget {
  const _Hero({required this.items, required this.trending});
  final List<FeaturedItem> items;

  /// Whether the slides come from what's trending (vs. library picks).
  final bool trending;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  Timer? _timer;
  int _index = 0;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(_Hero old) {
    super.didUpdateWidget(old);
    // Library picks → trending titles: start the new deck from the top.
    if (old.trending != widget.trending) _go(0);
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!_hover && widget.items.length > 1) setState(() => _index = (_index + 1) % widget.items.length);
    });
  }

  void _go(int i) {
    final n = widget.items.length;
    setState(() => _index = n == 0 ? 0 : (i % n + n) % n);
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final slide = widget.items[_index.clamp(0, widget.items.length - 1)];
    final item = slide.item;
    final poster = slide.poster;
    final showPoster = context.isExpanded && slide.isTrending && poster != null && poster.startsWith('http');

    return MouseRegion(
      onEnter: (_) => _hover = true,
      onExit: (_) => _hover = false,
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 200) _go(_index + (v < 0 ? 1 : -1));
        },
        child: Container(
          height: wide ? 400 : 320,
          margin: EdgeInsets.symmetric(horizontal: context.pagePadding),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.lg)),
          child: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.56, -0.6),
                  radius: 1.2,
                  colors: [AppColors.neutral800, AppColors.neutral900, AppColors.bg],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: KeyedSubtree(
                key: ValueKey('${item.id}:${slide.backdrop}'),
                child: Stack(fit: StackFit.expand, children: [
                  NetImage(slide.backdrop, label: slide.title, labelSize: 0, lighten: true, memCacheWidth: 1600),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.bg.withValues(alpha: 0.92), AppColors.bg.withValues(alpha: 0)],
                        stops: const [0, 0.7],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.bg.withValues(alpha: 0), AppColors.bg.withValues(alpha: 0.85)],
                        stops: const [0.35, 1],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Positioned(
              left: wide ? 32 : 18,
              right: wide ? 32 : 18,
              bottom: wide ? 28 : 18,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.bottomLeft, children: [...previous, ?current]),
                    child: _HeroCopy(key: ValueKey(item.id), slide: slide),
                  ),
                ),
                if (showPoster) ...[
                  const SizedBox(width: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _HeroPoster(key: ValueKey(poster), url: poster, label: slide.title, onTap: () => openItem(context, item)),
                  ),
                ],
                if (widget.items.length > 1 && wide) ...[
                  const SizedBox(width: 24),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Previous',
                      onPressed: () => _go(_index - 1),
                      icon: const Icon(PhosphorIconsRegular.caretLeft, size: 18),
                    ),
                    for (var i = 0; i < widget.items.length; i++)
                      GestureDetector(
                        onTap: () => _go(i),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _index ? 22 : 8,
                            height: 4,
                            decoration: BoxDecoration(
                              color: i == _index ? AppColors.accent : AppColors.neutral700,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Next',
                      onPressed: () => _go(_index + 1),
                      icon: const Icon(PhosphorIconsRegular.caretRight, size: 18),
                    ),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The TMDB poster shown beside the copy on expanded layouts.
class _HeroPoster extends StatelessWidget {
  const _HeroPoster({super.key, required this.url, required this.label, required this.onTap});
  final String url;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        child: Container(
          width: 150,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.md), boxShadow: Shadows.md),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: AspectRatio(aspectRatio: 2 / 3, child: NetImage(url, label: label, memCacheWidth: 400)),
          ),
        ),
      );
}

class _HeroCopy extends ConsumerWidget {
  const _HeroCopy({super.key, required this.slide});
  final FeaturedItem slide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = slide.item;
    ref.watch(favoritesProvider);
    final saved = ref.read(favoritesProvider.notifier).contains(item.id);
    final wide = context.isWide;
    final tags = <String>{item.kind.label, ...item.genres.take(2)}.toList();
    final seasons = item.seasonCount;
    final meta = [
      if (slide.year != null) '${slide.year}',
      if (item.kind == MediaKind.movie && item.durationSecs != null && item.durationSecs! > 0)
        formatDuration(item.durationSecs)
      else if (item.kind == MediaKind.series && seasons != null)
        '$seasons season${seasons == 1 ? '' : 's'}',
    ];
    final rating = slide.rating;
    final plot = slide.plot;
    const buttonSize = Size(0, 38);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (slide.isTrending) const Tag('Trending now', tone: TagTone.accent, icon: PhosphorIconsRegular.fire),
          for (final t in tags) Tag(t),
        ]),
        const SizedBox(height: 10),
        Text(slide.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: wide ? AppText.h1 : AppText.h3),
        const SizedBox(height: 10),
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13, color: AppColors.neutral300),
          child: Row(children: [
            if (rating != null && rating > 0) ...[
              StarRating(rating),
              if (slide.isTrending && (slide.voteCount ?? 0) >= 100)
                Text(' · ${formatCount(slide.voteCount!)} votes', style: const TextStyle(color: AppColors.neutral500)),
              const SizedBox(width: 10),
            ],
            for (final m in meta) ...[Text(m), const SizedBox(width: 10)],
          ]),
        ),
        if (plot != null && plot.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(plot,
              maxLines: wide ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.neutral300)),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: buttonSize, padding: const EdgeInsets.symmetric(horizontal: 16)),
            onPressed: () => playItem(context, item),
            icon: const Icon(PhosphorIconsFill.play),
            label: Text(item.kind == MediaKind.movie ? 'Play' : 'Watch'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: buttonSize),
            onPressed: () => toggleSaved(context, ref, item),
            icon: Icon(saved ? PhosphorIconsFill.bookmarkSimple : PhosphorIconsRegular.bookmarkSimple),
            label: Text(saved ? 'In My List' : 'My List'),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: buttonSize, padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: () => openItem(context, item),
            child: const Text('Details'),
          ),
        ]),
      ]),
    );
  }
}

/// Chips driving the row beneath: "For you" (user-level suggestions,
/// independent of the active playlist) then the IPTV account's movie
/// categories in the provider's order.
class _GenreBrowser extends ConsumerStatefulWidget {
  const _GenreBrowser({required this.poster, required this.height, required this.onSeeAll});
  final double poster;
  final double height;
  final ValueChanged<String?> onSeeAll;

  @override
  ConsumerState<_GenreBrowser> createState() => _GenreBrowserState();
}

class _GenreBrowserState extends ConsumerState<_GenreBrowser> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider(MediaKind.movie)).value;
    final labels = ['For you', ...?cats?.ordered];
    if (_selected >= labels.length) _selected = 0;
    final group = _selected == 0 ? null : labels[_selected];

    final List<(MediaItem, String?)> items;
    final bool loading;
    String? subtitle;
    if (group == null) {
      final sug = ref.watch(suggestionsProvider);
      final byId = {for (final s in sug.value?.suggested ?? const <Suggestion>[]) s.item.id: s.reason};
      items = [for (final m in ref.watch(forYouProvider)) (m, byId[m.id])];
      loading = sug.isLoading;
      subtitle = sug.value?.basisLabel ?? 'Based on what you watch';
    } else {
      final row = ref.watch(categoryRowProvider(group));
      items = [for (final m in row.value ?? const <MediaItem>[]) (m, null)];
      loading = row.isLoading;
      final n = cats?.countFor(group);
      subtitle = n == null ? null : '${formatCount(n)} title${n == 1 ? '' : 's'}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ChipStrip(labels: labels, selected: _selected, onSelect: (i) => setState(() => _selected = i)),
      const SizedBox(height: 12),
      if (loading && items.isEmpty)
        SkeletonRow(itemWidth: widget.poster)
      else if (items.isEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, 28),
          child: Text(
            group == null ? 'Watch a few titles and personalised picks will appear here.' : 'Nothing in $group yet.',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        )
      else
        MediaRow(
          title: group ?? 'Suggested for you',
          subtitle: subtitle,
          trailing: RowAction('See all', onTap: () => widget.onSeeAll(group)),
          itemCount: items.length,
          itemWidth: widget.poster,
          height: widget.height + (group == null ? _noteHeight : 0),
          arrowInset: 44 + (group == null ? _noteHeight : 0),
          itemBuilder: (_, i) =>
              group == null ? NotedPoster(item: items[i].$1, note: items[i].$2) : MediaCard(item: items[i].$1),
        ),
    ]);
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
                  icon: PhosphorIconsRegular.playlist,
                  title: 'Add your first playlist',
                  message: 'Connect an Xtream Codes account or an M3U link to start watching live TV, movies and series.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/settings/add-playlist'),
                    icon: const Icon(PhosphorIconsRegular.plus),
                    label: const Text('Add playlist'),
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
      padding: const EdgeInsets.only(top: 24),
      children: [
        Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: const Skeleton(width: 220, height: 26, radius: Radii.sm)),
        const SizedBox(height: 22),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Skeleton(height: context.isWide ? 400 : 320, radius: Radii.lg),
        ),
        const SizedBox(height: 32),
        SkeletonRow(itemWidth: _posterWidth(context)),
        SkeletonRow(itemWidth: _posterWidth(context)),
      ],
    );
  }
}
