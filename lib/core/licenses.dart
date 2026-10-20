import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Registers the Geist / Geist Mono SIL OFL 1.1 text with [LicenseRegistry]
/// so it is listed on the in-app licenses page. Safe to call more than once.
void registerFontLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const <String>[
      'Geist',
      'Geist Mono',
    ], text);
  });
}
