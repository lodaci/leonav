import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:leonav/calendario.dart';
import 'package:leonav/modelli.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it'));

  final imp = Impostazioni(minutiAnticipo: 5, giorniServizio: {1, 2, 3, 4, 5}, giorniPrenotabili: 14);
  final linea = Linea(id: 1, nome: 'Comerio-Varese', colore: '#1565C0', orarioRitorno: '16:45');

  Fermata fermata({required Tratta tratta, String? orario}) => Fermata(
    id: 1,
    lineaId: 1,
    tratta: tratta,
    ordine: 2,
    nome: 'X',
    orario: orario,
    rilevata: false,
    stabilimento: false,
  );

  group('giorniPrenotabili', () {
    test('solo giorni feriali, festivi esclusi', () {
      // giovedi' 19 novembre 2026
      final giorni = giorniPrenotabili(DateTime(2026, 11, 19, 10), imp, {DateTime(2026, 11, 23)});
      expect(giorni.first, DateTime(2026, 11, 19));
      expect(giorni, isNot(contains(DateTime(2026, 11, 21)))); // sabato
      expect(giorni, isNot(contains(DateTime(2026, 11, 22)))); // domenica
      expect(giorni, isNot(contains(DateTime(2026, 11, 23)))); // festivo
      expect(giorni.last, DateTime(2026, 12, 3));
    });

    test('attraversa il cambio di ora legale senza saltare giorni', () {
      final giorni = giorniPrenotabili(DateTime(2027, 3, 26), imp, {});
      expect(giorni, contains(DateTime(2027, 3, 29)));
    });
  });

  group('limiteModifica', () {
    test('andata: 5 minuti prima del passaggio alla fermata', () {
      final l = limiteModifica(DateTime(2026, 11, 23), fermata(tratta: Tratta.andata, orario: '07:01'), linea, imp);
      expect(l, DateTime(2026, 11, 23, 6, 56));
    });

    test('ritorno senza orario: 5 minuti prima della partenza dallo stabilimento', () {
      final l = limiteModifica(DateTime(2026, 11, 23), fermata(tratta: Tratta.ritorno), linea, imp);
      expect(l, DateTime(2026, 11, 23, 16, 40));
    });

    test('andata senza orario: usa il primo orario della tratta', () {
      final l = limiteModifica(
        DateTime(2026, 11, 23),
        fermata(tratta: Tratta.andata),
        linea,
        imp,
        primoOrarioTratta: '07:00',
      );
      expect(l, DateTime(2026, 11, 23, 6, 55));
    });
  });

  test('trattaDelMomento', () {
    expect(trattaDelMomento(DateTime(2026, 11, 19, 7)), Tratta.andata);
    expect(trattaDelMomento(DateTime(2026, 11, 19, 16)), Tratta.ritorno);
  });

  test('giornoLungo in italiano', () {
    expect(giornoLungo(DateTime(2026, 11, 23)), 'Lunedì 23 novembre');
  });
}
