import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config.dart';
import '../../modelli.dart';
import '../../servizi/gps.dart';
import '../../servizi/sessione.dart';
import '../widgets/comuni.dart';
import 'corse_oggi_page.dart';

/// La corsa in corso: fermate in ordine, chi sale o scende, presenze, posizione condivisa.
class CorsaPage extends StatefulWidget {
  const CorsaPage({super.key, required this.corsa});

  final Corsa corsa;

  @override
  State<CorsaPage> createState() => _CorsaPageState();
}

class _CorsaPageState extends State<CorsaPage> {
  late Corsa _corsa = widget.corsa;
  List<RigaLista> _lista = [];
  Tracciamento? _gps;
  String? _statoGps;
  RealtimeChannel? _canale;
  bool _pronto = false;

  bool get _attiva => _corsa.stato == StatoCorsa.inCorso;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pronto) return;
    _pronto = true;
    final archivio = SessioneScope.of(context).archivio;
    _ricarica();
    _canale = archivio.ascoltaCorsa(_corsa.id, cambiamento: _ricarica);
    if (_attiva) _avviaGps();
  }

  Future<void> _ricarica() async {
    final archivio = SessioneScope.of(context).archivio;
    try {
      final r = await Future.wait([archivio.corsa(_corsa.id), archivio.listaCorsa(_corsa.id)]);
      if (!mounted) return;
      setState(() {
        _corsa = (r[0] as Corsa?) ?? _corsa;
        _lista = r[1] as List<RigaLista>;
      });
    } catch (_) {}
  }

  Future<void> _avviaGps() async {
    final problema = await verificaPermessiPosizione();
    if (!mounted) return;
    if (problema != null) {
      setState(() => _statoGps = problema);
      return;
    }
    final archivio = SessioneScope.of(context).archivio;
    final linea = SessioneScope.of(context).linea(_corsa.lineaId);
    _gps = Tracciamento(
      intervallo: const Duration(seconds: Config.secondiInvioPosizione),
      suPosizione: (p) async {
        await archivio.inviaPosizione(_corsa.id, p);
        if (mounted) setState(() => _statoGps = 'Posizione condivisa');
      },
      suErrore: (e) => mounted ? setState(() => _statoGps = 'Posizione non inviata, riprovo…') : null,
    )..avvia(impostazioniTracciamento(titoloNotifica: 'Linea ${linea.id} in corso'));
    setState(() => _statoGps = 'In attesa del GPS…');
  }

  @override
  void dispose() {
    _gps?.ferma();
    if (_canale != null) SessioneScope.of(context).archivio.smettiDiAscoltare(_canale!);
    super.dispose();
  }

  Future<void> _cambiaPosti() async {
    final n = await chiediPosti(context, iniziale: _corsa.posti);
    if (n == null || !mounted) return;
    await esegui(context, () => SessioneScope.of(context).archivio.aggiornaPosti(_corsa.id, n));
    _ricarica();
  }

  Future<void> _segna(RigaLista r, bool salito) async {
    await esegui(
      context,
      () =>
          SessioneScope.of(context).archivio
              .segnaPresenza(r.prenotazioneId, salito ? Presenza.salito : Presenza.daSegnare),
    );
    _ricarica();
  }

  Future<void> _concludi() async {
    final daSegnare = _lista.where((r) => r.haPosto && r.presenza == Presenza.daSegnare).length;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concludere la corsa?'),
        content: Text(
          'Smetterai di condividere la posizione.'
          '${daSegnare > 0 ? ' $daSegnare passeggeri non spuntati risulteranno assenti.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Concludi')),
        ],
      ),
    );
    if (conferma != true || !mounted) return;
    final ok = await esegui(
      context,
      () => SessioneScope.of(context).archivio.concludiCorsa(_corsa.id),
      ok: 'Corsa conclusa',
    );
    if (!ok || !mounted) return;
    await _gps?.ferma();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final sessione = SessioneScope.of(context);
    final linea = sessione.linea(_corsa.lineaId);
    final fermate = sessione.fermateDi(_corsa.lineaId, _corsa.tratta);
    final perFermata = <int, List<RigaLista>>{};
    for (final r in _lista) {
      perFermata.putIfAbsent(r.fermataId, () => []).add(r);
    }
    final senzaPosto = _lista.where((r) => !r.haPosto).length;
    final verbo = _corsa.tratta == Tratta.andata ? 'salgono' : 'scendono';
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Linea ${linea.id} · ${_corsa.tratta == Tratta.andata ? 'mattino' : 'ritorno'}'),
        actions: [
          if (_attiva)
            TextButton.icon(
              onPressed: _cambiaPosti,
              icon: const Icon(Icons.event_seat),
              label: Text(posti(_corsa.posti)),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_attiva)
            Container(
              width: double.infinity,
              color: tema.colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.gps_fixed, size: 18, color: tema.colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_statoGps ?? ''} · ${_lista.length} prenotati'
                      '${senzaPosto > 0 ? ', $senzaPosto senza posto' : ''}',
                      style: TextStyle(color: tema.colorScheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          if (_corsa.stato == StatoCorsa.conclusa)
            const Padding(padding: EdgeInsets.all(12), child: Text('Corsa conclusa: presenze salvate.')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [for (final f in fermate) _fermata(context, f, perFermata[f.id] ?? [], verbo)],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _attiva
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _concludi,
                  icon: const Icon(Icons.flag),
                  label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Fine corsa')),
                ),
              ),
            )
          : null,
    );
  }

  Widget _fermata(BuildContext context, Fermata f, List<RigaLista> righe, String verbo) {
    final tema = Theme.of(context);
    final vuota = righe.isEmpty && !f.stabilimento;
    final colore = vuota ? tema.colorScheme.outline : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: vuota ? tema.colorScheme.surfaceContainerHighest : tema.colorScheme.primary,
            child: Text(
              '${f.ordine}',
              style: TextStyle(fontSize: 12, color: vuota ? colore : tema.colorScheme.onPrimary),
            ),
          ),
          title: Text(
            f.nomeBreve,
            style: TextStyle(color: colore, fontWeight: vuota ? null : FontWeight.w600),
          ),
          subtitle: Text(
            [
              ?f.orario,
              if (f.stabilimento)
                'stabilimento'
              else if (vuota)
                'nessuno, si può saltare'
              else
                '${righe.length} $verbo',
            ].join(' · '),
            style: TextStyle(color: colore),
          ),
        ),
        for (final r in righe)
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: CheckboxListTile(
              dense: true,
              value: r.presenza == Presenza.salito,
              onChanged: _attiva && r.haPosto ? (v) => _segna(r, v ?? false) : null,
              title: Text(r.nome.isEmpty ? 'Passeggero' : r.nome),
              subtitle: r.haPosto
                  ? (r.presenza == Presenza.assente ? const Text('assente') : null)
                  : Text(
                      'senza posto (${r.posizioneInLista}° in lista)',
                      style: TextStyle(color: tema.colorScheme.error),
                    ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
