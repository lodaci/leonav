import 'package:material_ui/material_ui.dart';

import '../../calendario.dart';
import '../../modelli.dart';
import '../../servizi/sessione.dart';
import '../widgets/comuni.dart';
import 'prenota_sheet.dart';

class PrenotazioniPage extends StatefulWidget {
  const PrenotazioniPage({super.key});

  @override
  State<PrenotazioniPage> createState() => _PrenotazioniPageState();
}

class _PrenotazioniPageState extends State<PrenotazioniPage> {
  List<Prenotazione>? _prenotazioni;
  String? _errore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prenotazioni == null && _errore == null) _carica();
  }

  Future<void> _carica() async {
    final sessione = SessioneScope.of(context);
    try {
      final p = await sessione.archivio.miePrenotazioni(soloData(DateTime.now()));
      if (mounted) setState(() => _prenotazioni = p);
    } catch (e) {
      if (mounted) setState(() => _errore = '$e');
    }
  }

  Prenotazione? _trova(DateTime giorno, Tratta tratta) {
    for (final p in _prenotazioni ?? <Prenotazione>[]) {
      if (p.data == giorno && p.tratta == tratta) return p;
    }
    return null;
  }

  Future<void> _apri(DateTime giorno, Tratta tratta, Prenotazione? esistente) async {
    final cambiato = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PrenotaSheet(giorno: giorno, tratta: tratta, esistente: esistente),
    );
    if (cambiato == true) _carica();
  }

  @override
  Widget build(BuildContext context) {
    final sessione = SessioneScope.of(context);
    final giorni = giorniPrenotabili(DateTime.now(), sessione.impostazioni!, sessione.festivi);
    return Scaffold(
      appBar: AppBar(title: const Text('Le mie prenotazioni')),
      body: _prenotazioni == null
          ? (_errore != null
                ? Vuoto(
                    icona: Icons.cloud_off,
                    testo: 'Impossibile caricare le prenotazioni',
                    azione: FilledButton(onPressed: _carica, child: const Text('Riprova')),
                  )
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: giorni.length,
                itemBuilder: (context, i) {
                  final g = giorni[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text(giornoLungo(g), style: Theme.of(context).textTheme.titleMedium),
                          ),
                          for (final t in Tratta.values) _riga(context, g, t),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _riga(BuildContext context, DateTime giorno, Tratta tratta) {
    final sessione = SessioneScope.of(context);
    final p = _trova(giorno, tratta);
    final f = sessione.fermata(p?.fermataId);
    final icona = tratta == Tratta.andata ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined;
    if (p == null || f == null) {
      return ListTile(
        leading: Icon(icona),
        title: Text(tratta.etichetta),
        subtitle: const Text('Non prenotato'),
        trailing: const Icon(Icons.add_circle_outline),
        onTap: () => _apri(giorno, tratta, null),
      );
    }
    final linea = sessione.linea(f.lineaId);
    final orario = f.orario ?? (tratta == Tratta.ritorno ? 'partenza ${linea.orarioRitorno}' : null);
    return ListTile(
      leading: Icon(icona, color: Color(linea.coloreArgb)),
      title: Text('${tratta.etichetta} · Linea ${linea.id}'),
      subtitle: Text([f.nomeBreve, ?orario].join(' · ')),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => _apri(giorno, tratta, p),
    );
  }
}
