import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';
import '../../widgets/nocturne.dart';
import '../details/detail_scaffold.dart';

class ActorScreen extends ConsumerWidget {
  const ActorScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(actorProvider(id));
    final r = async.value;
    if (r == null) {
      return DetailPlaceholder(
        error: async.hasError ? async.error : null,
        onRetry: () => ref.invalidate(actorProvider(id)),
      );
    }
    final (actor, credits) = r;
    final wide = context.isWide;
    final g = detailGutter(context);
    final size = wide ? 132.0 : 96.0;
    final photo = actor.profileUrl != null && actor.profileUrl!.startsWith('http');

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
                child: photo
                    ? SizedBox.expand(child: NetImage(actor.profileUrl, label: actor.name, memCacheWidth: 300))
                    : Text(initials(actor.name), style: TextStyle(fontSize: size * 0.2, color: AppColors.n500)),
              ),
              SizedBox(width: wide ? 28 : 18),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('ACTOR',
                        style: TextStyle(fontSize: 10, letterSpacing: 1, color: AppColors.accent, height: 1.4)),
                    const SizedBox(height: 10),
                    Text(actor.name, style: wide ? NocText.h2 : NocText.h3),
                    const SizedBox(height: 10),
                    Text('${credits.length} title${credits.length == 1 ? '' : 's'} in your library',
                        style: const TextStyle(fontSize: 13, color: AppColors.n300)),
                    if (actor.biography != null) ...[
                      const SizedBox(height: 10),
                      Text(actor.biography!,
                          maxLines: 8,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, height: 1.55, color: AppColors.n300)),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),
        if (credits.isNotEmpty) ...[
          const SliverToBoxAdapter(child: DetailHeading('In your library')),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(g, 2, g, 40),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: wide ? 170 : 130,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
                childAspectRatio: 0.55,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => PosterCard(item: credits[i]),
                childCount: credits.length,
              ),
            ),
          ),
        ] else
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: EmptyState(icon: Ph.filmStrip, title: 'Nothing in your library', message: 'No titles with this actor yet.'),
            ),
          ),
      ]),
    );
  }
}
