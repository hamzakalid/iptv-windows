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

final recommendationsProvider = FutureProvider<List<Recommendation>>((ref) => ref
    .watch(repositoryProvider)
    .recommendations(playlistId: ref.watch(activePlaylistProvider))
    .catchError((_) => <Recommendation>[]));

/// Flat "For you" list. Personalised picks come first; when there are few
/// (new account, small playlist) the row is topped up with the best-rated
/// titles the user hasn't finished, so it never looks empty.
final forYouProvider = Provider<List<MediaItem>>((ref) {
  final recs = (ref.watch(recommendationsProvider).value ?? const <Recommendation>[]).map((r) => r.item).toList();
  if (recs.length >= 8) return recs;
  final watched = ref.watch(watchedIdsProvider);
  final seen = recs.map((m) => m.id).toSet();
  final top = ref.watch(homeProvider).value?.topRatedMovies ?? const <MediaItem>[];
  return [...recs, ...top.where((m) => !watched.contains(m.id) && seen.add(m.id))];
});

typedef SeedRow = ({String title, List<MediaItem> items});

/// Recommendations grouped by the title that produced them, biggest groups
/// first. Rows with fewer than three items aren't worth a carousel.
final becauseYouWatchedProvider = Provider<List<SeedRow>>((ref) {
  final recs = ref.watch(recommendationsProvider).value ?? const <Recommendation>[];
  final groups = <String, List<MediaItem>>{};
  for (final r in recs) {
    if (r.seedName == null) continue;
    groups.putIfAbsent(r.reasonTitle, () => []).add(r.item);
  }
  final rows = groups.entries
      .where((e) => e.value.length >= 3)
      .map((e) => (title: e.key, items: e.value))
      .toList()
    ..sort((a, b) => b.items.length.compareTo(a.items.length));
  return rows.take(3).toList();
});

final categoriesProvider = FutureProvider.family<Categories, MediaKind>((ref, kind) =>
    ref.watch(repositoryProvider).categories(kind, playlistId: ref.watch(activePlaylistProvider)));

/// One home-screen row for a movie category ("Action", "Comedy", …).
final categoryRowProvider = FutureProvider.family<List<MediaItem>, String>((ref, group) async {
  final page = await ref
      .watch(repositoryProvider)
      .list(MediaKind.movie, playlistId: ref.watch(activePlaylistProvider), group: group, limit: 20);
  return page.items;
});

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

/// Most recent watch events, hydrated with their content.
final historyProvider = FutureProvider<List<WatchEvent>>(
    (ref) => ref.watch(repositoryProvider).history().catchError((_) => <WatchEvent>[]));

/// Content ids the user has finished, for "watched" badges on posters.
final watchedIdsProvider = Provider<Set<String>>((ref) => (ref.watch(historyProvider).value ?? const [])
    .where((e) => e.completed && e.kind == MediaKind.movie)
    .map((e) => e.contentId)
    .toSet());

/// Titles added to the playlist since the user last opened the app.
final whatsNewProvider = Provider<List<MediaItem>>((ref) {
  final since = ref.watch(lastSeenProvider);
  final home = ref.watch(homeProvider).value;
  if (home == null || since == null) return const [];
  return [...home.recentMovies, ...home.recentSeries]
      .where((m) => m.createdAt != null && m.createdAt!.isAfter(since))
      .toList()
    ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
});

/// A pending request from another screen to open Browse pre-filtered.
final browseIntentProvider = NotifierProvider<BrowseIntent, ({MediaKind kind, String? group})?>(BrowseIntent.new);

class BrowseIntent extends Notifier<({MediaKind kind, String? group})?> {
  @override
  ({MediaKind kind, String? group})? build() => null;
  void set(MediaKind kind, String? group) => state = (kind: kind, group: group);
  ({MediaKind kind, String? group})? take(MediaKind kind) {
    final s = state;
    if (s == null || s.kind != kind) return null;
    state = null;
    return s;
  }
}

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
