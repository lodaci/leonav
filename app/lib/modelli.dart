import 'package:latlong2/latlong.dart';

enum Tratta {
  andata,
  ritorno;

  String get etichetta => this == andata ? 'Andata' : 'Ritorno';
  static Tratta da(String s) => Tratta.values.byName(s);
}

enum Ruolo {
  passeggero,
  autista,
  admin;

  static Ruolo da(String s) => Ruolo.values.byName(s);
}

enum StatoCorsa {
  programmata,
  inCorso,
  conclusa;

  static StatoCorsa da(String s) => switch (s) {
    'in_corso' => inCorso,
    'conclusa' => conclusa,
    _ => programmata,
  };
}

enum Presenza {
  daSegnare('da_segnare'),
  salito('salito'),
  assente('assente');

  const Presenza(this.db);
  final String db;
  static Presenza da(String s) => Presenza.values.firstWhere((p) => p.db == s);
}

/// Data senza orario, come 'YYYY-MM-DD' nel database.
String dataDb(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime daDataDb(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

class Profilo {
  Profilo({
    required this.id,
    required this.nome,
    required this.email,
    required this.ruolo,
    required this.sviluppatore,
    required this.approvato,
    this.lineaAbituale,
    this.fermataAndata,
    this.fermataRitorno,
  });

  factory Profilo.daJson(Map<String, dynamic> j) => Profilo(
    id: j['id'] as String,
    nome: (j['nome'] as String?) ?? '',
    email: j['email'] as String,
    ruolo: Ruolo.da(j['ruolo'] as String),
    sviluppatore: j['sviluppatore'] as bool? ?? false,
    approvato: j['approvato'] as bool? ?? false,
    lineaAbituale: j['linea_abituale'] as int?,
    fermataAndata: j['fermata_andata'] as int?,
    fermataRitorno: j['fermata_ritorno'] as int?,
  );

  final String id;
  final String nome;
  final String email;
  final Ruolo ruolo;
  final bool sviluppatore;
  final bool approvato;
  final int? lineaAbituale;
  final int? fermataAndata;
  final int? fermataRitorno;

  bool get guida => ruolo == Ruolo.autista || ruolo == Ruolo.admin;
  bool get viaggia => ruolo == Ruolo.passeggero || ruolo == Ruolo.admin;
  bool get rilevatore => sviluppatore || ruolo == Ruolo.admin;
}

class Impostazioni {
  Impostazioni({required this.minutiAnticipo, required this.giorniServizio, required this.giorniPrenotabili});

  factory Impostazioni.daJson(Map<String, dynamic> j) => Impostazioni(
    minutiAnticipo: j['minuti_anticipo'] as int,
    giorniServizio: (j['giorni_servizio'] as List).cast<int>().toSet(),
    giorniPrenotabili: j['giorni_prenotabili'] as int,
  );

  final int minutiAnticipo;

  /// 1 = lunedi' ... 7 = domenica.
  final Set<int> giorniServizio;
  final int giorniPrenotabili;
}

class Linea {
  Linea({required this.id, required this.nome, required this.colore, required this.orarioRitorno});

  factory Linea.daJson(Map<String, dynamic> j) => Linea(
    id: j['id'] as int,
    nome: j['nome'] as String,
    colore: j['colore'] as String,
    orarioRitorno: (j['orario_ritorno'] as String).substring(0, 5),
  );

  final int id;
  final String nome;

  /// Colore in formato '#RRGGBB'.
  final String colore;
  final String orarioRitorno;

  int get coloreArgb => 0xFF000000 | int.parse(colore.substring(1), radix: 16);
  String get titolo => 'Linea $id · $nome';
}

class Fermata {
  Fermata({
    required this.id,
    required this.lineaId,
    required this.tratta,
    required this.ordine,
    required this.nome,
    this.lat,
    this.lng,
    this.orario,
    required this.rilevata,
    required this.stabilimento,
  });

  factory Fermata.daJson(Map<String, dynamic> j) => Fermata(
    id: j['id'] as int,
    lineaId: j['linea_id'] as int,
    tratta: Tratta.da(j['tratta'] as String),
    ordine: j['ordine'] as int,
    nome: j['nome'] as String,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    orario: (j['orario'] as String?)?.substring(0, 5),
    rilevata: j['rilevata'] as bool? ?? false,
    stabilimento: j['stabilimento'] as bool? ?? false,
  );

  final int id;
  final int lineaId;
  final Tratta tratta;
  final int ordine;
  final String nome;
  final double? lat;
  final double? lng;

  /// 'HH:MM' oppure null se non noto.
  final String? orario;
  final bool rilevata;
  final bool stabilimento;

  LatLng? get posizione => lat != null && lng != null ? LatLng(lat!, lng!) : null;

  /// Nome leggibile: 'VARESE - VIA DEL PONTE' -> 'Varese - Via Del Ponte'.
  String get nomeBreve =>
      nome.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  Fermata conPosizione(double lat, double lng) => Fermata(
    id: id,
    lineaId: lineaId,
    tratta: tratta,
    ordine: ordine,
    nome: nome,
    lat: lat,
    lng: lng,
    orario: orario,
    rilevata: true,
    stabilimento: stabilimento,
  );
}

class Corsa {
  Corsa({
    required this.id,
    required this.lineaId,
    required this.data,
    required this.tratta,
    this.autistaId,
    this.posti,
    required this.stato,
  });

  factory Corsa.daJson(Map<String, dynamic> j) => Corsa(
    id: j['id'] as int,
    lineaId: j['linea_id'] as int,
    data: daDataDb(j['data'] as String),
    tratta: Tratta.da(j['tratta'] as String),
    autistaId: j['autista_id'] as String?,
    posti: j['posti'] as int?,
    stato: StatoCorsa.da(j['stato'] as String),
  );

  final int id;
  final int lineaId;
  final DateTime data;
  final Tratta tratta;
  final String? autistaId;
  final int? posti;
  final StatoCorsa stato;
}

class Prenotazione {
  Prenotazione({
    required this.id,
    required this.corsaId,
    required this.fermataId,
    required this.data,
    required this.tratta,
    required this.presenza,
  });

  factory Prenotazione.daJson(Map<String, dynamic> j) => Prenotazione(
    id: j['id'] as int,
    corsaId: j['corsa_id'] as int,
    fermataId: j['fermata_id'] as int,
    data: daDataDb(j['data'] as String),
    tratta: Tratta.da(j['tratta'] as String),
    presenza: Presenza.da(j['presenza'] as String),
  );

  final int id;
  final int corsaId;
  final int fermataId;
  final DateTime data;
  final Tratta tratta;
  final Presenza presenza;
}

/// Una riga della lista di una corsa (funzione lista_corsa).
class RigaLista {
  RigaLista({
    required this.prenotazioneId,
    required this.utenteId,
    required this.nome,
    required this.fermataId,
    required this.fermataOrdine,
    required this.presenza,
    required this.posizioneInLista,
    required this.haPosto,
  });

  factory RigaLista.daJson(Map<String, dynamic> j) => RigaLista(
    prenotazioneId: j['prenotazione_id'] as int,
    utenteId: j['utente_id'] as String,
    nome: (j['nome'] as String?) ?? '',
    fermataId: j['fermata_id'] as int,
    fermataOrdine: j['fermata_ordine'] as int,
    presenza: Presenza.da(j['presenza'] as String),
    posizioneInLista: j['posizione_in_lista'] as int,
    haPosto: j['ha_posto'] as bool,
  );

  final int prenotazioneId;
  final String utenteId;
  final String nome;
  final int fermataId;
  final int fermataOrdine;
  final Presenza presenza;
  final int posizioneInLista;
  final bool haPosto;
}

class PosizioneNavetta {
  PosizioneNavetta({required this.lat, required this.lng, required this.registrataAt});

  factory PosizioneNavetta.daJson(Map<String, dynamic> j) => PosizioneNavetta(
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    registrataAt: DateTime.parse(j['registrata_at'] as String).toLocal(),
  );

  final double lat;
  final double lng;
  final DateTime registrataAt;

  LatLng get punto => LatLng(lat, lng);
}
