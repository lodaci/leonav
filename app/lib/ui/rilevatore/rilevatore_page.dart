import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../modelli.dart';
import '../../servizi/gps.dart';
import '../../servizi/sessione.dart';
import '../widgets/comuni.dart';
import '../widgets/mappa_linea.dart';

/// Modalita' rilevatore (account sviluppatore): a bordo della navetta si registrano
/// la posizione reale di ogni fermata e il percorso effettivo.
class RilevatorePage extends StatefulWidget {
  const RilevatorePage({super.key});

  @override
  State<RilevatorePage> createState() => _RilevatorePageState();
}

class _RilevatorePageState extends State<RilevatorePage> {
  int? _linea;
  Tratta _tratta = Tratta.andata;
  Tracciamento? _gps;
  Position? _io;
  final List<List<double>> _traccia = [];
  final _mappa = MapController();
  bool _registra = false;
  String? _problema;

  @override
  void dispose() {
    _gps?.ferma();
    super.dispose();
  }

  Future<void> _avviaGps() async {
    if (_gps != null) return;
    final problema = await verificaPermessiPosizione();
    if (!mounted) return;
    if (problema != null) {
      setState(() => _problema = problema);
      return;
    }
    _gps = Tracciamento(
      intervallo: const Duration(seconds: 2),
      suPosizione: (p) async {
        if (!mounted) return;
        setState(() {
          _io = p;
          _problema = null;
          if (_registra) _traccia.add([_arrotonda(p.latitude), _arrotonda(p.longitude)]);
        });
      },
      suErrore: (e) => mounted ? setState(() => _problema = 'GPS non disponibile') : null,
    )..avvia(impostazioniTracciamento(titoloNotifica: 'Rilevatore LeoNav', distanzaMinima: 5));
  }

  double _arrotonda(double v) => (v * 1e6).roundToDouble() / 1e6;

  Future<void> _salvaFermata(Fermata f) async {
    final p = _io;
    if (p == null) {
      mostraMessaggio(context, 'Aspetta che il GPS trovi la posizione');
      return;
    }
    if (p.accuracy > 30) {
      final procedi = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Posizione poco precisa'),
          content: Text('Il GPS ha una precisione di circa ${p.accuracy.round()} m. Salvare comunque?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Aspetto')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salva')),
          ],
        ),
      );
      if (procedi != true || !mounted) return;
    }
    final sessione = SessioneScope.of(context);
    final ok = await esegui(
      context,
      () => sessione.archivio.salvaPosizioneFermata(f.id, p.latitude, p.longitude),
      ok: 'Salvata: ${f.nomeBreve}',
    );
    if (ok) sessione.aggiornaFermata(f.conPosizione(p.latitude, p.longitude));
  }

  Future<void> _salvaPercorso() async {
    if (_traccia.length < 2) {
      mostraMessaggio(context, 'Percorso troppo corto');
      return;
    }
    final ok = await esegui(
      context,
      () => SessioneScope.of(context).archivio.salvaPercorso(_linea!, _tratta, List.of(_traccia)),
      ok: 'Percorso salvato (${_traccia.length} punti)',
    );
    if (ok && mounted) {
      setState(() {
        _registra = false;
        _traccia.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessione = SessioneScope.of(context);
    final fermate = _linea == null ? <Fermata>[] : sessione.fermateDi(_linea!, _tratta);
    final linea = _linea == null ? null : sessione.linea(_linea!);
    Fermata? prossima;
    for (final f in fermate) {
      if (!f.rilevata) {
        prossima = f;
        break;
      }
    }
    final rilevate = fermate.where((f) => f.rilevata).length;
    final io = _io == null ? null : LatLng(_io!.latitude, _io!.longitude);

    return Scaffold(
      appBar: AppBar(title: const Text('Rilevatore')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _linea,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Linea', border: OutlineInputBorder(), isDense: true),
                    items: [for (final l in sessione.linee) DropdownMenuItem(value: l.id, child: Text(l.titolo))],
                    onChanged: _registra
                        ? null
                        : (v) {
                            setState(() => _linea = v);
                            _avviaGps();
                          },
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<Tratta>(
                  segments: const [
                    ButtonSegment(value: Tratta.andata, label: Text('A')),
                    ButtonSegment(value: Tratta.ritorno, label: Text('R')),
                  ],
                  selected: {_tratta},
                  showSelectedIcon: false,
                  onSelectionChanged: _registra ? null : (s) => setState(() => _tratta = s.first),
                ),
              ],
            ),
          ),
          if (_linea == null)
            const Expanded(
              child: Vuoto(
                icona: Icons.add_location_alt,
                testo:
                    'Scegli linea e tratta. A bordo della navetta, a ogni fermata premi "Sono qui" '
                    'per salvarne la posizione reale. Puoi anche registrare il percorso effettivo.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '$rilevate di ${fermate.length} fermate rilevate'
                '${_io != null ? ' · precisione GPS ${_io!.accuracy.round()} m' : ''}'
                '${_problema != null ? ' · $_problema' : ''}',
              ),
            ),
            SizedBox(
              height: 220,
              child: MappaLinea(
                key: ValueKey('$_linea-$_tratta'),
                controller: _mappa,
                fermate: fermate,
                colore: linea!.coloreArgb,
                percorso: _traccia.map((p) => LatLng(p[0], p[1])).toList(),
                io: io,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: prossima == null ? null : () => _salvaFermata(prossima!),
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        prossima == null ? 'Tutte rilevate' : 'Sono qui: ${prossima.nomeBreve}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _registra
                  ? Row(
                      children: [
                        Expanded(child: Text('Registrazione percorso: ${_traccia.length} punti')),
                        TextButton(
                          onPressed: () => setState(() {
                            _registra = false;
                            _traccia.clear();
                          }),
                          child: const Text('Scarta'),
                        ),
                        FilledButton.tonal(onPressed: _salvaPercorso, child: const Text('Salva percorso')),
                      ],
                    )
                  : OutlinedButton.icon(
                      onPressed: () {
                        _avviaGps();
                        setState(() => _registra = true);
                      },
                      icon: const Icon(Icons.fiber_manual_record, color: Colors.red),
                      label: const Text('Registra il percorso'),
                    ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  for (final f in fermate)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        f.rilevata ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: f.rilevata ? Colors.green : null,
                      ),
                      title: Text('${f.ordine}. ${f.nomeBreve}'),
                      subtitle: f.orario != null ? Text(f.orario!) : null,
                      trailing: IconButton(
                        tooltip: 'Salva qui la posizione',
                        icon: const Icon(Icons.pin_drop_outlined),
                        onPressed: () => _salvaFermata(f),
                      ),
                      onTap: f.posizione == null ? null : () => _mappa.move(f.posizione!, 16),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
