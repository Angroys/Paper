import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/core/immersive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late double imeInset;

  int immersiveCalls() => calls
      .where(
        (c) =>
            c.method == 'SystemChrome.setEnabledSystemUIMode' &&
            c.arguments == 'SystemUiMode.immersiveSticky',
      )
      .length;

  setUp(() {
    calls = <MethodCall>[];
    imeInset = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  ImmersiveMode make({bool enabled = true}) =>
      ImmersiveMode(enabled: enabled, imeInset: () => imeInset);

  test('disabled: never touches SystemChrome', () async {
    final mode = make(enabled: false);
    await mode.install();
    await mode.apply();
    mode.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(calls, isEmpty);
  });

  test('default is off under flutter test', () {
    expect(ImmersiveMode().enabled, isFalse);
  });

  testWidgets('install applies immersiveSticky and registers callbacks', (
    tester,
  ) async {
    final mode = make();
    await mode.install();
    addTearDown(mode.uninstall);
    expect(immersiveCalls(), 1);
    expect(
      calls.map((c) => c.method),
      contains('SystemChrome.setSystemUIChangeListener'),
    );
    // Second install is a no-op.
    await mode.install();
    expect(immersiveCalls(), 1);
  });

  testWidgets('re-applies on resume', (tester) async {
    final mode = make();
    await mode.install();
    addTearDown(mode.uninstall);
    calls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(immersiveCalls(), 1);
  });

  testWidgets('re-applies 1 s after the system reports visible bars', (
    tester,
  ) async {
    final mode = make();
    await mode.install();
    addTearDown(mode.uninstall);
    calls.clear();

    await mode.onSystemUiChange(false);
    await tester.pump(const Duration(seconds: 2));
    expect(immersiveCalls(), 0);

    await mode.onSystemUiChange(true);
    await tester.pump(const Duration(milliseconds: 900));
    expect(immersiveCalls(), 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(immersiveCalls(), 1);
  });

  testWidgets('system UI change from the platform channel is handled', (
    tester,
  ) async {
    final mode = make();
    await mode.install();
    addTearDown(mode.uninstall);
    calls.clear();

    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.platform.name,
      SystemChannels.platform.codec.encodeMethodCall(
        const MethodCall('SystemChrome.systemUIChange', <Object>[true]),
      ),
      (_) {},
    );
    await tester.pump(const Duration(seconds: 1, milliseconds: 50));
    expect(immersiveCalls(), 1);
  });

  testWidgets('re-applies 300 ms after the IME closes', (tester) async {
    final mode = make();
    await mode.install();
    addTearDown(mode.uninstall);
    calls.clear();

    imeInset = 280;
    mode.didChangeMetrics(); // IME opened: nothing to do.
    await tester.pump(const Duration(seconds: 1));
    expect(immersiveCalls(), 0);

    imeInset = 0;
    mode.didChangeMetrics(); // IME closed.
    await tester.pump(const Duration(milliseconds: 250));
    expect(immersiveCalls(), 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(immersiveCalls(), 1);

    // Metrics changes without an IME (rotation) don't re-apply.
    mode.didChangeMetrics();
    await tester.pump(const Duration(seconds: 1));
    expect(immersiveCalls(), 1);
  });

  testWidgets('SafeViewPadding adds viewPadding on chosen sides', (
    tester,
  ) async {
    late EdgeInsets resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          viewPadding: EdgeInsets.fromLTRB(30, 40, 0, 10),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SafeViewPadding(
            base: const EdgeInsets.symmetric(horizontal: 24),
            bottom: false,
            child: Builder(
              builder: (context) {
                resolved = SafeViewPadding.resolve(
                  context,
                  base: const EdgeInsets.symmetric(horizontal: 24),
                  bottom: false,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(resolved, const EdgeInsets.fromLTRB(54, 40, 24, 0));
    final padding = tester.widget<Padding>(find.byType(Padding));
    expect(padding.padding, const EdgeInsets.fromLTRB(54, 40, 24, 0));
  });

  testWidgets('SafeViewPadding bottom collapses while the IME is open', (
    tester,
  ) async {
    // Engine metrics with a 48px nav bar: padding = viewPadding - viewInsets.
    Future<double> bottomFor(MediaQueryData data) async {
      late EdgeInsets resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: data,
          child: Builder(
            builder: (context) {
              resolved = SafeViewPadding.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return resolved.bottom;
    }

    expect(
      await bottomFor(
        const MediaQueryData(
          viewPadding: EdgeInsets.only(bottom: 48),
          padding: EdgeInsets.only(bottom: 48),
        ),
      ),
      48,
    );
    expect(
      await bottomFor(
        const MediaQueryData(
          viewPadding: EdgeInsets.only(bottom: 48),
          viewInsets: EdgeInsets.only(bottom: 300),
        ),
      ),
      0,
    );
  });
}
