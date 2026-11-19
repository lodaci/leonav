import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../calendario.dart';
import '../../modelli.dart';
import '../../servizi/sessione.dart';
import '../widgets/comuni.dart';
import '../widgets/mappa_linea.dart';

/// La navetta di oggi in tempo reale, per la tratta del momento.
class NavettaLivePage extends StatefulWidget {
  const NavettaLivePage({super.key});

  @override
  State<NavettaLivePage> createState() => _NavettaLivePageState();
}

class _NavettaLivePageState extends State<NavettaLivePage> {
  bool _caricamento = true;
  Prenotazione? _prenotazione;
  Corsa? _corsa;
  RigaLista? _mia;
  PosizioneNavetta? _posizione;
  List<LatLng>? _percorso;
  RealtimeChannel? _canale;
  Timer? _orologio;
  late Tratta _tratta;

  @override
  void initState() {
    super.initState();
    _tratta = trattaDelMomento(DateTime.now());
    // Aggiorna "ultimo aggiornamento N minuti fa".
    _orologio = Timer.periodic(const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_caricamento && _canale == null && _prenotazione == null) _carica();
  }

  Future<void> _carica() async {
    final sessione = SessioneScope.of(context);
    final archivio = sessione.archivio;
    setState(() => _caricamento = true);
    try {
      final oggi = soloData(DateTime.now());
      final mie = await archivio.miePrenotazioni(oggi);
      _prenotazione = null;
      for (final p in mie) {
        if (p.data == oggi && p.tratta == _tratta) _prenotazione = p;
      }
      if (_canale != null) await archivio.smettiDiAscoltare(_canale!);
      _canale = null;
      if (_prenotazione != null) {
        final id = _prenotazione!.corsaId;
        final f = sessione.fermata(_prenotazione!.fermataId)!;
        final r = await Future.wait([
          archivio.corsa(id),
          archivio.listaCorsa(id),
          archivio.ultimaPosizione(id),
          archivio.ultimoPercorso(f.lineaId, f.tratta),
        ]);
        _corsa = r[0] as Corsa?;
        final lista = r[1] as List<RigaLista>;
        _mia = lista.isEmpty ? null : lista.first;
        _posizione = r[2] as PosizioneNavetta?;
        _percorso = (r[3] as List<List<double>>?)?.map((p) => LatLng(p[0], p[1])).toList();
        _canale = archivio.ascoltaCorsa(
          id,
          posizione: (p) => mounted ? setState(() => _posizione = p) : null,
          cambiamento: _aggiornaStato,
        );
      }
    } catch (e) {
      if (mounted) mostraMessaggio(context, 'Impossibile caricare la navetta');
    }
    if (mounted) setState(() => _caricamento = false);
  }

  Future<void> _aggiornaStato() async {
    if (_prenotazione == null) return;
    final archivio = SessioneScope.of(context).archivio;
    final id = _prenotazione!.corsaId;
    final r = await Future.wait([archivio.corsa(id), archivio.listaCorsa(id)]);
    if (!mounted) return;
    setState(() {
      _corsa = r[0] as Corsa?;
      final lista = r[1] as List<RigaLista>;
      _mia = lista.isEmpty ? null : lista.first;
    });
  }

  @override
  void dispose() {
    _orologio?.cancel();
    if (_canale != null) SessioneScope.of(context).archivio.smettiDiAscoltare(_canale!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navetta'),
        actions: [
          SegmentedButton<Tratta>(
            segments: const [
              ButtonSegment(value: Tratta.andata, label: Text('Andata')),
              ButtonSegment(value: Tratta.ritorno, label: Text('Ritorno')),
            ],
            selected: {_tratta},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              setState(() => _tratta = s.first);
              _carica();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _caricamento
          ? const Center(child: CircularProgressIndicator())
          : _prenotazione == null
          ? Vuoto(
              icona: Icons.event_busy,
              testo: 'Oggi non hai prenotato ${_tratta == Tratta.andata ? 'l\'andata' : 'il ritorno'}.',
              azione: OutlinedButton(onPressed: _carica, child: const Text('Aggiorna')),
            )
          : _contenuto(context),
    );
  }

  Widget _contenuto(BuildContext context) {
    final sessione = SessioneScope.of(context);
    final f = sessione.fermata(_prenotazione!.fermataId)!;
    final linea = sessione.linea(f.lineaId);
    final fermate = sessione.fermateDi(f.lineaId, f.tratta);
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: MappaLinea(
            key: ValueKey('${f.lineaId}-${f.tratta}-${_percorso?.length}'),
            fermate: fermate,
            colore: linea.coloreArgb,
            percorso: _percorso,
            navetta: _posizione?.punto,
            evidenziata: f.id,
          ),
        ),
        Material(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    PallinoLinea(numero: linea.id, colore: linea.coloreArgb),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_statoCorsa(), style: tema.textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${f.tratta == Tratta.andata ? 'Sali a' : 'Scendi a'}: ${f.nomeBreve}'
                  '${f.orario != null ? ' · previsto ${f.orario}' : ''}',
                ),
                if (_posizione != null)
                  Text('Posizione aggiornata ${_tempoFa(_posizione!.registrataAt)}', style: tema.textTheme.bodySmall),
                if (_mia != null && !_mia!.haPosto) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tema.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Posti esauriti: oggi il veicolo ha ${posti(_corsa?.posti)} e sei ${_mia!.posizioneInLista}° in lista. '
                      'Organizzati con un mezzo alternativo.',
                      style: TextStyle(color: tema.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _statoCorsa() {
    final c = _corsa;
    if (c == null || c.stato == StatoCorsa.programmata) return 'La corsa non è ancora partita';
    if (c.stato == StatoCorsa.conclusa) return 'Corsa conclusa';
    return 'Navetta in viaggio';
  }

  String _tempoFa(DateTime t) {
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return 'adesso';
    if (m == 1) return '1 minuto fa';
    return '$m minuti fa';
  }
}
