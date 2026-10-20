import 'package:flutter_test/flutter_test.dart';
import 'package:paper/app/router.dart';
import 'package:paper/core/app_links_deep_link_service.dart';
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

  group('authRedirect', () {
    const user = AppUser(id: 'u1');
    test('not configured allows everything', () {
      expect(authRedirect(const AuthState.notConfigured(), '/library'), isNull);
    });
    test('signed out goes to sign-in', () {
      expect(authRedirect(const AuthState.signedOut(), '/library'), '/sign-in');
      expect(authRedirect(const AuthState.signedOut(), '/sign-in'), isNull);
    });
    test('signed in leaves sign-in', () {
      expect(
        authRedirect(const AuthState.signedIn(user), '/sign-in'),
        '/library',
      );
      expect(authRedirect(const AuthState.signedIn(user), '/reader/x'), isNull);
    });
    test('unknown stays put', () {
      expect(authRedirect(const AuthState.unknown(), '/library'), isNull);
    });
  });
}
