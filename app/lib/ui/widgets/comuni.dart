import 'package:material_ui/material_ui.dart';

import '../../servizi/archivio.dart';

void mostraMessaggio(BuildContext context, String testo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(testo)));
}

/// Esegue [azione] mostrando l'eventuale errore. Restituisce true se e' andata a buon fine.
Future<bool> esegui(BuildContext context, Future<void> Function() azione, {String? ok}) async {
  try {
    await azione();
    if (ok != null && context.mounted) mostraMessaggio(context, ok);
    return true;
  } catch (e) {
    if (context.mounted) mostraMessaggio(context, messaggioErrore(e));
    return false;
  }
}

class Vuoto extends StatelessWidget {
  const Vuoto({super.key, required this.icona, required this.testo, this.azione});

  final IconData icona;
  final String testo;
  final Widget? azione;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icona, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(testo, textAlign: TextAlign.center),
          if (azione != null) ...[const SizedBox(height: 16), azione!],
        ],
      ),
    ),
  );
}

class PallinoLinea extends StatelessWidget {
  const PallinoLinea({super.key, required this.numero, required this.colore});

  final int numero;
  final int colore;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 16,
    backgroundColor: Color(colore),
    child: Text(
      '$numero',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}

String posti(int? n) => n == null ? '? posti' : (n == 1 ? '1 posto' : '$n posti');
