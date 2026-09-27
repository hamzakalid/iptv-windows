import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/media_row.dart';
import '../../widgets/nocturne.dart';
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

/// Card sizes: the design's desktop widths, a little smaller on phones.
({double poster, double wide, double live}) _sizes(BuildContext context) =>
    context.isWide ? (poster: 150.0, wide: 280.0, live: 260.0) : (poster: 120.0, wide: 240.0, live: 240.0);

/// Poster (2:3 + title + meta) row height, including the scroller padding.
double _posterRowHeight(double w) => w * 1.5 + 54;

/// Library fallback for the hero when `/home/featured` has nothing: three
/// best-rated movies and two newest series (with artwork), topped up.
List<FeaturedItem> _libraryFeatured(HomeData data) {
  final seen = <String>{};
  final out = <MediaItem>[];
  void take(Iterable<MediaItem> from, int n) {
    for (final m in from.where((m) => m.hasArtwork && !seen.contains(m.id)).take(n)) {
      seen.add(m.id);
      out.add(m);
    }
  }

  take(data.topRatedMovies, 3);
  take(data.recentSeries, 2);
  take([...data.topRatedMovies, ...data.recentSeries, ...data.recentMovies], 5 - out.length);
  return out.map(FeaturedItem.fromMedia).toList();
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = _sizes(context);
    final becauseRows = ref.watch(becauseYouWatchedProvider);
    final featured = ref.watch(featuredProvider);
    final suggestions = ref.watch(suggestionsProvider).value;
    final actors = ref.watch(topActorsProvider).value ?? const <Actor>[];

    // Trending-on-the-internet titles that exist in the catalogue lead the
    // hero; library picks stand in while they load or when TMDB is off.
    final trending = featured.value?.items ?? const <FeaturedItem>[];
    final hero = trending.isNotEmpty ? trending : _libraryFeatured(data);

    Widget posters(List<MediaItem> items) => _Row(
          height: _posterRowHeight(s.poster),
          arrowInset: 46,
          itemCount: items.length,
          itemBuilder: (_, i) => PosterCard(item: items[i], width: s.poster),
        );

    Widget noted(List<(MediaItem, String?)> items) => _Row(
          height: _posterRowHeight(s.poster) + 16,
          arrowInset: 62,
          itemCount: items.length,
          itemBuilder: (_, i) => _NotedPoster(item: items[i].$1, note: items[i].$2, width: s.poster),
        );

    final fresh = suggestions?.newArrivals ?? const <Suggestion>[];
    final mostWatched = suggestions?.mostWatched ?? const <MostWatched>[];

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: SafeArea(bottom: false, child: _Header(data: data))),
      if (hero.isNotEmpty) SliverToBoxAdapter(child: _Hero(items: hero, trending: trending.isNotEmpty)),
      if (data.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Ph.hourglass,
            title: 'Your playlist is syncing',
            message: 'Channels, movies and series will appear here as soon as the import finishes. Pull to refresh.',
          ),
        ),
      SliverList.list(children: [
        if (data.continueWatching.isNotEmpty) ...[
          RowHeading('Continue watching', action: 'History', onAction: () => context.go('/library?tab=history')),
          _Row(
            height: s.wide * 9 / 16 + 50,
            arrowInset: 46,
            itemCount: data.continueWatching.length,
            itemBuilder: (_, i) => ContinueCard(entry: data.continueWatching[i], width: s.wide),
          ),
        ],
        if (data.movieCount > 0) _GenreSection(poster: s.poster),
        if (fresh.isNotEmpty) ...[
          RowHeading('New for you',
              note: suggestions!.isPersonalised
                  ? 'Newest across your playlists, closest to your taste first'
                  : 'Newest across your playlists'),
          noted([for (final x in fresh) (x.item, x.reason)]),
        ],
        if (mostWatched.isNotEmpty) ...[
          RowHeading('Your most watched', note: 'By time watched, across all your playlists'),
          noted([for (final x in mostWatched) (x.item, x.label)]),
        ],
        if (data.liveChannels.isNotEmpty) ...[
          RowHeading('Live now', action: 'Guide', onAction: () => context.go('/live')),
          _Row(
            height: 80,
            itemCount: data.liveChannels.length,
            itemBuilder: (_, i) => LiveNowTile(item: data.liveChannels[i], width: s.live),
          ),
        ],
        for (final row in becauseRows) ...[
          RowHeading(row.title),
          posters(row.items),
        ],
        if (data.topRatedMovies.isNotEmpty) ...[
          RowHeading('Top rated', action: 'See all', onAction: () {
            ref.read(browseIntentProvider.notifier).set(MediaKind.movie, null, sort: SortOption.rating);
            context.go('/movies');
          }),
          posters(data.topRatedMovies),
        ],
        if (data.recentSeries.isNotEmpty) ...[
          RowHeading('New series', action: 'See all', onAction: () => context.go('/series')),
          posters(data.recentSeries),
        ],
        if (actors.isNotEmpty) ...[
          RowHeading('Actors in your library', action: 'See all', onAction: () => context.go('/actors')),
          _Row(
            height: ActorCard.heightFor(110) + 8,
            arrowInset: 56,
            itemCount: actors.length,
            itemBuilder: (_, i) => SizedBox(height: ActorCard.heightFor(110), child: ActorCard(actor: actors[i], width: 110)),
          ),
        ],
        const SizedBox(height: 32),
      ]),
    ]);
  }
}

