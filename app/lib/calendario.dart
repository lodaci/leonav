import 'package:intl/intl.dart';

import 'modelli.dart';

final _giorno = DateFormat('EEE d MMM', 'it');
final _giornoLungo = DateFormat('EEEE d MMMM', 'it');

String giornoBreve(DateTime d) => _giorno.format(d);
String giornoLungo(DateTime d) {
  final s = _giornoLungo.format(d);
  return s[0].toUpperCase() + s.substring(1);
}

DateTime soloData(DateTime d) => DateTime(d.year, d.month, d.day);

/// Giorni in cui si puo' prenotare, a partire da oggi.
List<DateTime> giorniPrenotabili(DateTime adesso, Impostazioni imp, Set<DateTime> festivi) {
  final oggi = soloData(adesso);
  final giorni = <DateTime>[];
  for (var i = 0; i <= imp.giorniPrenotabili; i++) {
    final g = DateTime(oggi.year, oggi.month, oggi.day + i);
    if (imp.giorniServizio.contains(g.weekday) && !festivi.contains(g)) giorni.add(g);
  }
  return giorni;
}

/// Tratta da mostrare "adesso": l'andata fino alle 12, poi il ritorno.
Tratta trattaDelMomento(DateTime adesso) => adesso.hour < 12 ? Tratta.andata : Tratta.ritorno;

/// Momento oltre il quale una prenotazione non si puo' piu' cambiare (stessa regola del database).
/// L'orario e' quello di passaggio alla fermata, o la partenza del ritorno se non noto.
DateTime limiteModifica(DateTime giorno, Fermata f, Linea linea, Impostazioni imp, {String? primoOrarioTratta}) {
  final orario = f.orario ?? (f.tratta == Tratta.ritorno ? linea.orarioRitorno : primoOrarioTratta) ?? '00:00';
  final p = orario.split(':').map(int.parse).toList();
  return DateTime(giorno.year, giorno.month, giorno.day, p[0], p[1]).subtract(Duration(minutes: imp.minutiAnticipo));
}
