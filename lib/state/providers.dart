import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/media.dart';
import 'session.dart';

export 'session.dart';

final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final list = await ref.watch(repositoryProvider).playlists();
  // Poll while any playlist is still ingesting so status chips update live.
  if (list.any((p) => p.isBusy)) {
    final t = Timer(const Duration(seconds: 4), ref.invalidateSelf);
    ref.onDispose(t.cancel);
  }
  return list;
});

final homeProvider = FutureProvider<HomeData>((ref) async {
  final repo = ref.watch(repositoryProvider);
  final data = await repo.home(playlistId: ref.watch(activePlaylistProvider));
  // Keep the playlist fresh without blocking the UI.
  if (data.playlistId != null) unawaited(repo.syncIfStale(data.playlistId!).catchError((_) {}));
  return data;
});

final recommendationsProvider = FutureProvider<List<MediaItem>>((ref) => ref
    .watch(repositoryProvider)
    .recommendations(playlistId: ref.watch(activePlaylistProvider))
    .catchError((_) => <MediaItem>[]));

final categoriesProvider = FutureProvider.family<Categories, MediaKind>((ref, kind) =>
    ref.watch(repositoryProvider).categories(kind, playlistId: ref.watch(activePlaylistProvider)));

typedef ItemRef = ({MediaKind kind, String id});

final detailProvider = FutureProvider.autoDispose.family<MediaItem, ItemRef>(
    (ref, r) => ref.watch(repositoryProvider).detail(r.kind, r.id));

final similarProvider = FutureProvider.autoDispose.family<List<MediaItem>, ItemRef>((ref, r) => ref
    .watch(repositoryProvider)
    .similar(r.kind, r.id)
    .catchError((_) => <MediaItem>[]));

final progressProvider = FutureProvider.autoDispose.family<WatchProgress?, String>(
    (ref, contentId) => ref.watch(repositoryProvider).progressFor(contentId).catchError((_) => null));

final actorProvider = FutureProvider.autoDispose
    .family<(Actor, List<MediaItem>), String>((ref, id) => ref.watch(repositoryProvider).actor(id));

final searchProvider = FutureProvider.autoDispose.family<SearchResults, String>((ref, q) =>
    ref.watch(repositoryProvider).search(q, playlistId: ref.watch(activePlaylistProvider)));

/// Favourites with optimistic add/remove.
final favoritesProvider = AsyncNotifierProvider<FavoritesController, List<Favorite>>(FavoritesController.new);

class FavoritesController extends AsyncNotifier<List<Favorite>> {
  @override
  Future<List<Favorite>> build() => ref.watch(repositoryProvider).favorites();

  bool contains(String contentId) => (state.value ?? const []).any((f) => f.contentId == contentId);

  Future<void> toggle(MediaItem item) async {
    final repo = ref.read(repositoryProvider);
    final current = state.value ?? const <Favorite>[];
    final existing = current.where((f) => f.contentId == item.id).firstOrNull;
    if (existing != null) {
      state = AsyncData(current.where((f) => f != existing).toList());
      try {
        if (existing.id.isNotEmpty) await repo.removeFavorite(existing.id);
      } catch (_) {
        state = AsyncData(current);
        rethrow;
      }
    } else {
      state = AsyncData([Favorite(id: '', kind: item.kind, contentId: item.id, item: item), ...current]);
      try {
        await repo.addFavorite(item);
      } catch (_) {
        state = AsyncData(current);
        rethrow;
      }
      // Refresh to pick up the server-side id (needed for delete).
      ref.invalidateSelf();
    }
  }
}
