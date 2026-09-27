import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_grid.dart';

/// Actor page: photo, TMDB biography and dates, then the user's movies and
/// series with this actor as two separate sections.
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
    final pad = context.pagePadding;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back (Esc)',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
        ),
      ),
      body: async.when(
        loading: () =>
            const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(actorProvider(widget.id))),
        data: (page) {
          final actor = page.actor;
          final wide = context.isWide;
          final size = wide ? 160.0 : 110.0;
          final facts = <String>[
            if (actor.birthday != null)
              'Born ${_date(actor.birthday!)}${actor.age != null ? ' (${actor.deathday == null ? 'age ' : ''}${actor.age})' : ''}',
            if (actor.deathday != null) 'Died ${_date(actor.deathday!)}',
            ?actor.placeOfBirth,
          ];
          final credits = [
            if (page.movies.isNotEmpty) '${page.movies.length} movie${page.movies.length == 1 ? '' : 's'}',
            if (page.series.isNotEmpty) '${page.series.length} series',
          ];
          final bio = actor.biography;

          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: size,
                    height: size,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.neutral900,
                      boxShadow: Shadows.sm,
                    ),
                    child: NetImage(actor.profileUrl, label: actor.name, labelSize: 28, memCacheWidth: 400),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((actor.knownFor ?? 'Actor').toUpperCase(), style: AppText.kicker),
                        const SizedBox(height: 8),
                        Text(actor.name, style: wide ? AppText.h2 : AppText.h3),
                        const SizedBox(height: 8),
                        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(credits.isEmpty ? 'Not in your library yet' : '${credits.join(' · ')} in your library',
                              style: AppText.meta),
                          for (final f in facts) Tag(f),
                        ]),
                        if (bio != null) ...[
                          const SizedBox(height: 12),
                          Text(bio,
                              maxLines: _fullBio ? null : (wide ? 5 : 4),
                              overflow: _fullBio ? null : TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: AppColors.neutral300, height: 1.55)),
                          if (bio.length > 280)
                            TextButton(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              onPressed: () => setState(() => _fullBio = !_fullBio),
                              child: Text(_fullBio ? 'Show less' : 'Read more'),
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
                    icon: PhosphorIconsRegular.filmStrip,
                    title: 'Nothing in your library',
                    message: 'No movies or series with this actor yet.',
                  ),
                ),
              ),
            if (page.movies.isNotEmpty) ..._section(context, 'Movies', page.movies, MediaKind.movie),
            if (page.series.isNotEmpty) ..._section(context, 'Series', page.series, MediaKind.series),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]);
        },
      ),
    );
  }

  List<Widget> _section(BuildContext context, String title, List<MediaItem> items, MediaKind kind) {
    final pad = context.pagePadding;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(title, style: AppText.h5),
            const SizedBox(width: 10),
            Text('${items.length}', style: const TextStyle(fontSize: 12, color: AppColors.neutral600)),
          ]),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
        sliver: MediaGridSliver(items: items, kind: kind),
      ),
    ];
  }
}

/// "9 Jul 1956"
String _date(DateTime d) {
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${mo[d.month - 1]} ${d.year}';
}
