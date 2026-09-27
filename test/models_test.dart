import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/data/api_client.dart';
import 'package:iptv_app/models/account.dart';
import 'package:iptv_app/models/media.dart';

void main() {
  _moreTests();
  _discoveryTests();
  group('ApiClient.normalizeBaseUrl', () {
    test('adds scheme and /api', () {
      expect(ApiClient.normalizeBaseUrl('192.168.1.5:4000'), 'http://192.168.1.5:4000/api');
      expect(ApiClient.normalizeBaseUrl('https://tv.example.com/'), 'https://tv.example.com/api');
      expect(ApiClient.normalizeBaseUrl('http://h:4000/api'), 'http://h:4000/api');
    });
  });

  group('MediaItem', () {
    test('parses lenient numbers and backdrop', () {
      final m = MediaItem.fromJson({
        '_id': 'a1',
        'name': 'Dune',
        'rating': '8.2',
        'year': 2021,
        'logo': 'https://img/p.jpg',
        'details': {
          'backdrop': ['https://img/b.jpg'],
          'plot': 'Spice',
        },
      }, MediaKind.movie);
      expect(m.rating, 8.2);
      expect(m.backdrop, 'https://img/b.jpg');
      expect(m.plot, 'Spice');
    });

    test('falls back to poster when no backdrop', () {
      final m = MediaItem.fromJson({'_id': 'x', 'name': 'N', 'logo': 'https://img/p.jpg'}, MediaKind.series);
      expect(m.backdrop, 'https://img/p.jpg');
    });
  });

  group('Episode.bySeason', () {
    test('groups a flat array (current backend shape)', () {
      final s = Episode.bySeason([
        {'id': '3', 'season': 2, 'episode': 1, 'title': 'C', 'url': 'u3'},
        {'id': '2', 'season': 1, 'episode': 2, 'title': 'B', 'url': 'u2'},
        {'id': '1', 'season': 1, 'episode': 1, 'title': 'A', 'url': 'u1'},
      ]);
      expect(s.keys, [1, 2]);
      expect(s[1]!.map((e) => e.id), ['1', '2']);
    });

    test('groups a season-keyed map (documented shape)', () {
      final s = Episode.bySeason({
        '1': [
          {'id': 'ep1', 'episode': 1, 'title': 'Pilot', 'url': 'u', 'still': 'img'},
        ],
      });
      expect(s[1]!.single.thumb, 'img');
      expect(s[1]!.single.season, 1);
    });
  });

  test('MovieDetails prefers resolved actors, falls back to cast', () {
    final withActors = MovieDetails(MediaItem.fromJson({
      '_id': 'm',
      'name': 'M',
      'details': {
        'cast': ['A', 'B'],
        'actors': [
          {'actorId': 'x', 'name': 'A', 'profileUrl': 'https://p'},
        ],
      },
    }, MediaKind.movie));
    expect(withActors.actors.single.id, 'x');

    final castOnly = MovieDetails(MediaItem.fromJson({
      '_id': 'm',
      'name': 'M',
      'details': {'cast': 'A, B'},
    }, MediaKind.movie));
    expect(castOnly.actors.map((a) => a.name), ['A', 'B']);
  });

  test('HomeData drops continue-watching rows without content', () {
    final h = HomeData.fromJson({
      'playlistId': 'p',
      'counts': {'movies': 1, 'series': 0, 'channels': 0},
      'continueWatching': [
        {'contentType': 'movie', 'contentId': 'm', 'progressPct': 40, 'movie': {'_id': 'm', 'name': 'M'}},
        {'contentType': 'movie', 'contentId': 'gone', 'movie': null},
      ],
    });
    expect(h.continueWatching.single.item!.name, 'M');
    expect(h.isEmpty, false);
  });

  test('Playlist reads stats and host', () {
    final p = Playlist.fromJson({
      '_id': 'p',
      'name': 'Prov',
      'type': 'xtream',
      'status': 'syncing',
      'config': {'serverUrl': 'http://tv.host:8080'},
      'counts': {'channels': 10, 'movies': 5, 'series': 2},
      'lastSyncError': 'boom',
    });
    expect(p.isBusy, true);
    expect(p.host, 'tv.host');
    expect(p.channels, 10);
    expect(p.lastError, 'boom');
  });
}

