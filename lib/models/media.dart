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
    this.createdAt,
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
  final DateTime? createdAt;
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
        createdAt: jDate(j['createdAt']),
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
  int? get durationSecs => jInt(details?['durationSecs']);

  /// Provider genre strings look like "Action, Adventure / Sci-Fi".
  List<String> get genres => (genre ?? '')
      .split(RegExp(r'[,/|]'))
      .map((g) => g.trim())
      .where((g) => g.isNotEmpty)
      .toList();

  bool get hasArtwork => logo != null || backdrop != null;

  /// Channel number, when the provider sends one (Xtream `num`).
  String? get number => jStr(raw['num']) ?? jStr(raw['number']) ?? jStr(details?['num']);

  /// Now/next programme for channels whose rows carry EPG.
  ChannelEpg get epg => ChannelEpg.fromDetails(details);
}

/// A recommended item plus the title that led to it ("Because you watched…").
class Recommendation {
  Recommendation({required this.item, this.seedName, this.seedId, this.seedKind});
  final MediaItem item;
  final String? seedName;
  final String? seedId;

  /// `watched` or `favorited` — which signal produced this pick.
  final String? seedKind;

  factory Recommendation.fromJson(Json j) {
    final reasons = jMapList(j['reasons']);
    final first = reasons.isEmpty ? null : reasons.first;
    return Recommendation(
      item: MediaItem.fromJson(jMap(j['content'])!, MediaKind.parse(j['type'])),
      seedName: jStr(first?['seedName']),
      seedId: jStr(first?['seedId']),
      seedKind: jStr(first?['kind']),
    );
  }

  /// Row title for a group of picks sharing this seed.
  String get reasonTitle =>
      seedKind == 'favorited' ? 'Because you saved $seedName' : 'Because you watched $seedName';
}

class Actor {
  Actor({
    required this.id,
    required this.name,
    this.profileUrl,
    this.biography,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.knownFor,
    this.popularity,
    this.movieCount = 0,
    this.seriesCount = 0,
  });

  final String? id;
  final String name;
  final String? profileUrl;
  final String? biography;
  final DateTime? birthday;
  final DateTime? deathday;
  final String? placeOfBirth;
  final String? knownFor;
  final double? popularity;

  /// Credits in the user's library (from `GET /actors`).
  final int movieCount;
  final int seriesCount;

  int get titleCount => movieCount + seriesCount;
  bool get hasPhoto => profileUrl != null && profileUrl!.startsWith('http');

  /// Age today, or at death.
  int? get age {
    final b = birthday;
    if (b == null) return null;
    final end = deathday ?? DateTime.now();
    var years = end.year - b.year;
    if (end.month < b.month || (end.month == b.month && end.day < b.day)) years--;
    return years < 0 ? null : years;
  }

  /// "2 movies · 1 series"
  String get creditsLabel => [
        if (movieCount > 0) '$movieCount movie${movieCount == 1 ? '' : 's'}',
        if (seriesCount > 0) '$seriesCount series',
      ].join(' · ');

  factory Actor.fromJson(Json j) {
    final path = jStr(j['profilePath']);
    return Actor(
      id: jStr(j['_id']) ?? jStr(j['actorId']),
      name: jStr(j['displayName']) ?? jStr(j['name']) ?? 'Unknown',
      profileUrl: jStr(j['profileUrl']) ??
          (path != null ? 'https://image.tmdb.org/t/p/w185$path' : null),
      biography: jStr(j['biography']),
      birthday: jDate(j['birthday']),
      deathday: jDate(j['deathday']),
      placeOfBirth: jStr(j['placeOfBirth']),
      knownFor: jStr(j['knownForDepartment']),
      popularity: jDouble(j['popularity']),
      movieCount: jInt(j['movieCount']) ?? 0,
      seriesCount: jInt(j['seriesCount']) ?? 0,
    );
  }
}

/// `GET /actors/:id`: the actor plus their movies and series in the library.
class ActorPage {
  ActorPage({required this.actor, required this.movies, required this.series});
  final Actor actor;
  final List<MediaItem> movies;
  final List<MediaItem> series;

  int get total => movies.length + series.length;

