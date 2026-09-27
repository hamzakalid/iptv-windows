import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';
import '../data/repository.dart';
import '../models/account.dart';

class Session {
  Session({required this.serverUrl, required this.token, this.user});
  final String serverUrl;
  final String token;
  final User? user;
}

const _kServer = 'server_url';
const _kToken = 'auth_token';
const _kEmail = 'auth_email';
const _kActivePlaylist = 'active_playlist';
const _kLastSeen = 'last_seen_at';

const _secure = FlutterSecureStorage();

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('overridden in main'));

/// Last server address typed on the login screen.
String savedServerUrl(SharedPreferences prefs) => prefs.getString(_kServer) ?? 'http://localhost:4000';

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final prefs = ref.read(prefsProvider);
    final token = await _secure.read(key: _kToken);
    final server = prefs.getString(_kServer);
    if (token == null || server == null) return null;
    final email = prefs.getString(_kEmail);
    final cached = Session(
      serverUrl: server,
      token: token,
      user: email == null ? null : User(id: '', email: email),
    );
    try {
      final user = await _repoFor(server, token).me();
      return Session(serverUrl: server, token: token, user: user);
    } on ApiException catch (e) {
      // Expired token → back to login. Offline → keep the cached session.
      if (e.status == 401) {
        await _secure.delete(key: _kToken);
        return null;
      }
      return cached;
    }
  }

  IptvRepository _repoFor(String server, String? token) =>
      IptvRepository(ApiClient(baseUrl: server, token: () => token, onUnauthorized: () {}));

  Future<void> signIn({
    required String serverUrl,
    required String email,
    required String password,
    required bool signup,
  }) async {
    final server = ApiClient.normalizeBaseUrl(serverUrl);
    final (token, user) = await _repoFor(server, null).login(email, password, signup: signup);
    final prefs = ref.read(prefsProvider);
    await prefs.setString(_kServer, server);
    await prefs.setString(_kEmail, user.email);
    await _secure.write(key: _kToken, value: token);
    state = AsyncData(Session(serverUrl: server, token: token, user: user));
  }

  Future<void> signOut() async {
    await _secure.delete(key: _kToken);
    await ref.read(prefsProvider).remove(_kActivePlaylist);
    state = const AsyncData(null);
  }
}

final repositoryProvider = Provider<IptvRepository>((ref) {
  final session = ref.watch(sessionProvider).value;
  return IptvRepository(ApiClient(
    baseUrl: session?.serverUrl ?? '',
    token: () => session?.token,
    onUnauthorized: () {
      if (ref.mounted) ref.read(sessionProvider.notifier).signOut();
    },
  ));
});

/// When the user last opened the app; anything added after this is "new".
final lastSeenProvider = NotifierProvider<LastSeen, DateTime?>(LastSeen.new);

class LastSeen extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final prefs = ref.read(prefsProvider);
    final stored = prefs.getString(_kLastSeen);
    if (stored == null) {
      // First launch: nothing counts as new yet.
      prefs.setString(_kLastSeen, DateTime.now().toIso8601String());
      return null;
    }
    return DateTime.tryParse(stored);
  }

  void markSeen() {
    final now = DateTime.now();
    ref.read(prefsProvider).setString(_kLastSeen, now.toIso8601String());
    state = now;
  }
}

/// The playlist the catalogue is scoped to. `null` lets the backend pick
/// the most recently synced one.
final activePlaylistProvider = NotifierProvider<ActivePlaylist, String?>(ActivePlaylist.new);

class ActivePlaylist extends Notifier<String?> {
  @override
  String? build() => ref.read(prefsProvider).getString(_kActivePlaylist);

  void select(String? id) {
    final prefs = ref.read(prefsProvider);
    id == null ? prefs.remove(_kActivePlaylist) : prefs.setString(_kActivePlaylist, id);
    state = id;
  }
}
