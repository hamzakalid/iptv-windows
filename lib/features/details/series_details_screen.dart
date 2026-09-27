import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/json.dart';
import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_row.dart';
import '../player/player_screen.dart';
import 'detail_scaffold.dart';

class SeriesDetailsScreen extends ConsumerStatefulWidget {
  const SeriesDetailsScreen({super.key, required this.id, this.preview});
  final String id;
  final MediaItem? preview;

  @override
  ConsumerState<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends ConsumerState<SeriesDetailsScreen> {
  int? _season;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(detailProvider((kind: MediaKind.series, id: widget.id)));
    final item = async.value ?? widget.preview;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: async.hasError
            ? ErrorView(error: async.error!, onRetry: () => ref.invalidate(detailProvider))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    // Episodes only exist on the fully loaded detail, not the preview.
    final seasons = async.value == null ? <int, List<Episode>>{} : Episode.bySeason(item.raw['episodes']);
    final season = _season ?? (seasons.isEmpty ? null : seasons.keys.first);
    final episodes = seasons[season] ?? const <Episode>[];
    final cast = jStrList(item.details?['cast']).map((n) => Actor(id: null, name: n)).toList();

    void play(List<Episode> queue, int index) =>
        PlayerScreen.open(context, PlayerArgs.episode(item, queue, index));

    return DetailScaffold(
      item: item,
      loading: async.isLoading && async.value == null,
      meta: [
        if (item.rating != null && item.rating! > 0) MetaChip(item.rating!.toStringAsFixed(1), icon: Icons.star_rounded),
        if (item.year != null) MetaChip('${item.year}'),
        if (seasons.isNotEmpty) MetaChip('${seasons.length} season${seasons.length == 1 ? '' : 's'}'),
        if (item.genre != null) MetaChip(item.genre!),
      ],
      actions: [
        if (seasons.isNotEmpty)
          GradientButton(
            label: 'Play S${seasons.keys.first} · E${seasons.values.first.first.episode}',
            icon: Icons.play_arrow_rounded,
            onPressed: () => play(seasons.values.first, 0),
          ),
        FavoriteButton(item: item),
      ],
      sections: [
        if (item.plot != null) TextSection(title: 'Storyline', text: item.plot!),
        if (seasons.isNotEmpty) ...[
          SectionHeader('Episodes'),
          if (seasons.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
                children: [
                  for (final s in seasons.keys)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Pill('Season $s', selected: s == season, onTap: () => setState(() => _season = s)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < episodes.length; i++)
            _EpisodeTile(episode: episodes[i], fallbackImage: item.backdrop, onTap: () => play(episodes, i)),
          const SizedBox(height: 28),
        ] else if (async.value != null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.video_library_outlined,
              title: 'No episodes available',
              message: 'This provider did not return episode information for this series.',
            ),
          ),
        if (cast.isNotEmpty) CastRow(actors: cast),
        SimilarRow(kind: MediaKind.series, id: item.id),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, required this.onTap, this.fallbackImage});
  final Episode episode;
  final String? fallbackImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = context.isWide;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.pagePadding - 8, vertical: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: wide ? 200 : 132,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(fit: StackFit.expand, children: [
                      NetImage(episode.thumb ?? fallbackImage, label: 'E${episode.episode}', memCacheWidth: 400),
                      const ColoredBox(color: Color(0x33000000)),
                      const Center(child: Icon(Icons.play_circle_fill_rounded, size: 34, color: Colors.white)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${episode.episode}. ${episode.title}', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (episode.durationSecs != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(formatDuration(episode.durationSecs),
                          style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                    ),
                  if (episode.plot != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(episode.plot!, maxLines: wide ? 3 : 2, overflow: TextOverflow.ellipsis,
                          style: t.bodySmall?.copyWith(color: Colors.white70, height: 1.45)),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