  factory ActorPage.fromJson(Json j) => ActorPage(
        actor: Actor.fromJson(jMap(j['actor']) ?? const {}),
        movies: MediaItem.list(j['movies'], MediaKind.movie),
        series: MediaItem.list(j['series'], MediaKind.series),
      );
}

/// A Home hero slide: a title trending on TMDB that also exists in the
/// user's catalogue, with TMDB artwork. `item` is the playable row.
class FeaturedItem {
  FeaturedItem({
    required this.item,
    required this.title,
    this.source = 'catalog',
    this.tmdbId,
    this.overview,
    this.year,
    this.rating,
    this.voteCount,
    this.posterUrl,
    this.backdropUrl,
  });

  final MediaItem item;
  final String title;

  /// `tmdb` when matched against what's trending, `catalog` for a library pick.
  final String source;
  final int? tmdbId;
  final String? overview;
  final int? year;
  final double? rating;
  final int? voteCount;
  final String? posterUrl;
  final String? backdropUrl;

  bool get isTrending => source == 'tmdb';
  String? get plot => overview ?? item.plot;
  String? get backdrop => backdropUrl ?? item.backdrop;
  String? get poster => posterUrl ?? item.logo;

  factory FeaturedItem.fromJson(Json j) {
    final kind = MediaKind.parse(j['kind']);
    final item = MediaItem.fromJson(jMap(j['content'])!, kind);
    return FeaturedItem(
      item: item,
      title: jStr(j['title']) ?? item.name,
      source: jStr(j['source']) ?? 'catalog',
      tmdbId: jInt(j['tmdbId']),
      overview: jStr(j['overview']),
      year: jInt(j['year']) ?? item.year,
      rating: jDouble(j['rating']) ?? item.rating,
      voteCount: jInt(j['voteCount']),
      posterUrl: jStr(j['posterUrl']),
      backdropUrl: jStr(j['backdropUrl']),
    );
  }

  /// A library title standing in for the hero when TMDB isn't available.
  factory FeaturedItem.fromMedia(MediaItem m) =>
      FeaturedItem(item: m, title: m.name, year: m.year, rating: m.rating);

  static List<FeaturedItem> list(Object? v) =>
      jMapList(v).where((j) => jMap(j['content']) != null).map(FeaturedItem.fromJson).toList();
}

/// `GET /home/featured`.
class Featured {
  Featured({required this.source, required this.items, this.matched = 0});
  final String source;
  final List<FeaturedItem> items;
  final int matched;

  factory Featured.fromJson(Json j) => Featured(
        source: jStr(j['source']) ?? 'none',
        items: FeaturedItem.list(j['items']),
        matched: jInt(j['matched']) ?? 0,
      );
}

/// Why a title was suggested ("Because you watched Dune", "You watch Sci-Fi").
class SuggestionReason {
  SuggestionReason({required this.kind, required this.label, this.seedId, this.seedName, this.actorId});
  final String kind;
  final String label;
  final String? seedId;
  final String? seedName;
  final String? actorId;

  factory SuggestionReason.fromJson(Json j) => SuggestionReason(
        kind: jStr(j['kind']) ?? '',
        label: jStr(j['label']) ?? '',
        seedId: jStr(j['seedId']),
        seedName: jStr(j['seedName']),
        actorId: jStr(j['actorId']),
      );
}

class Suggestion {
  Suggestion({required this.item, this.score = 0, this.reasons = const []});
  final MediaItem item;
  final double score;
  final List<SuggestionReason> reasons;

  String? get reason => reasons.firstOrNull?.label;

  factory Suggestion.fromJson(Json j) => Suggestion(
        item: MediaItem.fromJson(jMap(j['content'])!, MediaKind.parse(j['type'])),
        score: jDouble(j['score']) ?? 0,
        reasons: jMapList(j['reasons']).map(SuggestionReason.fromJson).toList(),
      );

  static List<Suggestion> list(Object? v) =>
      jMapList(v).where((j) => jMap(j['content']) != null).map(Suggestion.fromJson).toList();
}

