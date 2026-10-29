import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/app/deep_link_listener.dart';
import 'package:paper/auth/auth_providers.dart';
import 'package:paper/core/core_providers.dart';
import 'package:paper/domain/domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../features/feature_fakes.dart';

/// app_links reports the launch link via `getInitialLink()` and again on
/// `uriLinkStream`.
class _Links implements DeepLinkService {
  _Links(this.initial);

  final Uri? initial;
  final controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initialLink() async => initial;

  @override
  Stream<Uri> get links => controller.stream;
}

void main() {
  final code = Uri.parse('paper://auth-callback?code=abc');

  Future<(FakeAuthRepository, _Links, Completer<SupabaseClient?>)> pump(
    WidgetTester tester,
  ) async {
    final auth = FakeAuthRepository();
    final links = _Links(code);
    final ready = Completer<SupabaseClient?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          deepLinkServiceProvider.overrideWithValue(links),
          supabaseReadyProvider.overrideWith((ref) => ready.future),
        ],
        child: const DeepLinkListener(child: SizedBox()),
      ),
    );
    return (auth, links, ready);
  }

  testWidgets('cold start: the code is exchanged once Supabase is ready, '
      'and only once', (tester) async {
    final (auth, links, ready) = await pump(tester);
    links.controller.add(code); // the same launch link on the stream
    await tester.pump();
    expect(auth.callbacks, isEmpty); // still initialising

    ready.complete(null);
    await tester.pump();
    await tester.pump();
    expect(auth.callbacks, <Uri>[code]);
    await links.controller.close();
  });

  testWidgets('warm start: a new link on the stream is exchanged', (
    tester,
  ) async {
    final (auth, links, ready) = await pump(tester);
    ready.complete(null);
    await tester.pump();
    final warm = Uri.parse('paper://auth-callback?code=second');
    links.controller.add(warm);
    await tester.pump();
    await tester.pump();
    expect(auth.callbacks, <Uri>[code, warm]);
    await links.controller.close();
  });
}
