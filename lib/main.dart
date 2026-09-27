import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'router.dart';
import 'widgets/mini_player.dart';
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const IptvApp(),
  ));
}

class IptvApp extends ConsumerWidget {
  const IptvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
      // Picture-in-picture floats over every route (tabs, details, settings).
      builder: (context, child) => Stack(children: [
        ?child,
        Positioned.fill(
          child: Overlay(initialEntries: [
            OverlayEntry(
              builder: (context) => Stack(children: [
                Positioned(
                  right: 20,
                  bottom: context.isWide ? 20 : 84,
                  child: MiniPlayer(onExpand: (args) => router.push('/player', extra: args)),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
