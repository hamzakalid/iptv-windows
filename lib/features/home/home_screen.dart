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
import '../player/player_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeProvider.future),
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
    final recs = ref.watch(recommendationsProvider).value ?? const [];
    final wide = context.isWide;
    final poster = wide ? 170.0 : 128.0;
    final posterHeight = poster * 1.5 + 50;
    final channel = wide ? 210.0 : 160.0;

    final heroItems = [...data.topRatedMovies, ...data.recentSeries]
        .where((m) => m.logo != null || m.backdrop != null)
        .take(6)
        .toList();

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: heroItems.isEmpty ? SafeArea(child: _TopBar(data: data)) : _Hero(items: heroItems, data: data),
      ),
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
        const SizedBox(height: 8),
        if (data.continueWatching.isNotEmpty)
          MediaRow(
            title: 'Continue watching',
            itemCount: data.continueWatching.length,
            itemWidth: wide ? 320 : 250,
            height: (wide ? 320 : 250) * 9 / 16 + 16,
            itemBuilder: (_, i) => ContinueCard(entry: data.continueWatching[i], width: wide ? 320 : 250),
          ),
        if (recs.isNotEmpty)
          MediaRow(
            title: 'Recommended for you',
            subtitle: 'Based on what you watch',
            itemCount: recs.length,
            itemWidth: poster,
            height: posterHeight,
            itemBuilder: (_, i) => MediaCard(item: recs[i]),
          ),
        MediaRow(
          title: 'Live now',
          trailing: _SeeAll(onTap: () => StatefulNavigationShell.maybeOf(context)?.goBranch(3)),
          itemCount: data.liveChannels.length,
          itemWidth: channel,
          height: channel * 10 / 16 + 44,
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
          trailing: _SeeAll(onTap: () => StatefulNavigationShell.maybeOf(context)?.goBranch(1)),
          itemCount: data.recentMovies.length,
          itemWidth: poster,
          height: posterHeight,
          itemBuilder: (_, i) => PosterCard(item: data.recentMovies[i]),
        ),
        MediaRow(
          title: 'New series',
          trailing: _SeeAll(onTap: () => StatefulNavigationShell.maybeOf(context)?.goBranch(2)),
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

class _SeeAll extends StatelessWidget {
  const _SeeAll({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('See all'),
          Icon(Icons.chevron_right_rounded, size: 18),
        ]),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    return Padding(
      padding: EdgeInsets.fromLTRB(context.pagePadding, 12, context.pagePadding - 8, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(
              '${data.channelCount} channels · ${data.movieCount} movies · ${data.seriesCount} series',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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

/// Auto-advancing featured carousel.
class _Hero extends StatefulWidget {
  const _Hero({required this.items, required this.data});
  final List<MediaItem> items;
  final HomeData data;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _page = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!_page.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      _page.animateToPage(next, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final height = (MediaQuery.sizeOf(context).height * (wide ? 0.62 : 0.58)).clamp(380.0, 640.0);
    return SizedBox(
      height: height,
      child: Stack(children: [
        PageView.builder(
          controller: _page,
          itemCount: widget.items.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => _HeroSlide(item: widget.items[i]),
        ),
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: _TopBar(data: widget.data))),
        Positioned(
          bottom: 16,
          right: context.pagePadding,
          child: Row(children: [
            for (var i = 0; i < widget.items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(left: 6),
                width: i == _index ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == _index ? AppColors.text : Colors.white30,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _HeroSlide extends ConsumerWidget {
  const _HeroSlide({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final wide = context.isWide;
    return Stack(fit: StackFit.expand, children: [
      NetImage(item.backdrop, label: item.name),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99000000), Colors.transparent, Color(0xCC09090F), AppColors.bg],
            stops: [0, 0.3, 0.75, 1],
          ),
        ),
      ),
      if (wide)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xE609090F), Colors.transparent], stops: [0, 0.6]),
          ),
        ),
      Positioned(
        left: context.pagePadding,
        right: context.pagePadding,
        bottom: 40,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(6)),
              child: Text(item.kind == MediaKind.series ? 'FEATURED SERIES' : 'FEATURED',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 12),
            Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: (wide ? t.displaySmall : t.headlineMedium)?.copyWith(height: 1.05)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (item.rating != null && item.rating! > 0)
                MetaChip(item.rating!.toStringAsFixed(1), icon: Icons.star_rounded),
              if (item.year != null) MetaChip('${item.year}'),
              if (item.group.isNotEmpty) MetaChip(item.group),
            ]),
            if (item.plot != null && wide) ...[
              const SizedBox(height: 14),
              Text(item.plot!, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: t.bodyLarge?.copyWith(color: Colors.white70, height: 1.5)),
            ],
            const SizedBox(height: 20),
            Row(children: [
              GradientButton(
                label: item.kind == MediaKind.movie ? 'Play' : 'Watch',
                icon: Icons.play_arrow_rounded,
                onPressed: () => item.kind == MediaKind.movie
                    ? PlayerScreen.open(context, PlayerArgs.movie(item))
                    : openItem(context, item),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.35)),
                onPressed: () => openItem(context, item),
                icon: const Icon(Icons.info_outline_rounded),
                label: const Text('Details'),
              ),
            ]),
          ]),
        ),
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
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Skeleton(height: (MediaQuery.sizeOf(context).height * 0.5).clamp(320.0, 560.0), radius: 0),
          const SizedBox(height: 24),
          const SkeletonRow(),
          const SkeletonRow(),
        ],
      );
}
