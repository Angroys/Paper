/// Compile-time configuration, passed with `--dart-define` or
/// `--dart-define-from-file=env/<name>.json` (see `env/example.json`).
///
/// Real values never live in the repo: `env/*.json` is gitignored except the
/// example. When [isConfigured] is false the app runs in "not configured"
/// mode: no Supabase client is created, auth is always signed out and all
/// network features report themselves unavailable. Tests run in this mode.
class Env {
  const Env({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.paperApiBaseUrl,
  });

  /// Values baked in at compile time.
  factory Env.fromEnvironment() => const Env(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    paperApiBaseUrl: String.fromEnvironment(
      'PAPER_API_BASE_URL',
      defaultValue: defaultPaperApiBaseUrl,
    ),
  );

  /// Not configured: what tests and bare `flutter run` get.
  static const Env unconfigured = Env(
    supabaseUrl: '',
    supabaseAnonKey: '',
    paperApiBaseUrl: defaultPaperApiBaseUrl,
  );

  static const String defaultPaperApiBaseUrl = 'https://paper.college';

  /// OAuth redirect registered for the native app (Android intent-filter,
  /// macOS CFBundleURLTypes, Windows protocol handler).
  static const String authCallbackUrl = 'paper://auth-callback';

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Base URL of the paper.college Next.js API (AI routes etc.).
  final String paperApiBaseUrl;

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  Uri get paperApiBaseUri => Uri.parse(paperApiBaseUrl);
}