void _moreTests() {
  group('ListFilter', () {
    test('default filter sends no sort/filter params', () {
      final q = const ListFilter().toQuery();
      expect(q.values.every((v) => v == null), isTrue);
      expect(const ListFilter().isDefault, isTrue);
    });

    test('serialises sort, rating and year bounds', () {
      const f = ListFilter(sort: SortOption.rating, minRating: 7, yearFrom: 2010, yearTo: 2020);
      expect(f.toQuery(), {'sort': 'rating', 'minRating': 7.0, 'yearFrom': 2010, 'yearTo': 2020});
      expect(f.copyWith(minRating: () => null).minRating, isNull);
      expect(f.copyWith(sort: SortOption.name), const ListFilter(sort: SortOption.name, minRating: 7, yearFrom: 2010, yearTo: 2020));
    });
  });

  test('Recommendation keeps the seed that produced it', () {
    final r = Recommendation.fromJson({
      'type': 'series',
      'reasons': [
        {'kind': 'watched', 'seedId': 's1', 'seedName': 'Dune'},
      ],
      'content': {'_id': 'x', 'name': 'Foundation'},
    });
    expect(r.item.kind, MediaKind.series);
    expect(r.seedName, 'Dune');
    expect(r.reasonTitle, 'Because you watched Dune');
    final saved = Recommendation.fromJson({
      'type': 'movie',
      'reasons': [{'kind': 'favorited', 'seedName': 'Heat'}],
      'content': {'_id': 'y', 'name': 'Collateral'},
    });
    expect(saved.reasonTitle, 'Because you saved Heat');
  });

  test('WatchEvent parses a hydrated history row', () {
    final e = WatchEvent.fromJson({
      'contentType': 'series',
      'contentId': 'c1',
      'season': 2,
      'episode': 4,
      'episodeTitle': 'Pilot',
      'positionSecs': 300,
      'durationSecs': 2400,
      'progressPct': 12.5,
      'completed': false,
      'watchedAt': '2026-09-27T10:00:00Z',
      'content': {'_id': 'c1', 'name': 'Severance'},
    });
    expect(e.item!.name, 'Severance');
    expect(e.episodeLabel, 'S2 · E4 · Pilot');
    expect(e.progressPct, 12.5);
    expect(e.watchedAt, isNotNull);
  });

  test('MediaItem splits provider genre strings', () {
    final m = MediaItem.fromJson({
      '_id': 'g',
      'name': 'G',
      'details': {'genre': 'Action, Adventure / Sci-Fi', 'durationSecs': '5400'},
    }, MediaKind.movie);
    expect(m.genres, ['Action', 'Adventure', 'Sci-Fi']);
    expect(m.durationSecs, 5400);
  });
}