/// One of the user's most-watched titles, with accumulated watch time.
class MostWatched {
  MostWatched({
    required this.item,
    this.watchedSecs = 0,
    this.playCount = 0,
    this.episodesWatched = 0,
    this.lastWatchedAt,
    this.completed = false,
  });
  final MediaItem item;
  final int watchedSecs;
  final int playCount;
  final int episodesWatched;
  final DateTime? lastWatchedAt;
  final bool completed;

  factory MostWatched.fromJson(Json j) => MostWatched(
        item: MediaItem.fromJson(jMap(j['content'])!, MediaKind.parse(j['type'])),
        watchedSecs: jInt(j['watchedSecs']) ?? 0,
        playCount: jInt(j['playCount']) ?? 0,
        episodesWatched: jInt(j['episodesWatched']) ?? 0,
        lastWatchedAt: jDate(j['lastWatchedAt']),
        completed: jBool(j['completed']),
      );

  /// "8 episodes · 5h 06m" / "Watched 3× · 4h 12m".
  String get label {
    final time = watchedSecs >= 60 ? _hm(watchedSecs) : null;
    final parts = <String>[
      if (item.kind == MediaKind.series && episodesWatched > 0)
        '$episodesWatched episode${episodesWatched == 1 ? '' : 's'}'
      else if (playCount > 1)
        'Watched $playCount×',
      ?time,
    ];
    return parts.isEmpty ? (completed ? 'Finished' : 'Watched') : parts.join(' · ');
  }

  static String _hm(int secs) {
    final m = (secs / 60).round();
    return m >= 60 ? '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m' : '${m}m';
  }
}

/// "Because you watched X" row from `/suggestions`.
class BecauseRow {
  BecauseRow({required this.seedId, required this.seedName, required this.title, required this.items, this.seedKind = 'watched'});
  final String seedId;
  final String seedName;
  final String seedKind;
  final String title;
  final List<Suggestion> items;

  factory BecauseRow.fromJson(Json j) {
    final seed = jMap(j['seed']) ?? const {};
    final name = jStr(seed['name']) ?? '';
    return BecauseRow(
      seedId: jStr(seed['id']) ?? '',
      seedName: name,
      seedKind: jStr(seed['signal']) ?? 'watched',
      title: jStr(j['title']) ?? 'Because you watched $name',
      items: Suggestion.list(j['items']),
    );
  }
}

/// `GET /suggestions` — built from the user's history across every playlist,
/// independent of the active IPTV account.
class Suggestions {
  Suggestions({
    this.basis = 'none',
    this.seedCount = 0,
    this.genres = const [],
    this.suggested = const [],
    this.newArrivals = const [],
    this.mostWatched = const [],
    this.becauseYouWatched = const [],
  });

  /// `history`, `favorites` or `none`.
  final String basis;
  final int seedCount;
  final List<String> genres;
  final List<Suggestion> suggested;
  final List<Suggestion> newArrivals;
  final List<MostWatched> mostWatched;
  final List<BecauseRow> becauseYouWatched;

  bool get isPersonalised => basis != 'none';
  bool get isEmpty => suggested.isEmpty && newArrivals.isEmpty && mostWatched.isEmpty;

  /// Short line explaining what the picks are based on.
  String get basisLabel => switch (basis) {
        'history' => genres.isEmpty ? 'Based on what you watch' : 'Because you watch ${genres.take(2).join(' and ')}',
        'favorites' => 'Based on your saved titles',
        _ => 'Top picks from your library',
      };

  factory Suggestions.fromJson(Json j) {
    final profile = jMap(j['profile']) ?? const {};
    return Suggestions(
      basis: jStr(profile['basis']) ?? 'none',
      seedCount: jInt(profile['seedCount']) ?? 0,
      genres: jMapList(profile['genres']).map((g) => jStr(g['name'])).whereType<String>().toList(),
      suggested: Suggestion.list(j['suggested']),
      newArrivals: Suggestion.list(j['newArrivals']),
      mostWatched: jMapList(j['mostWatched']).where((m) => jMap(m['content']) != null).map(MostWatched.fromJson).toList(),
      becauseYouWatched: jMapList(j['becauseYouWatched']).map(BecauseRow.fromJson).where((r) => r.items.isNotEmpty).toList(),
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
