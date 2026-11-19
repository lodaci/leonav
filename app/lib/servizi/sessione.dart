import 'package:material_ui/material_ui.dart';

import '../modelli.dart';
import 'archivio.dart';

/// Dati dell'utente collegato e configurazione, caricati una volta dopo l'accesso.
class Sessione extends ChangeNotifier {
  Sessione(this.archivio);

  final Archivio archivio;

  Profilo? profilo;
  Impostazioni? impostazioni;
  Set<DateTime> festivi = {};
  List<Linea> linee = [];
  List<Fermata> fermate = [];

  Future<void> carica() async {
    profilo = await archivio.mioProfilo();
    if (profilo!.approvato) {
      final r = await Future.wait([archivio.impostazioni(), archivio.festivi(), archivio.linee(), archivio.fermate()]);
      impostazioni = r[0] as Impostazioni;
      festivi = r[1] as Set<DateTime>;
      linee = r[2] as List<Linea>;
      fermate = r[3] as List<Fermata>;
    }
    notifyListeners();
  }

  void svuota() {
    profilo = null;
    impostazioni = null;
    festivi = {};
    linee = [];
    fermate = [];
  }

  Linea linea(int id) => linee.firstWhere((l) => l.id == id);

  Fermata? fermata(int? id) {
    if (id == null) return null;
    for (final f in fermate) {
      if (f.id == id) return f;
    }
    return null;
  }

  List<Fermata> fermateDi(int lineaId, Tratta tratta) =>
      fermate.where((f) => f.lineaId == lineaId && f.tratta == tratta).toList()
        ..sort((a, b) => a.ordine.compareTo(b.ordine));

  /// Fermate dove si puo' salire (andata) o scendere (ritorno): tutte tranne lo stabilimento.
  List<Fermata> fermatePrenotabili(int lineaId, Tratta tratta) =>
      fermateDi(lineaId, tratta).where((f) => !f.stabilimento).toList();

  String? primoOrario(int lineaId, Tratta tratta) {
    for (final f in fermateDi(lineaId, tratta)) {
      if (f.orario != null) return f.orario;
    }
    return null;
  }

  void aggiornaFermata(Fermata nuova) {
    final i = fermate.indexWhere((f) => f.id == nuova.id);
    if (i >= 0) fermate[i] = nuova;
    notifyListeners();
  }
}

class SessioneScope extends InheritedNotifier<Sessione> {
  const SessioneScope({super.key, required Sessione sessione, required super.child}) : super(notifier: sessione);

  static Sessione of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessioneScope>()!.notifier!;
}
