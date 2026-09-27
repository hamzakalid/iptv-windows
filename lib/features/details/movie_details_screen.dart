import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/nocturne.dart';
import '../player/player_screen.dart';
import 'detail_scaffold.dart';

class MovieDetailsScreen extends ConsumerWidget {
  const MovieDetailsScreen({super.key, required this.id, this.preview});
  final String id;
  final MediaItem? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(detailProvider((kind: MediaKind.movie, id: id)));
    final item = async.value ?? preview;
    if (item == null) {
      return DetailPlaceholder(
        error: async.hasError ? async.error : null,
        onRetry: () => ref.invalidate(detailProvider),
      );
    }

    final d = MovieDetails(item);
    final progress = ref.watch(progressProvider(item.id)).value;
    final done = (progress?.completed ?? false) || ref.watch(watchedIdsProvider).contains(item.id);
    final dur = d.durationSecs ?? progress?.durationSecs;
    final resumeAt = !done && progress != null && progress.positionSecs > 30 ? progress.positionSecs : null;
    final pct = resumeAt != null && dur != null && dur > 0 ? (resumeAt / dur).clamp(0.0, 1.0) : null;
    final genres = item.genres.isNotEmpty
        ? item.genres
        : (d.genre ?? '').split(RegExp(r'[,/|]')).map((g) => g.trim()).where((g) => g.isNotEmpty).toList();
    final trailer = d.trailer;

    void play(int startAt) => PlayerScreen.open(context, PlayerArgs.movie(item, startAt: startAt));

    return DetailScaffold(
      item: item,
      kindLabel: 'Movie',
      loading: async.isLoading && async.value == null,
      meta: detailMeta(item, length: dur != null && dur > 0 ? hm(dur) : null, genres: genres),
      plot: d.plot,
      progress: pct,
      progressLabel: pct != null ? '${hm(dur! - resumeAt!)} left' : null,
      actions: [
        NocButton.primary(
          label: resumeAt != null ? 'Resume' : (done ? 'Watch again' : 'Play'),
          icon: PhF.play,
          height: 38,
          onPressed: () => play(resumeAt ?? 0),
        ),
        if (resumeAt != null)
          NocButton(label: 'Start over', icon: Ph.arrowCounterClockwise, height: 38, onPressed: () => play(0)),
        SaveButton(item: item),
        if (trailer != null) TrailerButton(trailer: trailer),
      ],
      sections: [
        if (d.actors.isNotEmpty) CastRow(actors: d.actors),
        SimilarRow(kind: MediaKind.movie, id: item.id),
      ],
    );
  }
}
