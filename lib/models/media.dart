import '../core/json.dart';

enum MediaKind {
  movie,
  series,
  channel;

  static MediaKind parse(Object? v) => switch (jStr(v)) {
        'series' => MediaKind.series,
        'channel' => MediaKind.channel,
        _ => MediaKind.movie,
      };

  String get label => switch (this) {
        MediaKind.movie => 'Movie',
        MediaKind.series => 'Series',
        MediaKind.channel => 'Live',
      };
}

/// A movie, series or live channel row. The backend uses one shared shape
/// for all three; `details` varies per kind and is parsed lazily.
class MediaItem {
  MediaItem({
    required this.id,
    required this.kind,
    required this.name,
    this.playlistId,
    this.group = '',
    this.logo,
    this.url,
    this.rating,
    this.year,
    this.details,
    this.raw = const {},
  });

  final String id;
  final MediaKind kind;
  final String name;
  final String? playlistId;
  final String group;
  final String? logo;
  final String? url;
  final double? rating;
  final int? year;
  final Json? details;
  final Json raw;

  factory MediaItem.fromJson(Json j, MediaKind kind) => MediaItem(
        id: jStr(j['_id']) ?? '',
        kind: kind,
        name: jStr(j['name']) ?? 'Untitled',
        playlistId: jStr(j['playlistId']),
        group: jStr(j['group']) ?? '',
        logo: jStr(j['logo']),
        url: jStr(j['url']),
        rating: jDouble(j['rating']),
        year: jInt(j['year']),
        details: jMap(j['details']),
        raw: j,
      );

  static List<MediaItem> list(Object? v, MediaKind kind) =>
      jMapList(v).map((j) => MediaItem.fromJson(j, kind)).toList();

  /// Wide artwork for heroes; falls back to the poster.
  String? get backdrop {
    final b = jStrList(details?['backdrop']);
    return b.isNotEmpty ? b.first : logo;
  }

  String? get plot => jStr(details?['plot']);
  String? get genre => jStr(details?['genre']);
}

class Actor {
  Actor({required this.id, required this.name, this.profileUrl, this.biography});

  final String? id;
  final String name;
  final String? profileUrl;
  final String? biography;

  factory Actor.fromJson(Json j) {
    final path = jStr(j['profilePath']);
    return Actor(
      id: jStr(j['_id']) ?? jStr(j['actorId']),
      name: jStr(j['displayName']) ?? jStr(j['name']) ?? 'Unknown',
      profileUrl: jStr(j['profileUrl']) ??
          (path != null ? 'https://image.tmdb.org/t/p/w185$path' : null),
      biography: jStr(j['biography']),
    );
  }
}

class MovieDetails {
  MovieDetails(this.item);
  final MediaItem item;

  Json get _d => item.details ?? const {};
  String? get plot => jStr(_d['plot']);
  String? get director => jStr(_d['director']) ?? jStrList(_d['directors']).firstOrNull;
  String? get genre => jStr(_d['genre']) ?? jStrList(_d['genres']).join(', ').nullIfEmpty;
  String? get releaseDate => jStr(_d['releaseDate']);
  int? get durationSecs => jInt(_d['durationSecs']);
  String? get trailer => jStr(_d['trailer']) ?? jStr(_d['trailerYoutubeId']);
  List<Actor> get actors {
    final resolved = jMapList(_d['actors']).map(Actor.fromJson).toList();
    if (resolved.isNotEmpty) return resolved;
    return jStrList(_d['cast']).map((n) => Actor(id: null, name: n)).toList();
  }
}

class Episode {
  Episode({
    required this.id,
    required this.season,
    required this.episode,
    required this.title,
    required this.url,
    this.plot,
    this.durationSecs,
    this.thumb,
  });

  final String id;
  final int season;
  final int episode;
  final String title;
  final String url;
  final String? plot;
  final int? durationSecs;
  final String? thumb;

  factory Episode.fromJson(Json j, {int? season}) => Episode(
        id: jStr(j['id']) ?? '',
        season: jInt(j['season']) ?? season ?? 1,
        episode: jInt(j['episode']) ?? 0,
        title: jStr(j['title']) ?? 'Episode',
        url: jStr(j['url']) ?? '',
        plot: jStr(j['plot']),
        durationSecs: jInt(j['durationSecs']),
        thumb: jStr(j['thumb']) ?? jStr(j['still']),
      );

  /// Episodes arrive either as a flat array or as `{ "1": [...], "2": [...] }`.
  static Map<int, List<Episode>> bySeason(Object? raw) {
    final all = <Episode>[];
    if (raw is List) {
      all.addAll(jMapList(raw).map(Episode.fromJson));
    } else if (raw is Map) {
      raw.forEach((k, v) {
        final s = jInt(k);
        all.addAll(jMapList(v).map((e) => Episode.fromJson(e, season: s)));
      });
    }
    final out = <int, List<Episode>>{};
    for (final e in all.where((e) => e.url.isNotEmpty)) {
      out.putIfAbsent(e.season, () => []).add(e);
    }
    for (final l in out.values) {
      l.sort((a, b) => a.episode.compareTo(b.episode));
    }
    return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }
}

class EpgEntry {
  EpgEntry({required this.title, this.description, this.start, this.end});

  final String title;
  final String? description;
  final DateTime? start;
  final DateTime? end;

  factory EpgEntry.fromJson(Json j) => EpgEntry(
        title: jStr(j['title']) ?? 'Programme',
        description: jStr(j['description']),
        start: jDate(j['startAt'] ?? j['start']),
        end: jDate(j['endAt'] ?? j['stop']),
      );

  static EpgEntry? maybe(Object? v) {
    final m = jMap(v);
    return m == null ? null : EpgEntry.fromJson(m);
  }

  double get progress {
    if (start == null || end == null) return 0;
    final total = end!.difference(start!).inSeconds;
    if (total <= 0) return 0;
    final done = DateTime.now().difference(start!).inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }
}

class ChannelEpg {
  ChannelEpg({this.now, this.next, this.upcoming = const []});
  final EpgEntry? now;
  final EpgEntry? next;
  final List<EpgEntry> upcoming;

  factory ChannelEpg.fromDetails(Json? d) => ChannelEpg(
        now: EpgEntry.maybe(d?['now']),
        next: EpgEntry.maybe(d?['next']),
        upcoming: jMapList(d?['upcoming']).map(EpgEntry.fromJson).toList(),
      );
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
