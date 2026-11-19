import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servizi/archivio.dart';
import '../servizi/sessione.dart';
import 'accesso_page.dart';
import 'attesa_page.dart';
import 'home_page.dart';

ThemeData _tema(Brightness b) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0), brightness: b),
  useMaterial3: true,
);

class LeoNavApp extends StatelessWidget {
  const LeoNavApp({super.key, required this.sessione});

  final Sessione sessione;

  @override
  Widget build(BuildContext context) {
    return SessioneScope(
      sessione: sessione,
      child: MaterialApp(
        title: 'LeoNav',
        debugShowCheckedModeBanner: false,
        theme: _tema(Brightness.light),
        darkTheme: _tema(Brightness.dark),
        locale: const Locale('it'),
        supportedLocales: const [Locale('it')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        home: const Ingresso(),
      ),
    );
  }
}

/// Mostra l'accesso, l'attesa di approvazione o l'app, in base allo stato dell'account.
class Ingresso extends StatefulWidget {
  const Ingresso({super.key});

  @override
  State<Ingresso> createState() => _IngressoState();
}

class _IngressoState extends State<Ingresso> {
  StreamSubscription<AuthState>? _sub;
  bool _caricamento = true;
  String? _errore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sub != null) return;
    final sessione = SessioneScope.of(context);
    _sub = sessione.archivio.db.auth.onAuthStateChange.listen((stato) {
      if (stato.event == AuthChangeEvent.signedOut) {
        sessione.svuota();
        if (mounted) setState(() => _caricamento = false);
      } else if (stato.event == AuthChangeEvent.signedIn || stato.event == AuthChangeEvent.initialSession) {
        _carica();
      }
    });
  }

  Future<void> _carica() async {
    final sessione = SessioneScope.of(context);
    if (sessione.archivio.db.auth.currentUser == null) {
      setState(() => _caricamento = false);
      return;
    }
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      await sessione.carica();
    } catch (e) {
      _errore = messaggioErrore(e);
    }
    if (mounted) setState(() => _caricamento = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessione = SessioneScope.of(context);
    if (_caricamento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_errore != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_errore!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _carica, child: const Text('Riprova')),
                TextButton(onPressed: sessione.archivio.esci, child: const Text('Esci')),
              ],
            ),
          ),
        ),
      );
    }
    final profilo = sessione.profilo;
    if (sessione.archivio.db.auth.currentUser == null || profilo == null) return const AccessoPage();
    if (!profilo.approvato) return AttesaPage(suControlla: _carica);
    return const HomePage();
  }
}

class ConfigurazioneMancante extends StatelessWidget {
  const ConfigurazioneMancante({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configurazione mancante.\nAvvia l\'app con --dart-define=SUPABASE_URL=... '
              'e --dart-define=SUPABASE_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
