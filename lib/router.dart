import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/actor/actor_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/browse/browse_screen.dart';
import 'features/details/movie_details_screen.dart';
import 'features/details/series_details_screen.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/live/live_screen.dart';
import 'features/player/player_screen.dart';
import 'features/search/search_screen.dart';
import 'features/settings/add_playlist_screen.dart';
import 'features/settings/settings_screen.dart';
import 'models/media.dart';
import 'state/providers.dart';
import 'widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge auth state into go_router so redirects re-run on login/logout.
  final authChanges = ValueNotifier<AsyncValue<Session?>>(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, next) => authChanges.value = next);
  ref.onDispose(authChanges.dispose);

  StatefulShellBranch branch(String path, Widget child) =>
      StatefulShellBranch(routes: [GoRoute(path: path, builder: (_, _) => child)]);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = authChanges.value;
      if (auth.isLoading && !auth.hasValue) return '/splash';
      final loggedIn = auth.value != null;
      final atAuth = state.matchedLocation == '/login' || state.matchedLocation == '/splash';
      if (!loggedIn) return state.matchedLocation == '/login' ? null : '/login';
      if (atAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          branch('/home', const HomeScreen()),
          branch('/movies', const BrowseScreen(kind: MediaKind.movie)),
          branch('/series', const BrowseScreen(kind: MediaKind.series)),
          branch('/live', const LiveScreen()),
          branch('/library', const LibraryScreen()),
        ],
      ),
      GoRoute(
        path: '/search',
        builder: (_, s) => SearchScreen(
          initialQuery: s.uri.queryParameters['q'],
          initialScope: int.tryParse(s.uri.queryParameters['scope'] ?? '') ?? 0,
        ),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/settings/add-playlist', builder: (_, _) => const AddPlaylistScreen()),
      GoRoute(
        path: '/movie/:id',
        builder: (_, s) => MovieDetailsScreen(id: s.pathParameters['id']!, preview: s.extra as MediaItem?),
      ),
      GoRoute(
        path: '/series/:id',
        builder: (_, s) => SeriesDetailsScreen(id: s.pathParameters['id']!, preview: s.extra as MediaItem?),
      ),
      GoRoute(path: '/actor/:id', builder: (_, s) => ActorScreen(id: s.pathParameters['id']!)),
      GoRoute(
        path: '/player',
        pageBuilder: (_, s) => NoTransitionPage(child: PlayerScreen(args: s.extra! as PlayerArgs)),
      ),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
