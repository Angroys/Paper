import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../domain/services/deep_link_service.dart';

/// [DeepLinkService] backed by app_links.
///
/// Cold start: Android/macOS deliver the launch link through app_links.
/// On Windows the URL arrives as a command-line argument
/// (`Paper.exe "paper://auth-callback?code=..."`); [launchArgs] is checked
/// first so this works even without app_links' Windows handling. A second
/// launch while Paper runs is forwarded to the running instance by
/// `SendAppLinkToInstance()` in windows/runner/main.cpp and arrives on
/// [links].
class AppLinksDeepLinkService implements DeepLinkService {
  AppLinksDeepLinkService({this.launchArgs = const <String>[]});

  /// The process arguments `main()` received.
  final List<String> launchArgs;
  AppLinks? _appLinks;

  AppLinks get _links => _appLinks ??= AppLinks();

  /// First `paper://` URI in [args], or null.
  static Uri? linkFromArgs(List<String> args) {
    for (final arg in args) {
      final trimmed = arg.trim();
      if (!trimmed.toLowerCase().startsWith('paper://')) continue;
      final uri = Uri.tryParse(trimmed);
      if (uri != null) return uri;
    }
    return null;
  }

  @override
  Future<Uri?> initialLink() async {
    final fromArgs = linkFromArgs(launchArgs);
    if (fromArgs != null) return fromArgs;
    try {
      return await _links.getInitialLink();
    } on Object catch (e) {
      // Plugin missing (tests, unsupported platform): no initial link.
      debugPrint('deep links: initial link unavailable ($e)');
      return null;
    }
  }

  @override
  Stream<Uri> get links {
    try {
      return _links.uriLinkStream;
    } on Object catch (e) {
      debugPrint('deep links: stream unavailable ($e)');
      return const Stream<Uri>.empty();
    }
  }
}
