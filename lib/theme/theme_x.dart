import 'package:flutter/material.dart';

import 'paper_tokens.dart';

/// Short accessors for the Paper theme extensions.
extension PaperThemeX on BuildContext {
  PaperColors get paper => Theme.of(this).extension<PaperColors>()!;
  PaperHighlightColors get paperHighlights =>
      Theme.of(this).extension<PaperHighlightColors>()!;
}