/// A horizontal card row with the design's 2/24/6 padding and 14 gap.
class _Row extends StatelessWidget {
  const _Row({required this.height, required this.itemCount, required this.itemBuilder, this.arrowInset = 0});
  final double height;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double arrowInset;

  @override
  Widget build(BuildContext context) => ArrowScroller(
        height: height,
        itemCount: itemCount,
        arrowInset: arrowInset,
        padding: EdgeInsets.fromLTRB(context.pagePadding, 2, context.pagePadding, 6),
        itemBuilder: (c, i) => Align(alignment: Alignment.topLeft, child: itemBuilder(c, i)),
      );
}

/// Poster card with an extra muted line: why it was suggested, or how much
/// of it was watched.
class _NotedPoster extends StatelessWidget {
  const _NotedPoster({required this.item, required this.note, required this.width});
  final MediaItem item;
  final String? note;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          PosterCard(item: item, width: width),
          if (note != null && note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.a400)),
            ),
        ]),
      );
}

/// Greeting + library counts, the search field and "What's new".
/// Phones swap the search field for the compact header actions.
class _Header extends ConsumerWidget {
  const _Header({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final wide = context.isWide;
    final pad = context.pagePadding;
    final playlist = ref.watch(playlistsProvider).value?.where((p) => p.id == data.playlistId).firstOrNull?.name;
    final caption = [
      '${formatCount(data.channelCount)} channels',
      '${formatCount(data.movieCount)} movies',
      '${formatCount(data.seriesCount)} series',
      ?playlist,
    ].join(' · ');
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, wide ? 20 : 12, pad - (wide ? 0 : 8), 14),
      child: Row(crossAxisAlignment: wide ? CrossAxisAlignment.end : CrossAxisAlignment.center, children: [
        Expanded(child: PageTitle(greeting, caption: caption)),
        const SizedBox(width: 16),
        if (wide) ...[
          const _SearchButton(),
          const SizedBox(width: 16),
          const WhatsNewButton(),
        ] else
          const HeaderActions(),
      ]),
    );
  }
}

/// Secondary button styled as a search field; opens Search.
class _SearchButton extends ConsumerWidget {
  const _SearchButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Tappable(
        onTap: () => goSearch(context, ref),
        child: Container(
          height: 36,
          constraints: const BoxConstraints(minWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Ph.magnifyingGlass, size: 16, color: AppColors.n500),
            SizedBox(width: 6),
            Text('Search movies, series, channels', style: TextStyle(fontSize: 14, color: AppColors.n500)),
            SizedBox(width: 12),
            KeyCap('/'),
          ]),
        ),
      );
}

/// Featured hero: TMDB backdrop with a readable scrim, copy bottom-left, the
/// TMDB poster and prev/next + dots bottom-right. Advances every 8 s.
class _Hero extends ConsumerStatefulWidget {
  const _Hero({required this.items, required this.trending});
  final List<FeaturedItem> items;

  /// Whether the slides come from what's trending (vs. library picks).
  final bool trending;

  @override
  ConsumerState<_Hero> createState() => _HeroState();
}

class _HeroState extends ConsumerState<_Hero> {
  Timer? _timer;
  int _index = 0;

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
      if (mounted && widget.items.length > 1) setState(() => _index = (_index + 1) % widget.items.length);
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
    final items = widget.items;
    if (_index >= items.length) _index = 0;
    final slide = items[_index];
    final item = slide.item;
    final wide = context.isWide;
    final pad = context.pagePadding;
    ref.watch(favoritesProvider);
    final saved = ref.read(favoritesProvider.notifier).contains(item.id);

