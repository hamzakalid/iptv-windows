import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
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
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final d = MovieDetails(item);
    final progress = ref.watch(progressProvider(item.id)).value;
    final resumeAt = progress != null && !progress.completed && progress.positionSecs > 30 ? progress.positionSecs : null;
    final dur = d.durationSecs ?? progress?.durationSecs;
    final trailer = d.trailer;

    return DetailScaffold(
      item: item,
      loading: async.isLoading && async.value == null,
      meta: [
        if (item.rating != null && item.rating! > 0) MetaChip(item.rating!.toStringAsFixed(1), icon: Icons.star_rounded),
        if (item.year != null) MetaChip('${item.year}'),
        if (dur != null && dur > 0) MetaChip(formatDuration(dur), icon: Icons.schedule_rounded),
        if (d.genre != null) MetaChip(d.genre!),
      ],
      actions: [
        GradientButton(
          label: resumeAt != null ? 'Resume ${formatDuration(resumeAt)}' : 'Play',
          icon: Icons.play_arrow_rounded,
          onPressed: () => PlayerScreen.open(context, PlayerArgs.movie(item, startAt: resumeAt ?? 0)),
        ),
        if (resumeAt != null)
          OutlinedButton.icon(
            onPressed: () => PlayerScreen.open(context, PlayerArgs.movie(item, startAt: 0)),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('From start'),
          ),
        FavoriteButton(item: item),
        if (trailer != null)
          OutlinedButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(trailer.startsWith('http') ? trailer : 'https://www.youtube.com/watch?v=$trailer'),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.smart_display_outlined),
            label: const Text('Trailer'),
          ),
      ],
      sections: [
        if (resumeAt != null && dur != null && dur > 0)
          Padding(
            padding: EdgeInsets.fromLTRB(context.pagePadding, 0, context.pagePadding, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (resumeAt / dur).clamp(0, 1),
                  minHeight: 5,
                  color: AppColors.accent,
                  backgroundColor: AppColors.surfaceHigh,
                ),
              ),
            ),
          ),
        if (d.plot != null)
          TextSection(
            title: 'Storyline',
            text: d.plot!,
            footer: d.director == null
                ? null
                : Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Director  ', style: TextStyle(color: AppColors.textMuted)),
                    TextSpan(text: d.director, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ])),
          ),
        if (d.actors.isNotEmpty) CastRow(actors: d.actors),
        SimilarRow(kind: MediaKind.movie, id: item.id),
      ],
    );
  }
}
