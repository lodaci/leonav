import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'servizi/archivio.dart';
import 'servizi/sessione.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it');
  if (!Config.configurato) {
    runApp(const ConfigurazioneMancante());
    return;
  }
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseKey);
  final sessione = Sessione(Archivio(Supabase.instance.client));
  runApp(LeoNavApp(sessione: sessione));
}
