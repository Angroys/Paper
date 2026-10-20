/// Pure-Dart domain layer: models, errors and the interfaces the data,
/// auth, sync and AI layers implement. No Flutter imports here.
library;

export 'errors.dart';
export 'models/ai_result.dart';
export 'models/auth.dart';
export 'models/explanation.dart';
export 'models/figure_highlight.dart';
export 'models/glossary_term.dart';
export 'models/highlight.dart';
export 'models/note.dart';
export 'models/paper.dart';
export 'models/reading_position.dart';
export 'models/sync.dart';
export 'models/sync_state.dart';
export 'repositories/auth_repository.dart';
export 'repositories/highlight_repository.dart';
export 'repositories/note_repository.dart';
export 'repositories/paper_repository.dart';
export 'services/ai_service.dart';
export 'services/connectivity_service.dart';
export 'services/deep_link_service.dart';
export 'services/sync_service.dart';
