import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/nocturne.dart';
import '../details/detail_scaffold.dart';

/// Actor page: photo, biography and dates from TMDB, then the user's movies
/// and series with this actor as two separate sections.
class ActorScreen extends ConsumerStatefulWidget {
  const ActorScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ActorScreen> createState() => _ActorScreenState();
}

class _ActorScreenState extends ConsumerState<ActorScreen> {
  bool _fullBio = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(actorProvider(widget.id));
    final page = async.value;
    if (page == null) {
      return DetailPlaceholder(
        error: async.hasError ? async.error : null,
        onRetry: () => ref.invalidate(actorProvider(widget.id)),
      );
    }
    final actor = page.actor;
    final wide = context.isWide;
    final g = detailGutter(context);
    final size = wide ? 148.0 : 96.0;

    final meta = <String>[
      if (actor.birthday != null)
        'Born ${_date(actor.birthday!)}${actor.age != null ? ' (${actor.deathday == null ? 'age ' : ''}${actor.age})' : ''}',
      if (actor.deathday != null) 'Died ${_date(actor.deathday!)}',
      ?actor.placeOfBirth,
    ];
    final credits = [
      if (page.movies.isNotEmpty) '${page.movies.length} movie${page.movies.length == 1 ? '' : 's'}',
      if (page.series.isNotEmpty) '${page.series.length} series',
    ];

    return DetailPage(
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, g, 0),
            child: const Align(alignment: Alignment.centerLeft, child: BackButtonChip()),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(g, 28, g, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: size,
                height: size,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.n900,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.n800, spreadRadius: 1)],
                ),
                child: actor.hasPhoto
                    ? SizedBox.expand(child: NetImage(actor.profileUrl, label: actor.name, memCacheWidth: 400))
                    : Text(initials(actor.name), style: TextStyle(fontSize: size * 0.2, color: AppColors.n500)),
              ),
              SizedBox(width: wide ? 28 : 18),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((actor.knownFor ?? 'Actor').toUpperCase(),
                        style: const TextStyle(fontSize: 10, letterSpacing: 1, color: AppColors.accent, height: 1.4)),
                    const SizedBox(height: 10),
                    Text(actor.name, style: wide ? NocText.h2 : NocText.h3),
                    const SizedBox(height: 10),
                    Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(credits.isEmpty ? 'Not in your library yet' : '${credits.join(' · ')} in your library',
                          style: const TextStyle(fontSize: 13, color: AppColors.n300)),
                      for (final m in meta) NocTag(m),
                    ]),
                    if (actor.biography != null) ...[
                      const SizedBox(height: 12),
                      Text(actor.biography!,
                          maxLines: _fullBio ? null : (wide ? 5 : 4),
                          overflow: _fullBio ? null : TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, height: 1.55, color: AppColors.n300)),
                      if (actor.biography!.length > 280)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: NocButton.ghost(
                            label: _fullBio ? 'Show less' : 'Read more',
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() => _fullBio = !_fullBio),
                          ),
                        ),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
        if (page.total == 0)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: EmptyState(
                icon: Ph.filmStrip,
                title: 'Nothing in your library',
                message: 'No movies or series with this actor yet.',
              ),
            ),
          ),
        if (page.movies.isNotEmpty) ..._section(context, 'Movies', page.movies, MediaKind.movie),
        if (page.series.isNotEmpty) ..._section(context, 'Series', page.series, MediaKind.series),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
    );
  }

  List<Widget> _section(BuildContext context, String title, List<MediaItem> items, MediaKind kind) {
    final wide = context.isWide;
    final g = detailGutter(context);
    return [
      SliverToBoxAdapter(
        child: DetailHeading(
          title,
          trailing: Text('${items.length}', style: const TextStyle(fontSize: 13, color: AppColors.n600)),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(g, 2, g, 8),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: wide ? 170 : 130,
            mainAxisSpacing: 18,
            crossAxisSpacing: 14,
            childAspectRatio: 0.55,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, i) => PosterCard(item: items[i]),
            childCount: items.length,
          ),
        ),
      ),
    ];
  }
}

/// "9 Jul 1956"
String _date(DateTime d) {
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${mo[d.month - 1]} ${d.year}';
}
