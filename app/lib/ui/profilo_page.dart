import 'package:material_ui/material_ui.dart';

import '../modelli.dart';
import '../servizi/sessione.dart';
import 'widgets/comuni.dart';

class ProfiloPage extends StatefulWidget {
  const ProfiloPage({super.key});

  @override
  State<ProfiloPage> createState() => _ProfiloPageState();
}

class _ProfiloPageState extends State<ProfiloPage> {
  final _nome = TextEditingController();
  int? _linea;
  int? _andata;
  int? _ritorno;
  bool _pronto = false;
  bool _invio = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pronto) return;
    final p = SessioneScope.of(context).profilo!;
    _nome.text = p.nome;
    _linea = p.lineaAbituale;
    _andata = p.fermataAndata;
    _ritorno = p.fermataRitorno;
    _pronto = true;
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    final sessione = SessioneScope.of(context);
    setState(() => _invio = true);
    final ok = await esegui(
      context,
      () => sessione.archivio.aggiornaProfilo(
        nome: _nome.text.trim(),
        linea: _linea,
        fermataAndata: _andata,
        fermataRitorno: _ritorno,
      ),
      ok: 'Profilo salvato',
    );
    if (ok) await sessione.carica();
    if (mounted) setState(() => _invio = false);
  }

  @override
  Widget build(BuildContext context) {
    final sessione = SessioneScope.of(context);
    final p = sessione.profilo!;
    final ruolo = switch (p.ruolo) {
      Ruolo.passeggero => 'Passeggero',
      Ruolo.autista => 'Autista',
      Ruolo.admin => 'Amministratore',
    };
    DropdownButtonFormField<int> sceltaFermata(String etichetta, Tratta t, int? valore, ValueChanged<int?> cambia) {
      final fermate = _linea == null ? <Fermata>[] : sessione.fermatePrenotabili(_linea!, t);
      return DropdownButtonFormField<int>(
        key: ValueKey('$etichetta-$_linea'),
        initialValue: fermate.any((f) => f.id == valore) ? valore : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: etichetta, border: const OutlineInputBorder()),
        items: [
          for (final f in fermate)
            DropdownMenuItem(
              value: f.id,
              child: Text(f.nomeBreve, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: cambia,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(p.email),
            subtitle: Text([ruolo, if (p.sviluppatore) 'sviluppatore'].join(' · ')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nome,
            decoration: const InputDecoration(labelText: 'Nome e cognome', border: OutlineInputBorder()),
          ),
          if (p.viaggia) ...[
            const SizedBox(height: 24),
            Text('Linea e fermate abituali', style: Theme.of(context).textTheme.titleMedium),
            const Text('Vengono proposte quando prenoti.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _linea,
              decoration: const InputDecoration(labelText: 'Linea', border: OutlineInputBorder()),
              items: [for (final l in sessione.linee) DropdownMenuItem(value: l.id, child: Text(l.titolo))],
              onChanged: (v) => setState(() {
                _linea = v;
                _andata = null;
                _ritorno = null;
              }),
            ),
            const SizedBox(height: 12),
            sceltaFermata('Salgo a (andata)', Tratta.andata, _andata, (v) => setState(() => _andata = v)),
            const SizedBox(height: 12),
            sceltaFermata('Scendo a (ritorno)', Tratta.ritorno, _ritorno, (v) => setState(() => _ritorno = v)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _invio ? null : _salva, child: const Text('Salva')),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: sessione.archivio.esci,
            icon: const Icon(Icons.logout),
            label: const Text('Esci'),
          ),
        ],
      ),
    );
  }
}
