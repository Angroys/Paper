import 'explanation_tab.dart';
import 'glossary_tab.dart';
import 'notes_tab.dart';
import 'reader_side_panel.dart';

/// The app's side panel tab bodies. `main()` installs them by overriding
/// `readerPanelSlotsProvider`; tests do the same (or inject their own).
final ReaderPanelSlots appReaderPanelSlots = ReaderPanelSlots(
  notes: (context, panel) => NotesTab(panel: panel),
  glossary: (context, panel) => GlossaryTab(panel: panel),
  explanation: (context, panel) => ExplanationTab(panel: panel),
);
