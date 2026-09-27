import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/media.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_grid.dart';

/// Actor page: photo, biography and dates from TMDB, then the user's movies
/// and series with this actor as two separate sections.
class ActorScreen extends ConsumerStatefulWidget {
  const ActorScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(actorProvider(id));
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
        loading: () => const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(actorProvider(id))),
        data: (r) {
          final (actor, credits) = r;
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: context.isWide ? 160 : 110,
                    height: context.isWide ? 160 : 110,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.neutral900,
                      boxShadow: Shadows.sm,
                    ),
                    child: NetImage(actor.profileUrl, label: actor.name, labelSize: 28),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(actor.name, style: context.isWide ? AppText.h2 : AppText.h3),
                      const SizedBox(height: 6),
                      Text('${credits.length} title${credits.length == 1 ? '' : 's'} in your library',
                          style: AppText.meta),
                      if (actor.biography != null) ...[
                        const SizedBox(height: 12),
                        Text(actor.biography!, maxLines: 6, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: AppColors.neutral300, height: 1.55)),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
              sliver: MediaGridSliver(items: credits, kind: MediaKind.movie),
            ),
          ]);
        },
      ),
    );
  }
}
