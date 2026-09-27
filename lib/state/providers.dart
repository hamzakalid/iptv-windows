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

/// User-level discovery from `/suggestions`: built from the user's history
/// across every playlist, so switching the active IPTV account doesn't
/// change it. Errors degrade to an empty payload.
final suggestionsProvider = FutureProvider<Suggestions>(
    (ref) => ref.watch(repositoryProvider).suggestions().catchError((_) => Suggestions()));

/// Flat "For you" list. Personalised picks come first; when there are few
/// (new account, small library) the row is topped up with the best-rated
/// titles the user hasn't finished, so it never looks empty.
final forYouProvider = Provider<List<MediaItem>>((ref) {
  final recs = (ref.watch(suggestionsProvider).value?.suggested ?? const <Suggestion>[]).map((r) => r.item).toList();
  if (recs.length >= 8) return recs;
  final watched = ref.watch(watchedIdsProvider);
  final seen = recs.map((m) => m.id).toSet();
  final top = ref.watch(homeProvider).value?.topRatedMovies ?? const <MediaItem>[];
  return [...recs, ...top.where((m) => !watched.contains(m.id) && seen.add(m.id))];
});

typedef SeedRow = ({String title, List<MediaItem> items});

/// "Because you watched …" rows, biggest first (the server already drops
/// rows with fewer than three titles).
final becauseYouWatchedProvider = Provider<List<SeedRow>>((ref) {
  final rows = ref.watch(suggestionsProvider).value?.becauseYouWatched ?? const <BecauseRow>[];
  return rows.map((r) => (title: r.title, items: r.items.map((s) => s.item).toList())).take(3).toList();
});

/// Hero slides from `/home/featured` (TMDB trending ∩ catalogue). Empty on
/// error so Home falls back to library picks.
final featuredProvider = FutureProvider<Featured>((ref) =>
    ref.watch(repositoryProvider).featured().catchError((_) => Featured(source: 'none', items: const [])));

typedef ActorsQuery = ({String q, String sort, bool withPhoto});

/// First page of actors for a query; the Actors screen pages further itself.
final actorsProvider = FutureProvider.autoDispose.family<Paged<Actor>, ActorsQuery>((ref, q) =>
    ref.watch(repositoryProvider).actors(q: q.q, sort: q.sort, withPhoto: q.withPhoto, limit: 60));

/// Actors with the most credits in the library, for the Home row.
final topActorsProvider = FutureProvider<List<Actor>>((ref) => ref
    .watch(repositoryProvider)
    .actors(sort: 'titles', withPhoto: true, limit: 18)
    .then((p) => p.items)
    .catchError((_) => <Actor>[]));

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

final actorProvider =
    FutureProvider.autoDispose.family<ActorPage, String>((ref, id) => ref.watch(repositoryProvider).actor(id));

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
typedef BrowseRequest = ({MediaKind kind, String? group, SortOption? sort});

final browseIntentProvider = NotifierProvider<BrowseIntent, BrowseRequest?>(BrowseIntent.new);

class BrowseIntent extends Notifier<BrowseRequest?> {
  @override
  BrowseRequest? build() => null;
  void set(MediaKind kind, String? group, {SortOption? sort}) => state = (kind: kind, group: group, sort: sort);
  BrowseRequest? take(MediaKind kind) {
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

/// Now/next EPG for one channel. List rows carry cached `details` when the
/// server has them; otherwise the detail endpoint fetches the short EPG.
/// Kept for a few minutes so cards, the player and the guide share it.
final channelEpgProvider = FutureProvider.autoDispose.family<ChannelEpg?, String>((ref, id) async {
  final link = ref.keepAlive();
  final t = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(t.cancel);
  try {
    final c = await ref.watch(repositoryProvider).detail(MediaKind.channel, id);
    return c.details == null ? null : ChannelEpg.fromDetails(c.details);
  } catch (_) {
    return null;
  }
});

/// EPG straight from a list row, when the server already cached it.
ChannelEpg? cachedEpg(MediaItem channel) =>
    channel.details == null ? null : ChannelEpg.fromDetails(channel.details);

/// Channels the user watched most recently, newest first (from history).
final recentChannelsProvider = Provider<List<MediaItem>>((ref) {
  final seen = <String>{};
  return (ref.watch(historyProvider).value ?? const <WatchEvent>[])
      .where((e) => e.kind == MediaKind.channel && e.item != null && seen.add(e.contentId))
      .map((e) => e.item!)
      .take(8)
      .toList();
});

/// Bumped to ask the Search screen to focus its field (the `/` shortcut).
final searchFocusRequestProvider = NotifierProvider<SearchFocusRequest, int>(SearchFocusRequest.new);

class SearchFocusRequest extends Notifier<int> {
  @override
  int build() => 0;
  void request() => state++;
}

/// Recent search terms, persisted, newest first (max 6).
final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);

class RecentSearches extends Notifier<List<String>> {
  static const _key = 'recent_searches';

  @override
  List<String> build() => ref.read(prefsProvider).getStringList(_key) ?? const [];

  void add(String q) {
    final v = q.trim().toLowerCase();
    if (v.isEmpty) return;
    _save([v, ...state.where((s) => s != v)].take(6).toList());
  }

  void remove(String q) => _save(state.where((s) => s != q).toList());

  void _save(List<String> next) {
    ref.read(prefsProvider).setStringList(_key, next);
    state = next;
  }
}

/// Watch progress (0–1) by content id, from Continue watching.
final progressByIdProvider = Provider<Map<String, double>>((ref) => {
      for (final c in ref.watch(homeProvider).value?.continueWatching ?? const <ContinueItem>[])
        c.contentId: (c.progressPct / 100).clamp(0.0, 1.0),
    });

/// Content id of whatever is playing (full screen or picture-in-picture),
/// so cards can show a "Playing" tag.
final playingContentIdProvider = NotifierProvider<PlayingContentId, String?>(PlayingContentId.new);

class PlayingContentId extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}
