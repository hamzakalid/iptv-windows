import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/json.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
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
            : const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    // Episodes only exist on the fully loaded detail, not the preview.
    final seasons = async.value == null ? <int, List<Episode>>{} : Episode.bySeason(item.raw['episodes']);
    final cast = jStrList(item.details?['cast']).map((n) => Actor(id: null, name: n)).toList();
    final trailer = MovieDetails(item).trailer;

    // Where the user left off, matched by episode id, else season + number.
    final resume = ref.watch(resumeProvider)[item.id];
    ({int season, int index})? at;
    if (resume != null) {
      for (final MapEntry(key: s, value: eps) in seasons.entries) {
        final i = eps.indexWhere((e) =>
            (resume.episodeId != null && e.id == resume.episodeId) ||
            (e.season == resume.season && e.episode == resume.episode));
        if (i >= 0) {
          at = (season: s, index: i);
          break;
        }
      }
    }

    final season = _season ?? at?.season ?? (seasons.isEmpty ? null : seasons.keys.first);
    final episodes = seasons[season] ?? const <Episode>[];

    void play(int s, int index, {int startAt = 0}) =>
        PlayerScreen.open(context, PlayerArgs.episode(item, seasons[s]!, index, startAt: startAt, seasons: seasons));

    final first = seasons.isEmpty ? null : seasons.values.first.first;
    final current = at == null ? null : seasons[at.season]![at.index];

    return DetailScaffold(
      item: item,
      kindLabel: 'Series',
      loading: async.isLoading && async.value == null,
      meta: [
        if (item.year != null) Text('${item.year}'),
        if (seasons.isNotEmpty) Text('${seasons.length} season${seasons.length == 1 ? '' : 's'}'),
        for (final g in item.genres.take(3)) Tag(g),
      ],
      progress: current == null
          ? null
          : ResumeBar(
              value: resume!.progressPct / 100,
              label: 'S${current.season} · E${current.episode} · ${resume.progressPct.round()}%',
            ),
      actions: [
        if (current != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: detailButtonSize, padding: const EdgeInsets.symmetric(horizontal: 16)),
            onPressed: () => play(at!.season, at.index, startAt: resume!.positionSecs),
            icon: const Icon(PhosphorIconsFill.play),
            label: Text('Resume S${current.season} · E${current.episode}'),
          )
        else if (first != null)
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: detailButtonSize, padding: const EdgeInsets.symmetric(horizontal: 16)),
            onPressed: () => play(seasons.keys.first, 0),
            icon: const Icon(PhosphorIconsFill.play),
            label: Text('Play S${first.season} · E${first.episode}'),
          ),
        if (current != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: detailButtonSize),
            onPressed: () => play(seasons.keys.first, 0),
            icon: const Icon(PhosphorIconsRegular.arrowCounterClockwise),
            label: const Text('Start over'),
          ),
        MyListButton(item: item),
        if (trailer != null)
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: detailButtonSize, padding: const EdgeInsets.symmetric(horizontal: 10)),
            onPressed: () => launchUrl(
              Uri.parse(trailer.startsWith('http') ? trailer : 'https://www.youtube.com/watch?v=$trailer'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(PhosphorIconsRegular.filmReel),
            label: const Text('Trailer'),
          ),
      ],
      sections: [
        if (seasons.isNotEmpty) ...[
          DetailHeading(
            'Episodes',
            trailing: seasons.length > 1
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedControl<int>(
                      dense: true,
                      segments: [for (final s in seasons.keys) Segment(s, 'Season $s')],
                      selected: season!,
                      onChanged: (s) => setState(() => _season = s),
                    ),
                  )
                : null,
          ),
          for (var i = 0; i < episodes.length; i++)
            _EpisodeRow(
              episode: episodes[i],
              fallbackImage: item.backdrop,
              progress: at == null
                  ? 0
                  : (season! < at.season || (season == at.season && i < at.index))
                      ? 1
                      : (season == at.season && i == at.index ? resume!.progressPct / 100 : 0),
              onTap: () => play(season!, i, startAt: season == at?.season && i == at?.index ? resume!.positionSecs : 0),
            ),
        ] else if (async.value != null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              icon: PhosphorIconsRegular.stack,
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

double _pct(WatchEvent e) {
  if (e.progressPct > 0) return (e.progressPct / 100).clamp(0.0, 1.0);
  final d = e.durationSecs;
  return d == null || d <= 0 ? 0 : (e.positionSecs / d).clamp(0.0, 1.0);
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.onTap, required this.progress, this.fallbackImage});
  final Episode episode;
  final String? fallbackImage;

  /// 1 for episodes before the resume point, the fraction for the current one.
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final done = progress >= 1;
    final thumb = episode.thumb ?? fallbackImage;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: detailPad(context) - 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Hoverable(
            onTap: onTap,
            hoverColor: AppColors.wash(0.05),
            ring: Shadows.ringFlat,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: wide ? 176 : 128,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: Stack(fit: StackFit.expand, children: [
                        NetImage(thumb, labelSize: 0, memCacheWidth: 360),
                        if (thumb == null)
                          Center(
                            child: Text('E${episode.episode}', style: const TextStyle(fontSize: 11, color: AppColors.neutral600)),
                          ),
                        if (progress > 0) ArtProgress(progress),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(
                          child: Text('${episode.episode}. ${episode.title}',
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        if (done) ...[
                          const SizedBox(width: 8),
                          const Icon(PhosphorIconsRegular.check, size: 14, color: AppColors.accent400),
                        ],
                      ]),
                      if (episode.durationSecs != null) ...[
                        const SizedBox(height: 3),
                        Text(formatDuration(episode.durationSecs),
                            style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
                      ],
                      if (episode.plot != null) ...[
                        const SizedBox(height: 3),
                        Text(episode.plot!,
                            maxLines: wide ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.wash(0.65))),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
