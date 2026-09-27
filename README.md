# Nova TV — Flutter client for the IPTV backend

One Flutter codebase for **Android, iOS and Windows** that talks to
[`app-iptv-backend`](https://github.com/hamzakalid/app-iptv-backend).

- **Home**: featured carousel of rounded cards (genre pills, rating, save-to-list), a category strip that drives the row beneath it ("For you", Action, Drama, …), *Because you watched …* rows, Live now, Top rated, New movies and New series
- **Desktop shell**: persistent top bar with scoped search (All / Movies / Series / Live TV), a *what's new* bell listing titles added since your last visit, a profile menu to switch playlists, and a sidebar with **Continue Watching** thumbnails
- **Movies / Series / Live TV**: infinite-scroll grids with category filters, **sort** (recently added, top rated, release year, A–Z), **minimum rating** pills, and a **Surprise me** shuffle that picks a random title matching the current filters
- **Details**: cinematic header, resume/restart, My List, trailer, cast (tap through to the actor's page), "More like this", season and episode picker
- **Library**: My List (favourites) and **History** with progress, "watched" ticks and one-tap resume; finished movies get a ✓ badge on every poster
- **Player**: [`media_kit`](https://pub.dev/packages/media_kit) (libmpv) plays HLS, MPEG-TS and MP4 on every platform. Resumes from your last position, reports progress every 15 s, shows the live EPG ("Now: …"), playback **speed**, **audio & subtitle** track selection, and an **Up next** countdown that auto-plays the following episode
- **Playlists**: add Xtream Codes or M3U with **Test connection**, see live sync status, re-sync, switch or delete
- **Adaptive layout**: bottom navigation on phones; sidebar + top bar on tablets and Windows, with hover previews on posters and paging arrows on rows

## Run it

Prerequisites: Flutter 3.47+ (stable; Dart 3.13), and a running backend (see its README).

```bash
flutter pub get
flutter run -d windows        # Windows desktop
flutter run -d <android-id>   # Android phone/emulator
flutter run -d <ios-id>       # iPhone/simulator (macOS only)
```

On the login screen, tap **Server** and enter your backend address. `http://` is added if you leave it off, and so is `/api`:

| Where the app runs | Server address |
|---|---|
| Windows, on the same PC as the backend | `http://localhost:4000` |
| Android emulator | `http://10.0.2.2:4000` |
| Real phone on your Wi-Fi | `http://<your-PC-LAN-IP>:4000` |

## Build releases

```bash
flutter build windows --release   # build/windows/x64/runner/Release/
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
flutter build ipa                 # needs Xcode + signing
```

## Project layout

```
lib/
  main.dart              app entry, media_kit init, ProviderScope
  router.dart            go_router: auth redirect, tab shell, detail/player routes
  core/                  theme (colours, fonts, breakpoints), JSON + format helpers
  models/                MediaItem / Episode / EPG / Playlist / Home … (lenient parsing)
  data/                  ApiClient (Dio + bearer token) and IptvRepository (all endpoints)
  state/                 Riverpod providers: session, active playlist, home, favourites …
  widgets/               shared UI: cards, rows, paged grid, adaptive shell
  features/              auth, home, browse, live, details, player, search, favorites, settings, actor
test/models_test.dart    parsing tests against real backend payload shapes
```

## Notes

- **Cleartext HTTP is enabled** on Android (`usesCleartextTraffic`) and iOS (ATS `NSAllowsArbitraryLoads`), because most IPTV providers and LAN backends use plain `http://`.
- The JWT is kept in the OS secure store (`flutter_secure_storage`); the server URL and the chosen playlist are kept in `shared_preferences`.
- Sorting, rating/year filters and hydrated history need the backend from the same branch (`sort`, `minRating`, `yearFrom`/`yearTo` on list endpoints; `GET /watch-events?hydrate=1`). Older servers ignore the params, so lists stay unsorted and the History tab is empty.
- The models accept both the shapes in `docs/API.md` and what the server sends today (for example, a flat series `episodes` array rather than a season-keyed map).
- Branding lives in `lib/core/theme.dart` (`appName` and `AppColors`).
