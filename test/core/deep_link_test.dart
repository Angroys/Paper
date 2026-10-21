import 'package:flutter_test/flutter_test.dart';
import 'package:paper/app/deep_link_listener.dart';
import 'package:paper/core/app_links_deep_link_service.dart';
import 'package:paper/core/env.dart';
import 'package:paper/domain/domain.dart';

void main() {
  group('DeepLinkTarget.parse', () {
    test('auth callback keeps the full uri', () {
      final uri = Uri.parse('paper://auth-callback?code=abc');
      final target = DeepLinkTarget.parse(uri);
      expect(target, isA<AuthCallbackLink>());
      expect((target! as AuthCallbackLink).uri, uri);
    });

    test('open paper', () {
      final target = DeepLinkTarget.parse(Uri.parse('paper://paper/p-1'));
      expect((target! as OpenPaperLink).paperId, 'p-1');
    });

    test('rejects other schemes and hosts', () {
      expect(DeepLinkTarget.parse(Uri.parse('https://paper.college')), isNull);
      expect(DeepLinkTarget.parse(Uri.parse('paper://other')), isNull);
      expect(DeepLinkTarget.parse(Uri.parse('paper://paper/')), isNull);
    });
  });

  test('Windows cold start: link is read from argv', () async {
    final service = AppLinksDeepLinkService(
      launchArgs: <String>['--flag', 'paper://auth-callback?code=xyz'],
    );
    expect(
      await service.initialLink(),
      Uri.parse('paper://auth-callback?code=xyz'),
    );
    expect(AppLinksDeepLinkService.linkFromArgs(<String>['foo']), isNull);
  });

  test('OAuth redirectTo is exactly paper://auth-callback', () {
    expect(Env.authCallbackUrl, 'paper://auth-callback');
    final uri = Uri.parse(Env.authCallbackUrl);
    expect(uri.scheme, 'paper');
    expect(uri.host, 'auth-callback');
    expect(
      DeepLinkTarget.parse(Uri.parse('${Env.authCallbackUrl}?code=c')),
      isA<AuthCallbackLink>(),
    );
  });

  group('DeepLinkDeduper', () {
    test('an OAuth code is handled once (initial link + stream + argv)', () {
      final d = DeepLinkDeduper();
      final uri = Uri.parse('paper://auth-callback?code=abc');
      expect(d.accept(uri), isTrue);
      expect(d.accept(uri), isFalse);
      expect(d.accept(Uri.parse('paper://auth-callback?code=abc')), isFalse);
      expect(d.accept(Uri.parse('paper://auth-callback?code=other')), isTrue);
    });

    test('other links repeat only after the window', () {
      var now = DateTime(2026);
      final d = DeepLinkDeduper(clock: () => now);
      final uri = Uri.parse('paper://paper/p-1');
      expect(d.accept(uri), isTrue);
      expect(d.accept(uri), isFalse);
      now = now.add(const Duration(seconds: 6));
      expect(d.accept(uri), isTrue);
      // An error return (no code) is not single-use either.
      final err = Uri.parse('paper://auth-callback?error=access_denied');
      expect(d.accept(err), isTrue);
      expect(d.accept(err), isFalse);
    });
  });
}
