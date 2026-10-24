import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/session_lock.dart';
import '../../widgets/common.dart';

// Écran de verrouillage après inactivité (comme SessionLock du site) : par-dessus l'application,
// qui garde son état. Déverrouillage par empreinte / code du téléphone, ou par mot de passe.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    // Propose l'empreinte dès l'affichage
    if (SessionLock.to.biometricAvailable.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => SessionLock.to.unlockWithDevice());
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlockWithPassword() async {
    if (_password.text.isEmpty) return setState(() => _error = 'Saisissez votre mot de passe.');
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await Auth.to.signIn(Auth.to.email, _password.text);
      SessionLock.to.unlock();
    } on ApiException catch (error) {
      _password.clear();
      setState(() => _error = error.status == 401 ? 'Mot de passe incorrect.' : error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: KfColors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(KfSpace.s6),
          children: [
            const SizedBox(height: KfSpace.s8),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: KfColors.brandSoft, shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline, color: KfColors.brand, size: 30),
              ),
            ),
            const SizedBox(height: KfSpace.s6),
            Text('Session verrouillée', textAlign: TextAlign.center, style: text.headlineSmall),
            const SizedBox(height: KfSpace.s2),
            Text(
              'Après 15 minutes sans activité, Kin Factures se verrouille pour protéger vos données.',
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: KfColors.inkMuted),
            ),
            const SizedBox(height: KfSpace.s2),
            Text(Auth.to.email, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: KfSpace.s6),
            Obx(() => SessionLock.to.biometricAvailable.value
                ? Padding(
                    padding: const EdgeInsets.only(bottom: KfSpace.s6),
                    child: FilledButton.icon(
                      onPressed: _busy ? null : SessionLock.to.unlockWithDevice,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Déverrouiller avec l’empreinte'),
                    ),
                  )
                : const SizedBox.shrink()),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              // Pas de remplissage automatique : le mot de passe doit être ressaisi
              autofillHints: const [],
              enableSuggestions: false,
              onSubmitted: (_) => _unlockWithPassword(),
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            const SizedBox(height: KfSpace.s4),
            if (_error.isNotEmpty) ...[KfAlert(_error), const SizedBox(height: KfSpace.s4)],
            OutlinedButton(
              onPressed: _busy ? null : _unlockWithPassword,
              child: Text(_busy ? 'Vérification…' : 'Déverrouiller avec le mot de passe'),
            ),
            const SizedBox(height: KfSpace.s2),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      SessionLock.to.unlock();
                      Auth.to.signOut();
                    },
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
      ),
    );
  }
}
