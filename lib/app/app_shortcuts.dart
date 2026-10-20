import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/build_flags.dart';
import '../sync/sync_providers.dart';
import 'app_commands.dart';
import 'router.dart';
import 'routes.dart';

// App-level (scope G / L) keyboard shortcuts from layout-system.md §9.
//
// They sit above the Navigator, so route-level shortcut tables (the
// reader's `ReaderShortcuts`) see a key first and win any overlap: Mod+F is
// "find in paper" inside the reader and "search library" in the Library.
// Every shortcut here is a Mod chord, which the spec allows while a text
// field has focus; single-key shortcuts live in the reader only.

/// Mod+F (Library only) / Mod+K (anywhere): focus the library search.
class FocusLibrarySearchIntent extends Intent {
  const FocusLibrarySearchIntent({required this.anywhere});

  /// Mod+K works from any screen; Mod+F only in the Library.
  final bool anywhere;
}

/// Mod+O: import a PDF file. Mod+Shift+O: import from a link.
class ImportPaperIntent extends Intent {
  const ImportPaperIntent({required this.fromUrl});
  final bool fromUrl;
}

/// Mod+, : open Settings.
class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

/// Mod+Shift+S: sync now.
class SyncNowIntent extends Intent {
  const SyncNowIntent();
}

/// The app-level shortcut table for [platform] (Cmd on Apple, else Ctrl).
/// [offlineOnly] drops import-by-link and sync-now.
Map<ShortcutActivator, Intent> appShortcuts(
  TargetPlatform platform, {
  bool offlineOnly = false,
}) {
  final mac =
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
  SingleActivator mod(LogicalKeyboardKey key, {bool shift = false}) =>
      SingleActivator(key, meta: mac, control: !mac, shift: shift);
  return <ShortcutActivator, Intent>{
    mod(LogicalKeyboardKey.keyF): const FocusLibrarySearchIntent(
      anywhere: false,
    ),
    mod(LogicalKeyboardKey.keyK): const FocusLibrarySearchIntent(
      anywhere: true,
    ),
    mod(LogicalKeyboardKey.keyO): const ImportPaperIntent(fromUrl: false),
    if (!offlineOnly)
      mod(LogicalKeyboardKey.keyO, shift: true): const ImportPaperIntent(
        fromUrl: true,
      ),
    mod(LogicalKeyboardKey.comma): const OpenSettingsIntent(),
    if (!offlineOnly)
      mod(LogicalKeyboardKey.keyS, shift: true): const SyncNowIntent(),
  };
}

class _CallbackAction<T extends Intent> extends Action<T> {
  _CallbackAction(this._invoke, {this._enabled});

  final void Function(T intent) _invoke;
  final bool Function(T intent)? _enabled;

  @override
  bool isEnabled(T intent) => _enabled?.call(intent) ?? true;

  @override
  bool consumesKey(T intent) => isEnabled(intent);

  @override
  Object? invoke(T intent) {
    _invoke(intent);
    return null;
  }
}

/// Installs [appShortcuts] above the router's Navigator.
class AppShortcuts extends ConsumerWidget {
  const AppShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String location() {
      final router = ref.read(routerProvider);
      return router.routerDelegate.currentConfiguration.uri.path;
    }

    bool inLibrary() => location().startsWith(AppRoutes.library);
    bool signedInArea() => location() != AppRoutes.signIn;

    void toLibrary(LibraryCommandKind kind) {
      if (!inLibrary()) ref.read(routerProvider).go(AppRoutes.library);
      ref.read(libraryCommandProvider.notifier).send(kind);
    }

    return Shortcuts(
      shortcuts: appShortcuts(
        Theme.of(context).platform,
        offlineOnly: ref.watch(offlineOnlyProvider),
      ),
      child: Actions(
        actions: <Type, Action<Intent>>{
          FocusLibrarySearchIntent: _CallbackAction<FocusLibrarySearchIntent>(
            (_) => toLibrary(LibraryCommandKind.focusSearch),
            enabled: (i) => i.anywhere ? signedInArea() : inLibrary(),
          ),
          ImportPaperIntent: _CallbackAction<ImportPaperIntent>(
            (i) => toLibrary(
              i.fromUrl
                  ? LibraryCommandKind.importUrl
                  : LibraryCommandKind.importFile,
            ),
            enabled: (_) => signedInArea(),
          ),
          OpenSettingsIntent: _CallbackAction<OpenSettingsIntent>(
            (_) => ref.read(routerProvider).go(AppRoutes.settings),
            enabled: (_) => signedInArea(),
          ),
          SyncNowIntent: _CallbackAction<SyncNowIntent>(
            (_) => unawaited(ref.read(syncServiceProvider).syncNow()),
          ),
        },
        child: child,
      ),
    );
  }
}
