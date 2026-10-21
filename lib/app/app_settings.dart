import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences (settings.md: every setting is device-local in
/// v1). `main()` overrides this with the loaded [SharedPreferences]; when it
/// is null (widget tests that don't care) settings live in memory only.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Preference keys. Never rename: they are persisted.
abstract final class PrefKeys {
  /// Legacy: the theme toggle was removed (web parity is dark-only). The
  /// key may still hold "system"/"light"/"dark" on upgraded installs; it is
  /// never read or written any more, so old values are harmless.
  static const String themeMode = 'settings.themeMode';
  static const String reduceMotion = 'settings.reduceMotion';
  static const String singleKeyShortcuts = 'settings.reader.singleKeyShortcuts';
  static const String panelStyle = 'settings.reader.panelStyle';
  static const String autoSwitchToPen = 'settings.reader.autoSwitchToPen';
}

/// Settings › Appearance › Reduce motion: System (false) / On (true).
/// Applied once at the root as `MediaQuery.disableAnimations` (motion.md
/// §3.1), so `PaperMotion.of` / `fade` pick it up everywhere.
class ReduceMotionController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider)?.getBool(PrefKeys.reduceMotion) ??
      false;

  void set(bool on) {
    state = on;
    ref.read(sharedPreferencesProvider)?.setBool(PrefKeys.reduceMotion, on);
  }
}

final reduceMotionProvider = NotifierProvider<ReduceMotionController, bool>(
  ReduceMotionController.new,
);

/// Settings › Reader › "Side panel style" (tablets in landscape).
enum PanelStyle { split, overlay }

/// Settings › Reader preferences the reader consumes.
@immutable
class ReaderPrefs {
  const ReaderPrefs({
    this.singleKeyShortcuts = true,
    this.panelStyle = PanelStyle.split,
    this.autoSwitchToPen = true,
  });

  /// WCAG 2.1.4: single-letter shortcuts can be turned off.
  final bool singleKeyShortcuts;
  final PanelStyle panelStyle;

  /// Switch to the Pen tool when a stylus first touches the page.
  final bool autoSwitchToPen;

  ReaderPrefs copyWith({
    bool? singleKeyShortcuts,
    PanelStyle? panelStyle,
    bool? autoSwitchToPen,
  }) => ReaderPrefs(
    singleKeyShortcuts: singleKeyShortcuts ?? this.singleKeyShortcuts,
    panelStyle: panelStyle ?? this.panelStyle,
    autoSwitchToPen: autoSwitchToPen ?? this.autoSwitchToPen,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderPrefs &&
      other.singleKeyShortcuts == singleKeyShortcuts &&
      other.panelStyle == panelStyle &&
      other.autoSwitchToPen == autoSwitchToPen;

  @override
  int get hashCode =>
      Object.hash(singleKeyShortcuts, panelStyle, autoSwitchToPen);
}

class ReaderPrefsController extends Notifier<ReaderPrefs> {
  @override
  ReaderPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs == null) return const ReaderPrefs();
    final style = prefs.getString(PrefKeys.panelStyle);
    return ReaderPrefs(
      singleKeyShortcuts: prefs.getBool(PrefKeys.singleKeyShortcuts) ?? true,
      panelStyle: PanelStyle.values.firstWhere(
        (s) => s.name == style,
        orElse: () => PanelStyle.split,
      ),
      autoSwitchToPen: prefs.getBool(PrefKeys.autoSwitchToPen) ?? true,
    );
  }

  SharedPreferences? get _prefs => ref.read(sharedPreferencesProvider);

  void setSingleKeyShortcuts(bool on) {
    state = state.copyWith(singleKeyShortcuts: on);
    _prefs?.setBool(PrefKeys.singleKeyShortcuts, on);
  }

  void setPanelStyle(PanelStyle style) {
    state = state.copyWith(panelStyle: style);
    _prefs?.setString(PrefKeys.panelStyle, style.name);
  }

  void setAutoSwitchToPen(bool on) {
    state = state.copyWith(autoSwitchToPen: on);
    _prefs?.setBool(PrefKeys.autoSwitchToPen, on);
  }
}

final readerPrefsProvider =
    NotifierProvider<ReaderPrefsController, ReaderPrefs>(
      ReaderPrefsController.new,
    );
