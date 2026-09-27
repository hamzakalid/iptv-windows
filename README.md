# Nova TV — Flutter client for the IPTV backend

One Flutter codebase for **Android, iOS and Windows** that talks to
[`app-iptv-backend`](https://github.com/hamzakalid/app-iptv-backend).

- **Home**: a hero slider of titles **trending on the internet right now** (TMDB) that are also in your IPTV catalogue, with TMDB posters and backdrops served by the backend; a category strip built from the **IPTV account's own categories** (provider order, item counts) that drives the row beneath it; and user-level rows that don't depend on which playlist is active — *Suggested for you*, *New for you*, *Your most watched* and *Because you watched …* — plus Live now, Top rated, New series and *Actors in your library*
- **Actors**: a searchable, sortable grid of every actor credited in your movies and series (rail destination on desktop, "See all" from Home on phones); the actor page shows the TMDB biography and dates and lists their **Movies** and **Series** as two sections
- **Design**: the Nocturne design system — blue-grey ground, Inter, one blurple accent used as outlines and glows, Phosphor icons
- **Desktop shell**: a slim icon rail (Home, Movies, Series, Live TV, Library, Search, Settings, profile/playlist switcher); press `/` anywhere to search
- **Movies / Series / Live TV**: infinite-scroll grids with the provider's category filters (with per-category counts), **sort** (recently added, top rated, release year, A–Z), **minimum rating** pills, and a **Surprise me** shuffle that picks a random title matching the current filters
- **Details**: cinematic header, resume/restart, My List, trailer, cast (tap through to the actor's page), "More like this", season and episode picker
- **Library**: My List (favourites) and **History** with progress, "watched" ticks and one-tap resume; finished movies get a ✓ badge on every poster
- **Live TV**: category list, recently watched channels, All / Favourites, sort, and channel cards with what's on now, progress and what's next
- **Player**: [`media_kit`](https://pub.dev/packages/media_kit) (libmpv) with custom controls. Live: ↑/↓ channel zapping with an on-screen banner, channel list (`C`), mini guide (`G`). Series: episode drawer (`E`), **Up next** countdown. Audio, subtitles and speed (`S`), **picture-in-picture** (`P`) that keeps playing while you browse, and a shortcut sheet (`?`). Resumes from your last position and reports progress every 15 s
- **Playlists**: add Xtream Codes or M3U with **Test connection**, see live sync status, re-sync, switch or delete
- **Adaptive layout**: bottom navigation on phones; the icon rail on tablets and Windows, with hover rings on cards and paging arrows on rows

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
  features/              auth, home, browse, live, details, player, search, favorites, settings, actor, actors
test/models_test.dart    parsing tests against real backend payload shapes
```

## Notes

- **Cleartext HTTP is enabled** on Android (`usesCleartextTraffic`) and iOS (ATS `NSAllowsArbitraryLoads`), because most IPTV providers and LAN backends use plain `http://`.
- The JWT is kept in the OS secure store (`flutter_secure_storage`); the server URL and the chosen playlist are kept in `shared_preferences`.
- Sorting, rating/year filters and hydrated history need the backend from the same branch (`sort`, `minRating`, `yearFrom`/`yearTo` on list endpoints; `GET /watch-events?hydrate=1`). Older servers ignore the params, so lists stay unsorted and the History tab is empty.
- The trending hero (`GET /home/featured`), the user-level rows (`GET /suggestions`), category counts (`items` on `/categories`) and the Actors page (`GET /actors` with counts, `/actors/:id` with separate movies/series) also come from that backend. Suggestions are built from your watch history across **all** your playlists, so they don't change when you switch the active playlist. The hero needs `TMDB_API_READ_TOKEN` on the server; without it (or before the first sync) it falls back to the best-rated and newest titles in the library.
- Category pills and asides use the provider's order; alphabetical order is used only on older servers that don't send `items`.
- The models accept both the shapes in `docs/API.md` and what the server sends today (for example, a flat series `episodes` array rather than a season-keyed map).
- Branding lives in `lib/core/theme.dart` (`appName` and `AppColors`).
