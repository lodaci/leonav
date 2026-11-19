import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelli.dart';

/// Tutte le letture e scritture verso Supabase passano da qui.
class Archivio {
  Archivio(this.db);

  final SupabaseClient db;

  String get _uid => db.auth.currentUser!.id;

  // --- Account -------------------------------------------------------------

  Future<void> accedi(String email, String password) =>
      db.auth.signInWithPassword(email: email.trim(), password: password);

  Future<void> registrati(String nome, String email, String password) =>
      db.auth.signUp(email: email.trim(), password: password, data: {'nome': nome.trim()});

  Future<void> recuperaPassword(String email) => db.auth.resetPasswordForEmail(email.trim());

  Future<void> esci() => db.auth.signOut();

  Future<Profilo> mioProfilo() async => Profilo.daJson(await db.from('profili').select().eq('id', _uid).single());

  Future<void> aggiornaProfilo({required String nome, int? linea, int? fermataAndata, int? fermataRitorno}) => db
      .from('profili')
      .update({
        'nome': nome,
        'linea_abituale': linea,
        'fermata_andata': fermataAndata,
        'fermata_ritorno': fermataRitorno,
      })
      .eq('id', _uid);

  // --- Configurazione ------------------------------------------------------

  Future<Impostazioni> impostazioni() async =>
      Impostazioni.daJson(await db.from('impostazioni').select().eq('id', 1).single());

  Future<Set<DateTime>> festivi() async {
    final righe = await db.from('festivi').select('data');
    return righe.map((r) => daDataDb(r['data'] as String)).toSet();
  }

  Future<List<Linea>> linee() async {
    final righe = await db.from('linee').select().eq('attiva', true).order('id', ascending: true);
    return righe.map(Linea.daJson).toList();
  }

  Future<List<Fermata>> fermate() async {
    final righe = await db
        .from('fermate')
        .select()
        .order('linea_id', ascending: true)
        .order('tratta', ascending: true)
        .order('ordine', ascending: true);
    return righe.map(Fermata.daJson).toList();
  }

  Future<List<List<double>>?> ultimoPercorso(int lineaId, Tratta tratta) async {
    final r = await db
        .from('percorsi')
        .select('punti')
        .eq('linea_id', lineaId)
        .eq('tratta', tratta.name)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (r == null) return null;
    return (r['punti'] as List).map((p) => (p as List).map((v) => (v as num).toDouble()).toList()).toList();
  }

  // --- Prenotazioni --------------------------------------------------------

  Future<List<Prenotazione>> miePrenotazioni(DateTime daGiorno) async {
    final righe = await db
        .from('prenotazioni')
        .select()
        .eq('utente_id', _uid)
        .eq('stato', 'attiva')
        .gte('data', dataDb(daGiorno))
        .order('data', ascending: true);
    return righe.map(Prenotazione.daJson).toList();
  }

  Future<void> prenota(DateTime giorno, int fermataId) =>
      db.rpc('prenota', params: {'p_data': dataDb(giorno), 'p_fermata_id': fermataId});

  Future<void> annulla(int prenotazioneId) => db.rpc('annulla_prenotazione', params: {'p_id': prenotazioneId});

  // --- Corse ---------------------------------------------------------------

  Future<Corsa?> corsa(int id) async {
    final r = await db.from('corse').select().eq('id', id).maybeSingle();
    return r == null ? null : Corsa.daJson(r);
  }

  Future<List<Corsa>> corseDelGiorno(DateTime giorno) async {
    final righe = await db.from('corse').select().eq('data', dataDb(giorno));
    return righe.map(Corsa.daJson).toList();
  }

  Future<List<RigaLista>> listaCorsa(int corsaId) async {
    final righe = await db.rpc('lista_corsa', params: {'p_corsa_id': corsaId}) as List;
    return righe.cast<Map<String, dynamic>>().map(RigaLista.daJson).toList();
  }

