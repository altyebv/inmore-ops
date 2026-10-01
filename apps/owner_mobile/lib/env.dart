/// Backend configuration, supplied at build time.
///
/// Defaults point at the local `supabase start` stack. The local publishable
/// key is the fixed development key the Supabase CLI issues to every project —
/// it is not a secret and grants nothing beyond what RLS allows.
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
///
/// On a phone, `127.0.0.1` is the phone itself. For an Android emulator the
/// host machine is `10.0.2.2`; on a real handset use the machine's LAN address.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
  );
}
