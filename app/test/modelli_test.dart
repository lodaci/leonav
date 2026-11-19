import 'package:flutter_test/flutter_test.dart';
import 'package:leonav/modelli.dart';

void main() {
  test('Fermata dal database', () {
    final f = Fermata.daJson({
      'id': 7,
      'linea_id': 1,
      'tratta': 'andata',
      'ordine': 2,
      'nome': 'VARESE - VIA DEL PONTE (OSPEDALE)',
      'lat': null,
      'lng': null,
      'orario': '07:28:00',
      'rilevata': false,
      'stabilimento': false,
    });
    expect(f.orario, '07:28');
    expect(f.posizione, isNull);
    expect(f.nomeBreve, 'Varese - Via Del Ponte (ospedale)');
    expect(f.conPosizione(45.8, 8.8).posizione, isNotNull);
  });

  test('Corsa e stati', () {
    final c = Corsa.daJson({
      'id': 1,
      'linea_id': 3,
      'data': '2026-11-23',
      'tratta': 'ritorno',
      'autista_id': null,
      'posti': 18,
      'stato': 'in_corso',
    });
    expect(c.data, DateTime(2026, 11, 23));
    expect(c.stato, StatoCorsa.inCorso);
    expect(c.tratta, Tratta.ritorno);
  });

  test('RigaLista', () {
    final r = RigaLista.daJson({
      'prenotazione_id': 4,
      'utente_id': 'u',
      'nome': 'Mario',
      'fermata_id': 9,
      'fermata_nome': 'X',
      'fermata_ordine': 3,
      'presenza': 'da_segnare',
      'posizione_in_lista': 19,
      'ha_posto': false,
    });
    expect(r.presenza, Presenza.daSegnare);
    expect(r.haPosto, isFalse);
  });

  test('Linea colore', () {
    final l = Linea.daJson({'id': 2, 'nome': 'Porto Ceresio', 'colore': '#2E7D32', 'orario_ritorno': '16:45:00'});
    expect(l.coloreArgb, 0xFF2E7D32);
    expect(l.orarioRitorno, '16:45');
  });

  test('dataDb', () {
    expect(dataDb(DateTime(2026, 3, 5)), '2026-03-05');
    expect(daDataDb('2026-03-05'), DateTime(2026, 3, 5));
  });
}
