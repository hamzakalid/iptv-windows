import '../core/json.dart';
import '../models/account.dart';
import '../models/media.dart';
import 'api_client.dart';

String _path(MediaKind kind) => switch (kind) {
      MediaKind.movie => '/movies',
      MediaKind.series => '/series',
      MediaKind.channel => '/channels',
    };

/// Every backend endpoint the app uses, typed.
class IptvRepository {
  IptvRepository(this.api);
  final ApiClient api;

  // ---- Auth ----------------------------------------------------------------

  Future<(String, User)> login(String email, String password, {bool signup = false}) async {
    final j = jMap(await api.post(signup ? '/auth/signup' : '/auth/login', {
      'email': email,
      'password': password,
    }))!;
    return (jStr(j['token'])!, User.fromJson(jMap(j['user'])!));
  }

  Future<User> me() async => User.fromJson(jMap(jMap(await api.get('/auth/me'))!['user'])!);

  // ---- Playlists -----------------------------------------------------------

  Future<List<Playlist>> playlists() async =>
      jMapList(await api.get('/playlists')).map(Playlist.fromJson).toList();

  Json _playlistBody(String name, PlaylistType type, Map<String, String> config) =>
      {'name': name, 'type': type.name, 'config': config};

  Future<Json> testPlaylist(String name, PlaylistType type, Map<String, String> config) async =>
      jMap(await api.post('/playlists/test', _playlistBody(name, type, config))) ?? {};

  Future<Playlist> createPlaylist(String name, PlaylistType type, Map<String, String> config) async =>
      Playlist.fromJson(jMap(await api.post('/playlists', _playlistBody(name, type, config)))!);

  Future<void> syncPlaylist(String id) => api.post('/playlists/$id/sync');

  Future<void> syncIfStale(String id) => api.post('/playlists/$id/sync-if-stale');

  Future<void> deletePlaylist(String id) => api.delete('/playlists/$id');

  // ---- Catalogue -----------------------------------------------------------

  Future<HomeData> home({String? playlistId}) async =>
      HomeData.fromJson(jMap(await api.get('/home', query: {'playlistId': playlistId}))!);

  Future<Paged<MediaItem>> list(
    MediaKind kind, {
    String? playlistId,
    String? group,
    String? q,
    ListFilter filter = const ListFilter(),
    int offset = 0,
    int limit = 60,
  }) async {
    final j = jMap(await api.get(_path(kind), query: {
      'playlistId': playlistId,
      'group': group,
      'q': q,
      ...filter.toQuery(),
      'offset': offset,
      'limit': limit,
    }))!;
    return Paged(
      items: MediaItem.list(j['items'], kind),
      total: jInt(j['total']) ?? 0,
      offset: jInt(j['offset']) ?? offset,
    );
  }

  Future<Categories> categories(MediaKind kind, {String? playlistId}) async {
    final j = jMap(await api.get('${_path(kind)}/categories', query: {'playlistId': playlistId}))!;
    return Categories(jStrList(j['categories']), jBool(j['hasUncategorized']));
  }

  Future<MediaItem> detail(MediaKind kind, String id) async =>
      MediaItem.fromJson(jMap(await api.get('${_path(kind)}/$id'))!, kind);

  Future<List<MediaItem>> similar(MediaKind kind, String id, {int limit = 12}) async {
    final j = jMap(await api.get('${_path(kind)}/$id/similar', query: {'limit': limit}))!;
    return jMapList(j['items']).map((row) {
      // Movies/series wrap rows as { type, score, content }; channels don't.
      final content = jMap(row['content']);
      if (content == null) return MediaItem.fromJson(row, kind);
      return MediaItem.fromJson(content, MediaKind.parse(row['type']));
    }).toList();
  }

  Future<SearchResults> search(String q, {String? playlistId}) async {
    final j = jMap(await api.get('/search', query: {'q': q, 'playlistId': playlistId, 'limit': 30}))!;
    return SearchResults(
      movies: MediaItem.list(j['movies'], MediaKind.movie),
      series: MediaItem.list(j['series'], MediaKind.series),
      channels: MediaItem.list(j['channels'], MediaKind.channel),
    );
  }

  Future<List<Recommendation>> recommendations({String? playlistId}) async {
    final j = jMap(await api.get('/recommendations', query: {'playlistId': playlistId, 'limit': 40}))!;
    return jMapList(j['items']).where((r) => jMap(r['content']) != null).map(Recommendation.fromJson).toList();
  }

  /// A random item matching the same scope as a list, for "Surprise me".
  Future<MediaItem?> random(
    MediaKind kind, {
    String? playlistId,
    String? group,
    ListFilter filter = const ListFilter(),
    int total = 0,
  }) async {
    if (total <= 0) {
      total = (await list(kind, playlistId: playlistId, group: group, filter: filter, limit: 1)).total;
      if (total == 0) return null;
    }
    final offset = DateTime.now().microsecondsSinceEpoch % total;
    final page = await list(kind, playlistId: playlistId, group: group, filter: filter, offset: offset, limit: 1);
    return page.items.firstOrNull;
  }

  Future<(Actor, List<MediaItem>)> actor(String id) async {
    final j = jMap(await api.get('/actors/$id'))!;
    return (
      Actor.fromJson(jMap(j['actor'])!),
      [
        ...MediaItem.list(j['movies'], MediaKind.movie),
        ...MediaItem.list(j['series'], MediaKind.series),
      ],
    );
  }

  // ---- Watch progress ------------------------------------------------------

  Future<void> reportProgress({
    required MediaKind kind,
    required String contentId,
    Episode? episode,
    int? positionSecs,
    int? durationSecs,
  }) =>
      api.post('/watch-events', {
        'contentType': kind.name,
        'contentId': contentId,
        if (episode != null) ...{
          'episodeId': episode.id,
          'season': episode.season,
          'episode': episode.episode,
          'episodeTitle': episode.title,
        },
        'positionSecs': ?positionSecs,
        'durationSecs': ?durationSecs,
      });

  Future<List<WatchEvent>> history({int limit = 100}) async {
    final j = jMap(await api.get('/watch-events', query: {'limit': limit, 'hydrate': 1}))!;
    return jMapList(j['events']).map(WatchEvent.fromJson).toList();
  }

  Future<WatchProgress?> progressFor(String contentId, {String? episodeId}) async {
    try {
      final j = jMap(await api.get('/watch-events/by-content',
          query: {'contentId': contentId, 'episodeId': episodeId}));
      return j == null ? null : WatchProgress.fromJson(j);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  // ---- Favorites -----------------------------------------------------------

  Future<List<Favorite>> favorites() async {
    final j = jMap(await api.get('/favorites'))!;
    return jMapList(j['items']).map(Favorite.fromJson).where((f) => f.item != null).toList();
  }

  Future<void> addFavorite(MediaItem item) => api.post('/favorites', {
        'playlistId': item.playlistId,
        'contentType': item.kind.name,
        'contentId': item.id,
      });

  Future<void> removeFavorite(String favoriteId) => api.delete('/favorites/$favoriteId');
}
