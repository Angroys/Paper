import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/paper_tokens.dart';

bool get isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// Desktop window defaults (layout-system.md §8): 1280×800 centred, minimum
/// 480×560, #0A0A0A background so there is no white flash.
Future<void> initDesktopWindow() async {
  if (!isDesktop) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: PaperChrome.windowDefault,
    minimumSize: PaperChrome.windowMin,
    center: true,
    backgroundColor: Color(0xFF0A0A0A),
    title: 'Paper',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
