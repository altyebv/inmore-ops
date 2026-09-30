/// Backend configuration, supplied at build time.
///
/// Defaults point at the local `supabase start` stack, so a fresh clone runs
/// with no arguments. The local anon key is the fixed development key that the
/// Supabase CLI issues to every project — it is not a secret and grants nothing
/// beyond what RLS allows.
///
/// For the hosted projects, pass real values:
///
///   flutter run -d windows \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwic'
        'm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNR'
        'eilDMblYTn_I0',
  );

  static bool get isLocal => supabaseUrl.contains('127.0.0.1');
}
