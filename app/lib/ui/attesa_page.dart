import 'package:material_ui/material_ui.dart';

import '../servizi/sessione.dart';

class AttesaPage extends StatelessWidget {
  const AttesaPage({super.key, required this.suControlla});

  final VoidCallback suControlla;

  @override
  Widget build(BuildContext context) {
    final sessione = SessioneScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 56),
                const SizedBox(height: 16),
                Text('Account in attesa di approvazione', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Ciao ${sessione.profilo?.nome ?? ''}, un amministratore deve approvare il tuo account. '
                  'Riceverai accesso appena fatto.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: suControlla, child: const Text('Controlla di nuovo')),
                TextButton(onPressed: sessione.archivio.esci, child: const Text('Esci')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
