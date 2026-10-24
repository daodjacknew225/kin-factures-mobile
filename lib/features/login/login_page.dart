import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/session_lock.dart';
import '../../widgets/common.dart';

// Connexion (reprend la page /connexion du site). « Mot de passe oublié » et « Créer mon compte »
// ouvrent les pages du site dans le navigateur.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String _error = '';
  // Message transmis à l'ouverture (ex. « Votre session a expiré »)
  final String? _notice = Get.arguments is String ? Get.arguments as String : null;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Saisissez votre adresse email et votre mot de passe.');
      return;
    }
    setState(() {
      _error = '';
      _submitting = true;
    });
    try {
      await Auth.to.signIn(_email.text, _password.text);
      SessionLock.to.unlock();
      Get.offAllNamed(Routes.home);
    } on ApiException catch (error) {
      if (error.status == 401) _password.clear();
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(KfSpace.s6, KfSpace.s8, KfSpace.s6, KfSpace.s6),
          children: [
            const Align(alignment: Alignment.centerLeft, child: KfLogo(height: 36)),
            const SizedBox(height: 40),
            Text('Connexion', style: text.headlineSmall?.copyWith(fontSize: 26)),
            const SizedBox(height: KfSpace.s1),
            Text('Saisissez vos identifiants pour accéder à votre espace.', style: text.bodyLarge?.copyWith(color: KfColors.inkMuted)),
            const SizedBox(height: KfSpace.s6),
            if (_notice != null) ...[KfAlert(_notice, tone: AlertTone.pending), const SizedBox(height: KfSpace.s4)],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Adresse email'),
              enabled: !_submitting,
            ),
            const SizedBox(height: KfSpace.s4),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => launchUrl(Uri.parse(AppConfig.forgotPasswordUrl), mode: LaunchMode.externalApplication),
                child: const Text('Mot de passe oublié ?'),
              ),
            ),
            if (_error.isNotEmpty) ...[KfAlert(_error), const SizedBox(height: KfSpace.s4)],
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Connexion…' : 'Se connecter'),
            ),
            const SizedBox(height: KfSpace.s6),
            const Divider(),
            const SizedBox(height: KfSpace.s4),
            Text('Pas encore de compte ?', textAlign: TextAlign.center, style: text.bodySmall),
            const SizedBox(height: KfSpace.s2),
            OutlinedButton(
              onPressed: () => launchUrl(Uri.parse(AppConfig.signupUrl), mode: LaunchMode.externalApplication),
              child: const Text('Créer mon compte'),
            ),
            const SizedBox(height: KfSpace.s4),
            Text(
              'Collaborateur d’une entreprise déjà inscrite ? Demandez une invitation à son administrateur.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
