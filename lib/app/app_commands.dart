import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Commands the app-level shortcuts (layout-system.md §9) send to the
/// Library screen, which may not be on screen when the key is pressed.
enum LibraryCommandKind { focusSearch, importFile, importUrl }

@immutable
class LibraryCommand {
  const LibraryCommand(this.kind, this.serial);
  final LibraryCommandKind kind;

  /// Distinguishes two presses of the same shortcut.
  final int serial;
}

/// The latest unconsumed library command (null once handled). The Library
/// screen listens to it and also consumes a pending one when it mounts.
class LibraryCommandController extends Notifier<LibraryCommand?> {
  int _serial = 0;

  @override
  LibraryCommand? build() => null;

  void send(LibraryCommandKind kind) => state = LibraryCommand(kind, ++_serial);

  /// Returns the pending command and clears it.
  LibraryCommand? take() {
    final c = state;
    if (c != null) state = null;
    return c;
  }
}

final libraryCommandProvider =
    NotifierProvider<LibraryCommandController, LibraryCommand?>(
      LibraryCommandController.new,
    );
