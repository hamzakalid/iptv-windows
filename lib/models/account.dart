import '../core/json.dart';
import 'media.dart';

class User {
  User({required this.id, required this.email});
  final String id;
  final String email;

  factory User.fromJson(Json j) =>
      User(id: jStr(j['_id']) ?? '', email: jStr(j['email']) ?? '');
}

enum PlaylistType { m3u, xtream }

enum PlaylistStatus {
  pending,
  syncing,
  active,
  error;

  static PlaylistStatus parse(Object? v) =>
      PlaylistStatus.values.firstWhere((s) => s.name == jStr(v), orElse: () => PlaylistStatus.pending);
}

class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.channels = 0,
    this.movies = 0,
    this.series = 0,
    this.lastSyncedAt,
    this.lastError,
    this.host,
  });

  final String id;
  final String name;
  final PlaylistType type;
  final PlaylistStatus status;
  final int channels;
  final int movies;
  final int series;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final String? host;

  bool get isBusy => status == PlaylistStatus.pending || status == PlaylistStatus.syncing;

  factory Playlist.fromJson(Json j) {
    // The API docs say `stats`; the server currently sends `counts`.
    final stats = jMap(j['counts']) ?? jMap(j['stats']) ?? const {};
    final config = jMap(j['config']) ?? const {};
    final url = jStr(config['serverUrl']) ?? jStr(config['url']);
    return Playlist(
      id: jStr(j['_id']) ?? '',
      name: jStr(j['name']) ?? 'Playlist',
      type: jStr(j['type']) == 'xtream' ? PlaylistType.xtream : PlaylistType.m3u,
      status: PlaylistStatus.parse(j['status']),
      channels: jInt(stats['channels']) ?? 0,
      movies: jInt(stats['movies']) ?? 0,
      series: jInt(stats['series']) ?? 0,
      lastSyncedAt: jDate(j['lastSyncedAt']),
      lastError: jStr(j['lastSyncError']) ?? jStr(j['lastError']),
      host: url == null ? null : Uri.tryParse(url)?.host,
    );
  }
}

class ContinueItem {
  ContinueItem({
    required this.kind,
    required this.contentId,
    required this.item,
    this.episodeId,
    this.season,
    this.episode,
    this.episodeTitle,
    this.positionSecs = 0,
    this.durationSecs,
    this.progressPct = 0,
  });

  final MediaKind kind;
  final String contentId;
  final MediaItem? item;
  final String? episodeId;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int positionSecs;
  final int? durationSecs;
  final double progressPct;

  factory ContinueItem.fromJson(Json j) {
    final kind = MediaKind.parse(j['contentType']);
    final content = jMap(kind == MediaKind.series ? j['series'] : j['movie']);
    return ContinueItem(
      kind: kind,
      contentId: jStr(j['contentId']) ?? '',
      item: content == null ? null : MediaItem.fromJson(content, kind),
      episodeId: jStr(j['episodeId']),
      season: jInt(j['season']),
      episode: jInt(j['episode']),
      episodeTitle: jStr(j['episodeTitle']),
      positionSecs: jInt(j['positionSecs']) ?? 0,
      durationSecs: jInt(j['durationSecs']),
      progressPct: jDouble(j['progressPct']) ?? 0,
    );
  }
}

class HomeData {
  HomeData({
    required this.playlistId,
    required this.movieCount,
    required this.seriesCount,
    required this.channelCount,
    required this.recentMovies,
    required this.recentSeries,
    required this.topRatedMovies,
    required this.liveChannels,
    required this.continueWatching,
  });

  final String? playlistId;
  final int movieCount;
  final int seriesCount;
  final int channelCount;
  final List<MediaItem> recentMovies;
  final List<MediaItem> recentSeries;
  final List<MediaItem> topRatedMovies;
  final List<MediaItem> liveChannels;
  final List<ContinueItem> continueWatching;

  bool get isEmpty => movieCount + seriesCount + channelCount == 0;

  factory HomeData.fromJson(Json j) {
    final counts = jMap(j['counts']) ?? const {};
    return HomeData(
      playlistId: jStr(j['playlistId']),
      movieCount: jInt(counts['movies']) ?? 0,
      seriesCount: jInt(counts['series']) ?? 0,
      channelCount: jInt(counts['channels']) ?? 0,
      recentMovies: MediaItem.list(j['recentMovies'], MediaKind.movie),
      recentSeries: MediaItem.list(j['recentSeries'], MediaKind.series),
      topRatedMovies: MediaItem.list(j['topRatedMovies'], MediaKind.movie),
      liveChannels: MediaItem.list(j['liveChannels'], MediaKind.channel),
      continueWatching: jMapList(j['continueWatching'])
          .map(ContinueItem.fromJson)
          .where((c) => c.item != null)
          .toList(),
    );
  }
}

