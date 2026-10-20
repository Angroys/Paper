import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/domain.dart';

// Repository wiring. Placeholders: the data-layer agent replaces each body
// with the drift (SQLite) + Supabase implementation. Feature code depends
// only on these providers and the interfaces in lib/domain/.
//
// Tests override them:
//   ProviderScope(overrides: [
//     paperRepositoryProvider.overrideWithValue(FakePaperRepository()),
//   ], child: ...)

final paperRepositoryProvider = Provider<PaperRepository>(
  (ref) => throw UnimplementedError('paperRepositoryProvider: data layer'),
);

final highlightRepositoryProvider = Provider<HighlightRepository>(
  (ref) => throw UnimplementedError('highlightRepositoryProvider: data layer'),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => throw UnimplementedError('noteRepositoryProvider: data layer'),
);
