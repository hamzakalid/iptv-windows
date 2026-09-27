import 'package:flutter/material.dart';

import '../../models/media.dart';
import '../browse/browse_screen.dart';

/// Live TV uses the shared browser; tapping a channel starts playback and
/// the player shows the current programme from the EPG.
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) => const BrowseScreen(kind: MediaKind.channel);
}
