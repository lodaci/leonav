import 'package:material_ui/material_ui.dart';

import '../servizi/archivio.dart';
import '../servizi/sessione.dart';

class AccessoPage extends StatefulWidget {
  const AccessoPage({super.key});

  @override
  State<AccessoPage> createState() => _AccessoPageState();
}

class _AccessoPageState extends State<AccessoPage> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registrazione = false;
  bool _invio = false;
  String? _messaggio;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _conferma() async {
    if (!_form.currentState!.validate()) return;
    final archivio = SessioneScope.of(context).archivio;
    setState(() {
      _invio = true;
      _messaggio = null;
    });
    try {
      if (_registrazione) {
        await archivio.registrati(_nome.text, _email.text, _password.text);
        if (archivio.db.auth.currentSession == null) {
          _messaggio = 'Ti abbiamo inviato un\'email: apri il link per confermare, poi accedi.';
          _registrazione = false;
        }
      } else {
        await archivio.accedi(_email.text, _password.text);
      }
    } catch (e) {
      _messaggio = messaggioErrore(e);
    }
    if (mounted) setState(() => _invio = false);
  }

  Future<void> _recupera() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _messaggio = 'Scrivi prima la tua email');
      return;
    }
    try {
      await SessioneScope.of(context).archivio.recuperaPassword(_email.text);
      setState(() => _messaggio = 'Se l\'email è registrata riceverai un link per reimpostare la password.');
    } catch (e) {
      setState(() => _messaggio = messaggioErrore(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.directions_bus_rounded, size: 64, color: tema.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text('LeoNav', textAlign: TextAlign.center, style: tema.textTheme.headlineMedium),
                    Text('La navetta aziendale', textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
                    const SizedBox(height: 32),
                    if (_registrazione) ...[
                      TextFormField(
                        controller: _nome,
                        decoration: const InputDecoration(labelText: 'Nome e cognome', border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v ?? '').trim().length < 3 ? 'Scrivi nome e cognome' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email aziendale', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) => (v ?? '').contains('@') ? null : 'Email non valida',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      validator: (v) => (v ?? '').length < 8 ? 'Almeno 8 caratteri' : null,
                      onFieldSubmitted: (_) => _conferma(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _invio ? null : _conferma,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(_registrazione ? 'Registrati' : 'Accedi'),
                      ),
                    ),
                    if (_messaggio != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _messaggio!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: tema.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() {
                        _registrazione = !_registrazione;
                        _messaggio = null;
                      }),
                      child: Text(_registrazione ? 'Hai già un account? Accedi' : 'Prima volta? Registrati'),
                    ),
                    if (!_registrazione) TextButton(onPressed: _recupera, child: const Text('Password dimenticata')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
