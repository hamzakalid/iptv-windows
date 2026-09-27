import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
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
      return Scaffold(
        appBar: AppBar(),
        body: async.hasError
            ? ErrorView(error: async.error!, onRetry: () => ref.invalidate(detailProvider))
            : const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final d = MovieDetails(item);
    final progress = ref.watch(progressProvider(item.id)).value;
    final watched = progress?.completed == true || ref.watch(watchedIdsProvider).contains(item.id);
    final resumeAt = progress != null && !progress.completed && progress.positionSecs > 30 ? progress.positionSecs : null;
    final dur = d.durationSecs ?? progress?.durationSecs;
    final trailer = d.trailer;

    void play(int startAt) => PlayerScreen.open(context, PlayerArgs.movie(item, startAt: startAt));

    return DetailScaffold(
      item: item,
      loading: async.isLoading && async.value == null,
      meta: [
        if (item.year != null) Text('${item.year}'),
        if (dur != null && dur > 0) Text(formatDuration(dur)),
        for (final g in item.genres.take(3)) Tag(g),
      ],
      footnote: d.director == null
          ? null
          : Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Director  ', style: TextStyle(color: AppColors.neutral500)),
                TextSpan(text: d.director),
              ]),
              style: const TextStyle(fontSize: 12.5, color: AppColors.neutral300),
            ),
      progress: resumeAt != null && dur != null && dur > 0
          ? ResumeBar(value: resumeAt / dur, label: '${formatDuration(dur - resumeAt)} left')
          : null,
      actions: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: detailButtonSize, padding: const EdgeInsets.symmetric(horizontal: 16)),
          onPressed: () => play(resumeAt ?? 0),
          icon: const Icon(PhosphorIconsFill.play),
          label: Text(resumeAt != null ? 'Resume' : (watched ? 'Watch again' : 'Play')),
        ),
        if (resumeAt != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: detailButtonSize),
            onPressed: () => play(0),
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
        if (d.actors.isNotEmpty) CastRow(actors: d.actors),
        SimilarRow(kind: MediaKind.movie, id: item.id),
      ],
    );
  }
}