class Paged<T> {
  Paged({required this.items, required this.total, required this.offset});
  final List<T> items;
  final int total;
  final int offset;
}

class Categories {
  Categories(this.names, this.hasUncategorized);
  final List<String> names;
  final bool hasUncategorized;

  static const uncategorized = '__uncategorized__';
}

class SearchResults {
  SearchResults({required this.movies, required this.series, required this.channels});
  final List<MediaItem> movies;
  final List<MediaItem> series;
  final List<MediaItem> channels;

  bool get isEmpty => movies.isEmpty && series.isEmpty && channels.isEmpty;
}

class Favorite {
  Favorite({required this.id, required this.kind, required this.contentId, this.item});
  final String id;
  final MediaKind kind;
  final String contentId;
  final MediaItem? item;

  factory Favorite.fromJson(Json j) {
    final kind = MediaKind.parse(j['contentType']);
    final content = jMap(j['content']);
    return Favorite(
      id: jStr(j['_id']) ?? '',
      kind: kind,
      contentId: jStr(j['contentId']) ?? '',
      item: content == null ? null : MediaItem.fromJson(content, kind),
    );
  }
}

enum SortOption {
  recent('Recently added', 'recent'),
  rating('Top rated', 'rating'),
  year('Release year', 'year'),
  name('A – Z', 'name');

  const SortOption(this.label, this.param);
  final String label;
  final String param;
}

/// Sort + filters for a catalogue list. Immutable so it can key providers.
class ListFilter {
  const ListFilter({this.sort = SortOption.recent, this.minRating, this.yearFrom, this.yearTo});
  final SortOption sort;
  final double? minRating;
  final int? yearFrom;
  final int? yearTo;

  bool get isDefault => sort == SortOption.recent && minRating == null && yearFrom == null && yearTo == null;

  ListFilter copyWith({SortOption? sort, double? Function()? minRating, int? Function()? yearFrom, int? Function()? yearTo}) =>
      ListFilter(
        sort: sort ?? this.sort,
        minRating: minRating == null ? this.minRating : minRating(),
        yearFrom: yearFrom == null ? this.yearFrom : yearFrom(),
        yearTo: yearTo == null ? this.yearTo : yearTo(),
      );

  Map<String, dynamic> toQuery() => {
        'sort': sort == SortOption.recent ? null : sort.param,
        'minRating': minRating,
        'yearFrom': yearFrom,
        'yearTo': yearTo,
      };

  @override
  bool operator ==(Object other) =>
      other is ListFilter &&
      other.sort == sort &&
      other.minRating == minRating &&
      other.yearFrom == yearFrom &&
      other.yearTo == yearTo;
  @override
  int get hashCode => Object.hash(sort, minRating, yearFrom, yearTo);
}

/// One row of watch history, hydrated with its content.
class WatchEvent {
  WatchEvent({
    required this.kind,
    required this.contentId,
    required this.item,
    required this.watchedAt,
    this.episodeId,
    this.season,
    this.episode,
    this.episodeTitle,
    this.positionSecs = 0,
    this.durationSecs,
    this.progressPct = 0,
    this.completed = false,
  });

  final MediaKind kind;
  final String contentId;
  final MediaItem? item;
  final DateTime? watchedAt;
  final String? episodeId;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int positionSecs;
  final int? durationSecs;
  final double progressPct;
  final bool completed;

  factory WatchEvent.fromJson(Json j) {
    final kind = MediaKind.parse(j['contentType']);
    final content = jMap(j['content']);
    return WatchEvent(
      kind: kind,
      contentId: jStr(j['contentId']) ?? '',
      item: content == null ? null : MediaItem.fromJson(content, kind),
      watchedAt: jDate(j['watchedAt']),
      episodeId: jStr(j['episodeId']),
      season: jInt(j['season']),
      episode: jInt(j['episode']),
      episodeTitle: jStr(j['episodeTitle']),
      positionSecs: jInt(j['positionSecs']) ?? 0,
      durationSecs: jInt(j['durationSecs']),
      progressPct: jDouble(j['progressPct']) ?? 0,
      completed: jBool(j['completed']),
    );
  }

  String get episodeLabel => season == null ? '' : 'S$season · E${episode ?? '?'}${episodeTitle != null ? ' · $episodeTitle' : ''}';
}

class WatchProgress {
  WatchProgress({required this.positionSecs, this.durationSecs, this.completed = false});
  final int positionSecs;
  final int? durationSecs;
  final bool completed;

  factory WatchProgress.fromJson(Json j) => WatchProgress(
        positionSecs: jInt(j['positionSecs']) ?? 0,
        durationSecs: jInt(j['durationSecs']),
        completed: jBool(j['completed']),
      );
}
