import 'dart:io';

import 'package:flutter/foundation.dart';

/// Runs a process; injectable for tests.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Registers the `paper://` URL scheme for the current Windows user so the
/// OAuth / magic-link redirect (`paper://auth-callback?...`) opens Paper.
///
/// MSIX installs declare the protocol in the manifest; this covers the
/// portable zip / `flutter run` builds. It writes, under
/// `HKCU\Software\Classes\paper` (no admin rights needed):
///
/// ```
/// (Default)            = "URL:Paper"
/// URL Protocol         = ""
/// shell\open\command   = "<Paper.exe>" "%1"
/// ```
///
/// The OS then launches `Paper.exe "paper://..."`; windows/runner/main.cpp
/// forwards it to a running instance, or the cold-start argv is read by
/// `AppLinksDeepLinkService`. Re-registering on every launch is cheap and
/// keeps the command pointing at the current exe if the folder moved.
/// No-op on other platforms; never throws.
Future<bool> registerWindowsProtocolHandler({
  String scheme = 'paper',
  String? executablePath,
  ProcessRunner? run,
  bool? isWindows,
}) async {
  if (!(isWindows ?? Platform.isWindows)) return false;
  final exe = executablePath ?? Platform.resolvedExecutable;
  final runner = run ?? Process.run;
  final key = r'HKCU\Software\Classes\' + scheme;
  final commands = <List<String>>[
    ['add', key, '/ve', '/d', 'URL:Paper', '/f'],
    ['add', key, '/v', 'URL Protocol', '/d', '', '/f'],
    ['add', '$key\\shell\\open\\command', '/ve', '/d', '"$exe" "%1"', '/f'],
  ];
  try {
    for (final args in commands) {
      final result = await runner('reg', args);
      if (result.exitCode != 0) {
        debugPrint('paper:// registration failed: ${result.stderr}');
        return false;
      }
    }
    return true;
  } on Object catch (e) {
    debugPrint('paper:// registration failed: $e');
    return false;
  }
}
