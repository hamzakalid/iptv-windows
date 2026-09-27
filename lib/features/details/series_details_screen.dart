import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/json.dart';
import '../../core/theme.dart';
import '../../models/account.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/nocturne.dart';
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
      return DetailPlaceholder(
        error: async.hasError ? async.error : null,
        onRetry: () => ref.invalidate(detailProvider),
      );
    }

    // Episodes only exist on the fully loaded detail, not the preview.
    final seasons = async.value == null ? <int, List<Episode>>{} : Episode.bySeason(item.raw['episodes']);
    final cast = jStrList(item.details?['cast']).map((n) => Actor(id: null, name: n)).toList();
    final trailer = MovieDetails(item).trailer;

    // Watch history holds one row per (series, episode), newest first.
    final events = (ref.watch(historyProvider).value ?? const <WatchEvent>[])
        .where((e) => e.kind == MediaKind.series && e.contentId == item.id)
        .toList()
      ..sort((a, b) => (b.watchedAt ?? DateTime(0)).compareTo(a.watchedAt ?? DateTime(0)));
    WatchEvent? eventFor(Episode ep) {
      for (final e in events) {
        if (e.episodeId != null && e.episodeId == ep.id) return e;
        if (e.episodeId == null && e.season == ep.season && e.episode == ep.episode) return e;
      }
      return null;
    }

    // Where the user left off: the most recently watched episode.
    final flat = [for (final l in seasons.values) ...l];
    final last = events.firstOrNull;
    final lastIdx = last == null
        ? -1
        : flat.indexWhere((ep) =>
            (last.episodeId != null && last.episodeId == ep.id) ||
            (last.season == ep.season && last.episode == ep.episode));
    final lastEp = lastIdx < 0 ? null : flat[lastIdx];
    final resuming = lastEp != null && !last!.completed && last.positionSecs > 30;
    final resumePct = resuming ? _pct(last) : null;

    final Episode? target;
    final String label;
    var startAt = 0;
    if (resuming) {
      target = lastEp;
      label = 'Resume S${lastEp.season} · E${lastEp.episode}';
      startAt = last.positionSecs;
    } else if (lastEp != null && lastIdx + 1 < flat.length) {
      target = flat[lastIdx + 1];
      label = 'Play S${target.season} · E${target.episode}';
    } else if (lastEp != null) {
      target = flat.first;
      label = 'Watch again';
    } else {
      target = flat.firstOrNull;
      label = target == null ? 'Play' : 'Play S${target.season} · E${target.episode}';
    }

    final season = _season != null && seasons.containsKey(_season)
        ? _season
        : (lastEp?.season ?? seasons.keys.firstOrNull);
    final episodes = seasons[season] ?? const <Episode>[];

    void play(Episode ep, {int startAt = 0}) {
      final queue = seasons[ep.season]!;
      PlayerScreen.open(context, PlayerArgs.episode(item, queue, queue.indexOf(ep), startAt: startAt));
    }

    final seasonCount = seasons.isNotEmpty ? seasons.length : item.seasonCount;
    final g = detailGutter(context);

    return DetailScaffold(
      item: item,
      kindLabel: 'Series',
      loading: async.isLoading && async.value == null,
      meta: detailMeta(item,
          length: seasonCount == null ? null : '$seasonCount season${seasonCount == 1 ? '' : 's'}'),
      plot: item.plot,
      progress: resumePct,
      progressLabel: resuming ? 'S${lastEp.season} · E${lastEp.episode} · ${(resumePct! * 100).round()}%' : null,
      actions: [
        NocButton.primary(
          label: label,
          icon: PhF.play,
          height: 38,
          onPressed: target == null ? null : () => play(target!, startAt: startAt),
        ),
        if (resuming)
          NocButton(
            label: 'Start over',
            icon: Ph.arrowCounterClockwise,
            height: 38,
            onPressed: () => play(flat.first),
          ),
        SaveButton(item: item),
        if (trailer != null) TrailerButton(trailer: trailer),
      ],
      sections: [
        if (seasons.isNotEmpty) ...[
          DetailHeading(
            'Episodes',
            top: 36,
            bottom: 10,
            trailing: seasons.length < 2
                ? null
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Seg<int>(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      options: [for (final s in seasons.keys) SegOption(s, 'Season $s')],
                      value: season!,
                      onChanged: (s) => setState(() => _season = s),
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: g - 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(children: [
                  for (final ep in episodes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Builder(builder: (context) {
                        final e = eventFor(ep);
                        final isResume = resuming && ep == lastEp;
                        return _EpisodeTile(
                          episode: ep,
                          pct: e == null ? 0 : (e.completed ? 1 : _pct(e)),
                          done: e?.completed ?? false,
                          onTap: () => play(ep, startAt: isResume ? last.positionSecs : 0),
                        );
                      }),
                    ),
                ]),
              ),
            ),
          ),
        ] else if (async.value != null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: EmptyState(
              icon: Ph.filmSlate,
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

class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({required this.episode, required this.pct, required this.done, required this.onTap});
  final Episode episode;
  final double pct;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final thumb = episode.thumb;
    return Tappable(
      onTap: onTap,
      hover: AppColors.text.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: wide ? 176 : 132,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(fit: StackFit.expand, children: [
                  if (thumb != null && thumb.startsWith('http'))
                    NetImage(thumb, label: 'E${episode.episode}', memCacheWidth: 400)
                  else
                    ArtPlaceholder(
                      center: const Alignment(-0.4, -0.6),
                      child: Text('E${episode.episode}', style: const TextStyle(fontSize: 11, color: AppColors.n600)),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ProgressLine(pct, height: 3, track: AppColors.text.withValues(alpha: 0.12)),
                  ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                  if (done) ...[const SizedBox(width: 8), const Icon(Ph.check, size: 15, color: AppColors.a400)],
                ]),
                if (episode.durationSecs != null && episode.durationSecs! > 0) ...[
                  const SizedBox(height: 3),
                  Text('${(episode.durationSecs! / 60).round()} min',
                      style: const TextStyle(fontSize: 12, color: AppColors.n500)),
                ],
                if (episode.plot != null) ...[
                  const SizedBox(height: 3),
                  Text(episode.plot!,
                      maxLines: wide ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.text.withValues(alpha: 0.65))),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