    final dots = Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _go(i),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: i == _index ? 22 : 8,
              height: 4,
              decoration: BoxDecoration(
                color: i == _index ? AppColors.accent : AppColors.n700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    ]);

    final copy = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: _HeroCopy(slide: slide, saved: saved, compact: !wide),
    );

    final poster = slide.poster;
    final showPoster = wide && context.isExpanded && poster != null && poster.startsWith('http');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 200) _go(_index + (v < 0 ? 1 : -1));
        },
        child: Container(
          height: wide ? 400 : 380,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            gradient: const RadialGradient(
              center: Alignment(0.56, -0.6),
              radius: 1.2,
              colors: [AppColors.n800, AppColors.n900, AppColors.bg],
              stops: [0, 0.55, 1],
            ),
          ),
          child: Stack(fit: StackFit.expand, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _Backdrop(key: ValueKey('${item.id}:${slide.backdrop}'), url: slide.backdrop),
            ),
            const _Scrim(),
            Positioned(
              left: wide ? 32 : 16,
              right: wide ? 32 : 16,
              bottom: wide ? 28 : 18,
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: Align(alignment: Alignment.bottomLeft, child: _fade(slide, copy))),
                      const SizedBox(width: 24),
                      if (showPoster) ...[
                        _fade(slide, _HeroPoster(url: poster, label: slide.title, onTap: () => openItem(context, item))),
                        const SizedBox(width: 24),
                      ],
                      if (items.length > 1)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          NocIconButton(
                              icon: Ph.caretLeft, iconSize: 18, tooltip: 'Previous', onPressed: () => _go(_index - 1)),
                          const SizedBox(width: 6),
                          dots,
                          const SizedBox(width: 6),
                          NocIconButton(
                              icon: Ph.caretRight, iconSize: 18, tooltip: 'Next', onPressed: () => _go(_index + 1)),
                        ]),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      _fade(slide, copy),
                      if (items.length > 1) ...[const SizedBox(height: 14), dots],
                    ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _fade(FeaturedItem slide, Widget child) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        layoutBuilder: (current, previous) =>
            Stack(alignment: Alignment.bottomLeft, children: [...previous, ?current]),
        child: KeyedSubtree(key: ValueKey(slide.item.id), child: child),
      );
}

/// The TMDB poster shown beside the copy on expanded layouts.
class _HeroPoster extends StatelessWidget {
  const _HeroPoster({required this.url, required this.label, required this.onTap});
  final String url;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => HoverRing(
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

/// Backdrop art; while loading or on failure the hero's radial gradient
/// shows through.
class _Backdrop extends StatelessWidget {
  const _Backdrop({super.key, required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || !url!.startsWith('http')) return const SizedBox.expand();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      alignment: const Alignment(0.5, -0.4),
      memCacheWidth: 1600,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => const SizedBox.expand(),
      errorWidget: (_, _, _) => const SizedBox.expand(),
    );
  }
}

/// Darkens the left and bottom of the hero so the copy stays legible.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.bg.withValues(alpha: 0.92),
                AppColors.bg.withValues(alpha: 0.55),
                AppColors.bg.withValues(alpha: 0),
              ], stops: const [0, 0.45, 0.85]),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.bg.withValues(alpha: 0.9), AppColors.bg.withValues(alpha: 0)],
                stops: const [0, 0.6],
              ),
            ),
          ),
        ]),
      );
}

/// Tags, title, meta line, plot and actions for the featured title.
class _HeroCopy extends ConsumerWidget {
  const _HeroCopy({required this.slide, required this.saved, required this.compact});
  final FeaturedItem slide;
  final bool saved;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = slide.item;
    final tags = [item.kind.label, ...item.genres.take(3)];
    final rating = slide.rating;
    final seasons = item.seasonCount;
    final meta = <Widget>[
      if (rating != null && rating > 0)
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(PhF.star, size: 13, color: AppColors.a300),
          const SizedBox(width: 4),
          Text(rating.toStringAsFixed(1), style: const TextStyle(color: AppColors.a300)),
          if (slide.isTrending && (slide.voteCount ?? 0) >= 100)
            Text(' · ${formatCount(slide.voteCount!)} votes', style: const TextStyle(color: AppColors.n500)),
        ]),
      if (slide.year != null) Text('${slide.year}'),
      if (item.kind == MediaKind.movie && (item.durationSecs ?? 0) > 0)
        Text(formatDuration(item.durationSecs))
      else if (item.kind == MediaKind.series && seasons != null)
        Text('$seasons season${seasons == 1 ? '' : 's'}'),
    ];
    final plot = slide.plot;
    const gap = SizedBox(height: 10);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        if (slide.isTrending) const NocTag('Trending now', kind: TagKind.accent, icon: Ph.fire),
        for (final t in tags) NocTag(t),
      ]),
      gap,
      Text(slide.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: compact ? NocText.h3 : NocText.h1),
      if (meta.isNotEmpty) ...[
        gap,
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13, color: AppColors.n300),
          child: Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: meta),
        ),
      ],
      if ((plot ?? '').isNotEmpty) ...[
        gap,
        Text(plot!,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.n300)),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        NocButton.primary(label: 'Play', icon: PhF.play, height: 38, onPressed: () => playItem(context, item)),
        NocButton(
          label: saved ? 'In My List' : 'My List',
          icon: saved ? PhF.bookmarkSimple : Ph.bookmarkSimple,
          height: 38,
          onPressed: () => toggleSaved(context, ref, item),
        ),
        NocButton.ghost(
          label: 'Details',
          height: 38,
          fontSize: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          onPressed: () => openItem(context, item),
        ),
      ]),
    ]);
  }
}

