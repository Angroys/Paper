/// Incoming `paper://` links (OAuth return, open paper), including the
/// link that cold-started the app.
abstract interface class DeepLinkService {
  /// The link the app was launched with (Android intent, macOS open-URL
  /// event, Windows argv), or null.
  Future<Uri?> initialLink();

  /// Links received while running.
  Stream<Uri> get links;
}

/// What a `paper://` link points to.
sealed class DeepLinkTarget {
  const DeepLinkTarget();

  /// Parses `paper://auth-callback?...` and `paper://paper/<id>`; returns
  /// null for anything else.
  static DeepLinkTarget? parse(Uri uri) {
    if (uri.scheme != 'paper') return null;
    switch (uri.host) {
      case 'auth-callback':
        return AuthCallbackLink(uri);
      case 'paper':
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.length != 1) return null;
        return OpenPaperLink(segments.single);
    }
    return null;
  }
}

final class AuthCallbackLink extends DeepLinkTarget {
  const AuthCallbackLink(this.uri);
  final Uri uri;
}

final class OpenPaperLink extends DeepLinkTarget {
  const OpenPaperLink(this.paperId);
  final String paperId;
}
