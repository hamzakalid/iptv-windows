import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/media.dart';
import '../../state/providers.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/common.dart';
import '../../widgets/media_cards.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  MediaKind? _filter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoritesProvider);
    final pad = context.pagePadding;
    final wide = context.isWide;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(pad, 16, pad - (wide ? 0 : 8), 8),
            child: Row(children: [
              Expanded(child: Text('My List', style: Theme.of(context).textTheme.headlineMedium)),
              const HeaderActions(),
            ]),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
              children: [
                for (final k in <MediaKind?>[null, ...MediaKind.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(switch (k) {
                        null => 'All',
                        MediaKind.movie => 'Movies',
                        MediaKind.series => 'Series',
                        MediaKind.channel => 'Channels',
                      }),
                      selected: _filter == k,
                      labelStyle: TextStyle(
                        color: _filter == k ? Colors.white : AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _filter = k),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(favoritesProvider)),
              data: (favs) {
                final items = favs.where((f) => _filter == null || f.kind == _filter).map((f) => f.item!).toList();
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Your list is empty',
                    message: 'Tap "My List" on any movie or series to save it here for later.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(favoritesProvider.future),
                  child: GridView.builder(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: wide ? 190 : 130,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.52,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => items[i].kind == MediaKind.channel
                        ? Align(alignment: Alignment.topCenter, child: ChannelCard(item: items[i]))
                        : PosterCard(item: items[i]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