  /// Quanti hanno prenotato per ogni corsa del giorno (solo autisti e admin vedono tutte le righe).
  Future<Map<int, int>> prenotatiPerCorsa(DateTime giorno) async {
    final righe = await db.from('prenotazioni').select('corsa_id').eq('data', dataDb(giorno)).eq('stato', 'attiva');
    final conteggi = <int, int>{};
    for (final r in righe) {
      final id = r['corsa_id'] as int;
      conteggi[id] = (conteggi[id] ?? 0) + 1;
    }
    return conteggi;
  }

  Future<Corsa> avviaCorsa(int lineaId, DateTime giorno, Tratta tratta, int posti) async => Corsa.daJson(
    await db.rpc(
      'avvia_corsa',
      params: {'p_linea': lineaId, 'p_data': dataDb(giorno), 'p_tratta': tratta.name, 'p_posti': posti},
    ) as Map<String, dynamic>,
  );

  Future<void> aggiornaPosti(int corsaId, int posti) =>
      db.rpc('aggiorna_posti', params: {'p_corsa_id': corsaId, 'p_posti': posti});

  Future<void> segnaPresenza(int prenotazioneId, Presenza p) =>
      db.rpc('segna_presenza', params: {'p_prenotazione_id': prenotazioneId, 'p_presenza': p.db});

  Future<void> concludiCorsa(int corsaId) => db.rpc('concludi_corsa', params: {'p_corsa_id': corsaId});

  // --- Posizione -----------------------------------------------------------

  Future<void> inviaPosizione(int corsaId, Position p) => db.from('posizioni').insert({
    'corsa_id': corsaId,
    'lat': p.latitude,
    'lng': p.longitude,
    'velocita': p.speed,
    'direzione': p.heading,
  });

  Future<PosizioneNavetta?> ultimaPosizione(int corsaId) async {
    final r = await db
        .from('posizioni')
        .select()
        .eq('corsa_id', corsaId)
        .order('registrata_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return r == null ? null : PosizioneNavetta.daJson(r);
  }

  /// Avvisa quando cambia qualcosa di una corsa: posizione, posti, stato o prenotazioni.
  RealtimeChannel ascoltaCorsa(
    int corsaId, {
    void Function(PosizioneNavetta)? posizione,
    void Function()? cambiamento,
  }) {
    final ch = db.channel('corsa-$corsaId-${DateTime.now().microsecondsSinceEpoch}');
    if (posizione != null) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'posizioni',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'corsa_id', value: corsaId),
        callback: (p) => posizione(PosizioneNavetta.daJson(p.newRecord)),
      );
    }
    if (cambiamento != null) {
      ch
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'corse',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: corsaId),
          callback: (_) => cambiamento(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'prenotazioni',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'corsa_id', value: corsaId),
          callback: (_) => cambiamento(),
        );
    }
    return ch..subscribe();
  }

  Future<void> smettiDiAscoltare(RealtimeChannel ch) => db.removeChannel(ch);

  // --- Rilevatore ----------------------------------------------------------

  Future<void> salvaPosizioneFermata(int fermataId, double lat, double lng) =>
      db.rpc('salva_posizione_fermata', params: {'p_fermata_id': fermataId, 'p_lat': lat, 'p_lng': lng});

  Future<void> salvaPercorso(int lineaId, Tratta tratta, List<List<double>> punti) =>
      db.from('percorsi').insert({'linea_id': lineaId, 'tratta': tratta.name, 'punti': punti, 'registrato_da': _uid});
}

/// Messaggio leggibile da un errore di Supabase.
String messaggioErrore(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Email o password non corretti';
    if (m.contains('already registered')) return 'Email già registrata';
    if (m.contains('email not confirmed')) return 'Conferma prima l\'email con il link che ti abbiamo inviato';
    return e.message;
  }
  return 'Qualcosa è andato storto. Riprova.';
}
