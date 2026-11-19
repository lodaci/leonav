import 'package:material_ui/material_ui.dart';

import '../../calendario.dart';
import '../../modelli.dart';
import '../../servizi/sessione.dart';
import '../widgets/comuni.dart';
import 'corsa_page.dart';

/// Le corse di oggi: l'autista sceglie la sua e la avvia indicando i posti.
class CorseOggiPage extends StatefulWidget {
  const CorseOggiPage({super.key});

  @override
  State<CorseOggiPage> createState() => _CorseOggiPageState();
}

class _CorseOggiPageState extends State<CorseOggiPage> {
  late Tratta _tratta = trattaDelMomento(DateTime.now());
  Map<int, Corsa> _corse = {};
  Map<int, int> _prenotati = {};
  bool _caricamento = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_caricamento && _corse.isEmpty) _carica();
  }

  Future<void> _carica() async {
    final archivio = SessioneScope.of(context).archivio;
    final oggi = soloData(DateTime.now());
    try {
      final r = await Future.wait([archivio.corseDelGiorno(oggi), archivio.prenotatiPerCorsa(oggi)]);
      _corse = {
        for (final c in r[0] as List<Corsa>)
          if (c.tratta == _tratta) c.lineaId: c,
      };
      _prenotati = r[1] as Map<int, int>;
    } catch (e) {
      if (mounted) mostraMessaggio(context, 'Impossibile caricare le corse');
    }
    if (mounted) setState(() => _caricamento = false);
  }

  Future<void> _apri(Linea linea) async {
    final sessione = SessioneScope.of(context);
    final c = _corse[linea.id];
    Corsa? corsa = c;
    final mia = c != null && c.autistaId == sessione.profilo!.id;
    if (c == null || c.stato == StatoCorsa.programmata || (c.stato == StatoCorsa.inCorso && !mia)) {
      final n = await chiediPosti(context, iniziale: c?.posti);
      if (n == null || !mounted) return;
      final ok = await esegui(context, () async {
        corsa = await sessione.archivio.avviaCorsa(linea.id, soloData(DateTime.now()), _tratta, n);
      });
      if (!ok || !mounted) return;
    }
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CorsaPage(corsa: corsa!)));
    _carica();
  }

  @override
  Widget build(BuildContext context) {
    final sessione = SessioneScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Corse di oggi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<Tratta>(
              segments: const [
                ButtonSegment(value: Tratta.andata, label: Text('Mattino'), icon: Icon(Icons.wb_sunny_outlined)),
                ButtonSegment(value: Tratta.ritorno, label: Text('Ritorno'), icon: Icon(Icons.nights_stay_outlined)),
              ],
              selected: {_tratta},
              onSelectionChanged: (s) {
                setState(() {
                  _tratta = s.first;
                  _caricamento = true;
                });
                _carica();
              },
            ),
          ),
          Expanded(
            child: _caricamento
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _carica,
                    child: ListView(children: [for (final l in sessione.linee) _riga(context, l)]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _riga(BuildContext context, Linea l) {
    final c = _corse[l.id];
    final n = c == null ? 0 : (_prenotati[c.id] ?? 0);
    final stato = switch (c?.stato) {
      StatoCorsa.inCorso => 'in corso',
      StatoCorsa.conclusa => 'conclusa',
      _ => 'da avviare',
    };
    return ListTile(
      leading: PallinoLinea(numero: l.id, colore: l.coloreArgb),
      title: Text(l.nome),
      subtitle: Text(
        '${n == 1 ? '1 prenotato' : '$n prenotati'} · $stato${c?.posti != null ? ' · ${posti(c!.posti)}' : ''}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _apri(l),
    );
  }
}

/// Chiede quanti posti ha il veicolo di oggi.
Future<int?> chiediPosti(BuildContext context, {int? iniziale}) {
  final testo = TextEditingController(text: iniziale?.toString() ?? '');
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Posti del veicolo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quanti passeggeri può portare il veicolo di oggi?'),
          const SizedBox(height: 12),
          TextField(
            controller: testo,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Posti', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          onPressed: () {
            final n = int.tryParse(testo.text.trim());
            if (n != null && n > 0) Navigator.pop(context, n);
          },
          child: const Text('Conferma'),
        ),
      ],
    ),
  );
}
