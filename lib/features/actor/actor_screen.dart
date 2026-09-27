import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';

class ActorScreen extends ConsumerWidget {
  const ActorScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(actorProvider(id));
    final t = Theme.of(context).textTheme;
    final pad = context.pagePadding;
    return Scaffold(
      appBar: AppBar(),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(actorProvider(id))),
        data: (r) {
          final (actor, credits) = r;
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brandGradient),
                    child: ClipOval(
                      child: SizedBox.square(
                        dimension: context.isWide ? 160 : 110,
                        child: NetImage(actor.profileUrl, label: actor.name),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(actor.name, style: t.headlineMedium),
                      const SizedBox(height: 6),
                      Text('${credits.length} title${credits.length == 1 ? '' : 's'} in your library',
                          style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      if (actor.biography != null) ...[
                        const SizedBox(height: 12),
                        Text(actor.biography!, maxLines: 6, overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium?.copyWith(color: Colors.white70, height: 1.5)),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: context.isWide ? 190 : 130,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.52,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => PosterCard(item: credits[i]),
                  childCount: credits.length,
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