void _discoveryTests() {
  group('Categories', () {
    test('parses provider items with counts and keeps provider order', () {
      final c = Categories.fromJson({
        'categories': ['Action', 'Drama'],
        'hasUncategorized': true,
        'uncategorizedCount': 3,
        'total': 20,
        'items': [
          {'id': 'x', 'externalId': '21', 'name': 'Drama', 'order': 0, 'count': 12},
          {'id': 'y', 'externalId': '20', 'name': 'Action', 'order': 1, 'count': 5},
        ],
      });
      expect(c.names, ['Action', 'Drama']);
      expect(c.ordered, ['Drama', 'Action']);
      expect(c.countFor('Drama'), 12);
      expect(c.countFor(null), 20);
      expect(c.countFor(Categories.uncategorized), 3);
      expect(c.countFor('Nope'), isNull);
    });

    test('old servers: names only, no counts', () {
      final c = Categories.fromJson({'categories': ['B', 'A'], 'hasUncategorized': false});
      expect(c.ordered, ['B', 'A']);
      expect(c.countFor('A'), isNull);
      expect(c.countFor(null), isNull);
    });
  });

  test('ActorPage splits movies and series and reads TMDB details', () {
    final p = ActorPage.fromJson({
      'actor': {
        '_id': 'a1', 'displayName': 'Tom Hanks', 'profilePath': '/h.jpg', 'biography': 'Bio',
        'birthday': '1956-07-09', 'placeOfBirth': 'Concord', 'knownForDepartment': 'Acting',
      },
      'movies': [{'_id': 'm1', 'name': 'Big'}],
      'series': [{'_id': 's1', 'name': 'Band of Brothers'}, {'_id': 's2', 'name': 'From the Earth'}],
    });
    expect(p.actor.profileUrl, 'https://image.tmdb.org/t/p/w185/h.jpg');
    expect(p.actor.birthday!.year, 1956);
    expect(p.actor.age, greaterThan(60));
    expect(p.movies.single.kind, MediaKind.movie);
    expect(p.series.map((s) => s.kind).toSet(), {MediaKind.series});
    expect(p.total, 3);
  });

  test('Actor list rows carry credit counts', () {
    final a = Actor.fromJson({'_id': 'a', 'name': 'Judi Dench', 'movieCount': 2, 'seriesCount': 1});
    expect(a.titleCount, 3);
    expect(a.creditsLabel, '2 movies · 1 series');
    expect(a.hasPhoto, isFalse);
  });

  test('Featured slides keep TMDB art and the playable catalogue row', () {
    final f = Featured.fromJson({
      'source': 'tmdb',
      'matched': 1,
      'items': [
        {
          'kind': 'movie', 'source': 'tmdb', 'tmdbId': 1, 'title': 'Dune: Part Two', 'overview': 'Paul.',
          'year': 2024, 'rating': 8.3, 'voteCount': 5000,
          'posterUrl': 'https://image.tmdb.org/t/p/w500/p.jpg', 'backdropUrl': 'https://image.tmdb.org/t/p/w1280/b.jpg',
          'content': {'_id': 'm1', 'name': 'EN - Dune Part Two (2024)', 'logo': 'http://prov/p.jpg', 'url': 'http://stream'},
        },
        {'kind': 'series', 'source': 'catalog', 'title': 'X', 'content': null},
      ],
    });
    expect(f.items, hasLength(1)); // rows without content are dropped
    final s = f.items.single;
    expect(s.isTrending, isTrue);
    expect(s.backdrop, 'https://image.tmdb.org/t/p/w1280/b.jpg');
    expect(s.poster, 'https://image.tmdb.org/t/p/w500/p.jpg');
    expect(s.item.name, 'EN - Dune Part Two (2024)');
    expect(s.item.url, 'http://stream');
    final fallback = FeaturedItem.fromMedia(s.item);
    expect(fallback.isTrending, isFalse);
    expect(fallback.poster, 'http://prov/p.jpg');
  });

  test('Suggestions parses every section and the basis label', () {
    final s = Suggestions.fromJson({
      'profile': {'basis': 'history', 'seedCount': 3, 'genres': [{'name': 'Drama', 'weight': 1}, {'name': 'Sci-Fi', 'weight': 0.5}]},
      'suggested': [
        {'type': 'movie', 'score': 0.7, 'reasons': [{'kind': 'similar', 'label': 'Because you watched Dune', 'seedId': 'd'}],
         'content': {'_id': 'm1', 'name': 'Arrival'}},
      ],
      'newArrivals': [
        {'type': 'series', 'score': 0.9, 'reasons': [{'kind': 'new', 'label': 'Added today'}], 'content': {'_id': 's1', 'name': 'Foundation'}},
      ],
      'mostWatched': [
        {'type': 'series', 'watchedSecs': 18400, 'playCount': 9, 'episodesWatched': 8, 'lastWatchedAt': '2026-09-27T10:00:00Z',
         'completed': false, 'content': {'_id': 's2', 'name': 'Severance'}},
        {'type': 'movie', 'watchedSecs': 7200, 'playCount': 3, 'content': {'_id': 'm2', 'name': 'Heat'}},
      ],
      'becauseYouWatched': [
        {'seed': {'id': 'd', 'type': 'movie', 'name': 'Dune', 'signal': 'watched'}, 'title': 'Because you watched Dune',
         'items': [{'type': 'movie', 'content': {'_id': 'm3', 'name': 'Blade Runner'}}]},
        {'seed': {'id': 'e', 'type': 'movie', 'name': 'Empty'}, 'title': 'Because you watched Empty', 'items': []},
      ],
    });
    expect(s.isPersonalised, isTrue);
    expect(s.basisLabel, 'Because you watch Drama and Sci-Fi');
    expect(s.suggested.single.reason, 'Because you watched Dune');
    expect(s.newArrivals.single.item.kind, MediaKind.series);
    expect(s.mostWatched.first.label, '8 episodes · 5h 07m');
    expect(s.mostWatched.last.label, 'Watched 3× · 2h 00m');
    expect(s.becauseYouWatched, hasLength(1)); // empty rows dropped
    expect(Suggestions().basisLabel, 'Top picks from your library');
  });
}
