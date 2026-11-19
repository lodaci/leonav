import 'package:material_ui/material_ui.dart';

import '../../calendario.dart';
import '../../modelli.dart';
import '../../servizi/sessione.dart';
import '../widgets/comuni.dart';

/// Scelta di linea e fermata per un giorno e una tratta.
class PrenotaSheet extends StatefulWidget {
  const PrenotaSheet({super.key, required this.giorno, required this.tratta, this.esistente});

  final DateTime giorno;
  final Tratta tratta;
  final Prenotazione? esistente;

  @override
  State<PrenotaSheet> createState() => _PrenotaSheetState();
}

class _PrenotaSheetState extends State<PrenotaSheet> {
  int? _linea;
  int? _fermata;
  bool _invio = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_linea != null) return;
    final sessione = SessioneScope.of(context);
    final profilo = sessione.profilo!;
    final attuale = sessione.fermata(widget.esistente?.fermataId);
    final abituale = sessione.fermata(widget.tratta == Tratta.andata ? profilo.fermataAndata : profilo.fermataRitorno);
    _linea = attuale?.lineaId ?? abituale?.lineaId ?? profilo.lineaAbituale ?? sessione.linee.first.id;
    _fermata = attuale?.id ?? (abituale?.lineaId == _linea ? abituale?.id : null);
  }

  Future<void> _conferma() async {
    final sessione = SessioneScope.of(context);
    setState(() => _invio = true);
    final ok = await esegui(
      context,
      () => sessione.archivio.prenota(widget.giorno, _fermata!),
      ok: 'Prenotazione salvata',
    );
    if (!mounted) return;
    setState(() => _invio = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _annulla() async {
    final sessione = SessioneScope.of(context);
    setState(() => _invio = true);
    final ok = await esegui(
      context,
      () => sessione.archivio.annulla(widget.esistente!.id),
      ok: 'Prenotazione annullata',
    );
    if (!mounted) return;
    setState(() => _invio = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final sessione = SessioneScope.of(context);
    final fermate = sessione.fermatePrenotabili(_linea!, widget.tratta);
    final linea = sessione.linea(_linea!);
    final imp = sessione.impostazioni!;
    final primo = sessione.primoOrario(_linea!, widget.tratta);
    final adesso = DateTime.now();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.tratta.etichetta} · ${giornoLungo(widget.giorno)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.tratta == Tratta.andata
                        ? 'Scegli dove salire. Puoi cambiare fino a ${imp.minutiAnticipo} minuti prima del passaggio.'
                        : 'Scegli dove scendere. Partenza dallo stabilimento alle ${linea.orarioRitorno}.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _linea,
                    decoration: const InputDecoration(labelText: 'Linea', border: OutlineInputBorder()),
                    items: [for (final l in sessione.linee) DropdownMenuItem(value: l.id, child: Text(l.titolo))],
                    onChanged: (v) => setState(() {
                      _linea = v;
                      _fermata = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RadioGroup<int>(
                groupValue: _fermata,
                onChanged: (v) => setState(() => _fermata = v),
                child: ListView(
                  children: [
                    for (final f in fermate)
                      Builder(
                        builder: (context) {
                          final chiusa = adesso.isAfter(
                            limiteModifica(widget.giorno, f, linea, imp, primoOrarioTratta: primo),
                          );
                          final dettagli = [?f.orario, if (chiusa) 'non più prenotabile'];
                          return RadioListTile<int>(
                            value: f.id,
                            enabled: !chiusa,
                            title: Text(f.nomeBreve),
                            subtitle: dettagli.isEmpty ? null : Text(dettagli.join(' · ')),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  if (widget.esistente != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _invio ? null : _annulla,
                        child: const Text('Annulla prenotazione'),
                      ),
                    ),
                  if (widget.esistente != null) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _invio || _fermata == null ? null : _conferma,
                      child: Text(widget.esistente == null ? 'Prenota' : 'Salva'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
