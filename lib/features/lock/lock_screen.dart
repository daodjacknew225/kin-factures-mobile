import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/session_lock.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';

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
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: KfColors.surface,
        child: SingleChildScrollView(
          child: Column(children: [
            // Bandeau vert : compte verrouillé
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(KfSpace.s6, top + KfSpace.s8, KfSpace.s6, 72),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [KfColors.brandHover, KfColors.brand]),
              ),
              child: Column(children: [
                KfAvatar(Auth.to.name, size: 72, inverted: true),
                const SizedBox(height: KfSpace.s4),
                Text(Auth.to.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: KfColors.onBrand)),
                Text(Auth.to.email, style: TextStyle(fontSize: 14, color: KfColors.onBrand.withValues(alpha: 0.8))),
              ]),
            ),
            Transform.translate(
              offset: const Offset(0, -48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4),
                child: Container(
                  padding: const EdgeInsets.all(KfSpace.s6),
                  decoration: BoxDecoration(
                    color: KfColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: KfColors.ink.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Row(children: [
                      Icon(LucideIcons.lock, size: 20, color: KfColors.brand),
                      SizedBox(width: KfSpace.s2),
                      Text('Session verrouillée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: KfSpace.s1),
                    const Text(
                      'Après 15 minutes sans activité, Kin Factures se verrouille pour protéger vos données.',
                      style: TextStyle(fontSize: 14, color: KfColors.inkMuted),
                    ),
                    const SizedBox(height: KfSpace.s6),
                    Obx(() => SessionLock.to.biometricAvailable.value
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: KfSpace.s4),
                            child: FilledButton.icon(
                              onPressed: _busy ? null : SessionLock.to.unlockWithDevice,
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                              icon: const Icon(LucideIcons.fingerprint),
                              label: const Text('Déverrouiller avec l’empreinte', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          )
                        : const SizedBox.shrink()),
                    KfLabeledField(
                      label: 'Ou avec votre mot de passe',
                      controller: _password,
                      hint: 'Votre mot de passe',
                      obscureText: true,
                      enabled: !_busy,
                      // Pas de remplissage automatique : le mot de passe doit être ressaisi
                      autofillHints: const [],
                      onSubmitted: (_) => _unlockWithPassword(),
                    ),
                    const SizedBox(height: KfSpace.s4),
                    if (_error.isNotEmpty) ...[KfAlert(_error), const SizedBox(height: KfSpace.s4)],
                    OutlinedButton(
                      onPressed: _busy ? null : _unlockWithPassword,
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(_busy ? 'Vérification…' : 'Déverrouiller', style: const TextStyle(fontWeight: FontWeight.w600)),
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
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