/// Pills driving the poster row beneath: "For you" (user-level suggestions,
/// independent of the active playlist) followed by the IPTV account's movie
/// categories in the provider's order.
class _GenreSection extends ConsumerStatefulWidget {
  const _GenreSection({required this.poster});
  final double poster;

  @override
  ConsumerState<_GenreSection> createState() => _GenreSectionState();
}

class _GenreSectionState extends ConsumerState<_GenreSection> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final cats = ref.watch(categoriesProvider(MediaKind.movie)).value;
    final names = cats?.ordered ?? const <String>[];
    final labels = ['For you', ...names];
    if (_selected >= labels.length) _selected = 0;
    final group = _selected == 0 ? null : labels[_selected];

    final List<(MediaItem, String?)> items;
    final bool loading;
    String? note;
    if (group == null) {
      final sug = ref.watch(suggestionsProvider);
      final byId = {for (final s in sug.value?.suggested ?? const <Suggestion>[]) s.item.id: s.reason};
      items = [for (final m in ref.watch(forYouProvider)) (m, byId[m.id])];
      loading = sug.isLoading;
      note = sug.value?.basisLabel ?? (items.isEmpty ? null : 'Top picks from your library');
    } else {
      final row = ref.watch(categoryRowProvider(group));
      items = [for (final m in row.value ?? const <MediaItem>[]) (m, null)];
      loading = row.isLoading;
      final n = cats?.countFor(group);
      note = n == null ? null : '${formatCount(n)} title${n == 1 ? '' : 's'}';
    }

    void seeAll() {
      ref.read(browseIntentProvider.notifier).set(MediaKind.movie, group);
      context.go('/movies');
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 10),
        child: ArrowScroller(
          height: 32,
          separator: 6,
          itemCount: labels.length,
          padding: EdgeInsets.symmetric(horizontal: pad),
          itemBuilder: (_, i) => Center(
            child: Pill(labels[i],
                icon: i == 0 ? Ph.sparkle : null,
                selected: i == _selected,
                onTap: () => setState(() => _selected = i)),
          ),
        ),
      ),
      RowHeading(
        group ?? 'Suggested for you',
        note: note,
        action: 'See all',
        onAction: seeAll,
        padding: EdgeInsets.fromLTRB(pad, 4, pad, 10),
      ),
      if (loading && items.isEmpty)
        SizedBox(
          height: _posterRowHeight(widget.poster),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad, 2, pad, 6),
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, _) => Align(
              alignment: Alignment.topLeft,
              child: Skeleton(width: widget.poster, height: widget.poster * 1.5),
            ),
          ),
        )
      else if (items.isEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 20),
          child: Text(
            group == null ? 'Watch a few titles and personalised picks will appear here.' : 'Nothing in $group yet.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        )
      else
        _Row(
          height: _posterRowHeight(widget.poster) + (group == null ? 16 : 0),
          arrowInset: group == null ? 62 : 46,
          itemCount: items.length,
          itemBuilder: (_, i) => group == null
              ? _NotedPoster(item: items[i].$1, note: items[i].$2, width: widget.poster)
              : PosterCard(item: items[i].$1, width: widget.poster),
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
                  icon: Ph.playlist,
                  title: 'Add your first playlist',
                  message: 'Connect an Xtream Codes account or an M3U link to start watching live TV, movies and series.',
                  action: NocButton.primary(
                    label: 'Add playlist',
                    icon: Ph.plus,
                    height: 38,
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
    final wide = context.isWide;
    final s = _sizes(context);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: wide ? 20 : 12),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Skeleton(width: 220, height: 28),
            SizedBox(height: 6),
            Skeleton(width: 280, height: 14),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Skeleton(height: wide ? 400 : 380, radius: Radii.lg),
        ),
        const SizedBox(height: 28),
        SkeletonRow(itemWidth: s.wide, aspect: 16 / 9),
        SkeletonRow(itemWidth: s.poster),
      ],
    );
  }
}
