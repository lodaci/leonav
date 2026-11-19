import 'package:material_ui/material_ui.dart';

import '../servizi/sessione.dart';
import 'autista/corse_oggi_page.dart';
import 'passeggero/navetta_live_page.dart';
import 'passeggero/prenotazioni_page.dart';
import 'profilo_page.dart';
import 'rilevatore/rilevatore_page.dart';

class _Scheda {
  const _Scheda(this.etichetta, this.icona, this.pagina);
  final String etichetta;
  final IconData icona;
  final Widget pagina;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final profilo = SessioneScope.of(context).profilo!;
    final schede = <_Scheda>[
      if (profilo.viaggia) const _Scheda('Prenotazioni', Icons.event_available, PrenotazioniPage()),
      if (profilo.viaggia) const _Scheda('Navetta', Icons.directions_bus, NavettaLivePage()),
      if (profilo.guida) const _Scheda('Guida', Icons.airline_seat_recline_normal, CorseOggiPage()),
      if (profilo.rilevatore) const _Scheda('Rilevatore', Icons.add_location_alt, RilevatorePage()),
      const _Scheda('Profilo', Icons.person, ProfiloPage()),
    ];
    final i = _indice.clamp(0, schede.length - 1);
    return Scaffold(
      body: IndexedStack(index: i, children: [for (final s in schede) s.pagina]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (n) => setState(() => _indice = n),
        destinations: [for (final s in schede) NavigationDestination(icon: Icon(s.icona), label: s.etichetta)],
      ),
    );
  }
}
