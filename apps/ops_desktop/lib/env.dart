/// Backend configuration, supplied at build time.
///
/// Defaults point at the local `supabase start` stack, so a fresh clone runs
/// with no arguments. The local publishable key is the fixed development key
/// the Supabase CLI issues to every project — it is not a secret and grants
/// nothing beyond what RLS allows.
///
/// For the hosted projects, pass real values:
///
///   flutter run -d windows \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  /// The `sb_publishable_...` key. This replaced the older JWT `anon` key;
  /// `Supabase.initialize(anonKey:)` is deprecated and goes away in the next
  /// major version.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  );

  static bool get isLocal => supabaseUrl.contains('127.0.0.1');
}
