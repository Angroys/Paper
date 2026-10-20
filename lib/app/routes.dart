/// Route paths. Use these instead of string literals.
abstract final class AppRoutes {
  static const String signIn = '/sign-in';
  static const String library = '/library';
  static const String settings = '/settings';
  static const String readerPattern = '/reader/:paperId';

  static String reader(String paperId) =>
      '/reader/${Uri.encodeComponent(paperId)}';
}
