/// Configurazione passata in fase di build:
///
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_KEY=sb_publishable_...
///
/// La chiave "publishable" e' pubblica per natura: i dati sono protetti dalle regole
/// di accesso (RLS) definite in supabase/migrations.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get configurato => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Ogni quanti secondi l'autista invia la posizione durante la corsa.
  static const secondiInvioPosizione = 8;

  /// Centro mappa quando le fermate non hanno ancora coordinate (Venegono Superiore).
  static const latDefault = 45.757;
  static const lngDefault = 8.899;
}
