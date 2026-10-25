import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/biometric_login.dart';
import '../../core/session_lock.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/kit.dart';

// Connexion : bandeau vert, carte blanche avec email et mot de passe, connexion par empreinte si
// elle est activée sur ce téléphone. « Mot de passe oublié » et « Créer mon compte » ouvrent le site.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

const _lastEmailKey = 'kf_last_email';

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(text: GetStorage().read<String>(_lastEmailKey) ?? '');
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _biometric = false; // connexion par empreinte activée sur ce téléphone
  String _error = '';
  // Message transmis à l'ouverture (ex. « Votre session a expiré »)
  final String? _notice = Get.arguments is String ? Get.arguments as String : null;

  @override
  void initState() {
    super.initState();
    BiometricLogin.enabled().then((enabled) async {
      if (!mounted || !enabled) return;
      final email = await BiometricLogin.savedEmail();
      setState(() {
        _biometric = true;
        if (email != null) _email.text = email;
      });
      // Empreinte proposée dès l'ouverture
      WidgetsBinding.instance.addPostFrameCallback((_) => _signInWithBiometric());
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn(String email, String password, {required bool fromBiometric}) async {
    setState(() {
      _error = '';
      _submitting = true;
    });
    try {
      await Auth.to.signIn(email, password);
      GetStorage().write(_lastEmailKey, email.trim());
      SessionLock.to.unlock();
      HapticFeedback.lightImpact();
      if (!fromBiometric) await _offerBiometric(email, password);
      Get.offAllNamed(Routes.home);
    } on ApiException catch (error) {
      if (fromBiometric && error.status == 401) {
        // Mot de passe changé depuis : l'empreinte ne suffit plus
        await BiometricLogin.disable();
        setState(() {
          _biometric = false;
          _error = 'Votre mot de passe a changé : saisissez-le pour vous connecter. Vous pourrez réactiver l’empreinte ensuite.';
        });
      } else {
        if (error.status == 401) _password.clear();
        setState(() => _error = error.message);
      }
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Saisissez votre adresse email et votre mot de passe.');
      return;
    }
    await _signIn(_email.text, _password.text, fromBiometric: false);
  }

  Future<void> _signInWithBiometric() async {
    if (_submitting) return;
    final credentials = await BiometricLogin.unlock();
    if (credentials == null || !mounted) return;
    await _signIn(credentials.$1, credentials.$2, fromBiometric: true);
  }

  // Après une connexion par mot de passe : proposer l'empreinte (une seule fois si refusée)
  Future<void> _offerBiometric(String email, String password) async {
    if (!await BiometricLogin.shouldOffer()) return;
    final accept = await confirmAction(
      title: 'Connexion par empreinte',
      message: 'La prochaine fois, connectez-vous simplement avec votre empreinte. '
          'Vos identifiants restent chiffrés sur ce téléphone.',
      confirmLabel: 'Activer',
    );
    if (!accept) {
      BiometricLogin.decline();
      return;
    }
    if (await BiometricLogin.enable(email, password)) showNotice('Connexion par empreinte activée.');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: KfColors.surface,
        body: SingleChildScrollView(
          child: Column(children: [
            // Bandeau vert : logo et accroche
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(KfSpace.s6, top + KfSpace.s8, KfSpace.s6, 72),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [KfColors.heroStart, KfColors.heroEnd]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: KfColors.onHero, borderRadius: BorderRadius.circular(12)),
                    child: SvgPicture.asset('assets/logo-kin-factures-icone.svg'),
                  ),
                  const SizedBox(width: 12),
                  const Text('Kin Factures', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: KfColors.onHero)),
                ]),
                const SizedBox(height: KfSpace.s8),
                const Text(
                  'Facturez et encaissez,\noù que vous soyez.',
                  style: TextStyle(fontSize: 28, height: 34 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: KfColors.onHero),
                ),
                const SizedBox(height: KfSpace.s2),
                Text(
                  'Factures, liens de paiement et encaissements de votre entreprise, dans votre poche.',
                  style: TextStyle(fontSize: 14, height: 20 / 14, color: KfColors.onHero.withValues(alpha: 0.8)),
                ),
              ]),
            ),

            // Carte de connexion, qui remonte sur le bandeau
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
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Connexion', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Heureux de vous revoir.', style: TextStyle(fontSize: 14, color: KfColors.inkMuted)),
                      const SizedBox(height: KfSpace.s6),
                      if (_notice != null) ...[KfAlert(_notice, tone: AlertTone.pending), const SizedBox(height: KfSpace.s4)],
                      KfLabeledField(
                        label: 'Adresse email',
                        controller: _email,
                        hint: 'vous@entreprise.cd',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        enabled: !_submitting,
                      ),
                      const SizedBox(height: KfSpace.s4),
                      KfLabeledField(
                        label: 'Mot de passe',
                        controller: _password,
                        hint: 'Votre mot de passe',
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        enabled: !_submitting,
                        suffix: IconButton(
                          tooltip: _obscure ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                          icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 20, color: KfColors.inkMuted),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => launchUrl(Uri.parse(AppConfig.forgotPasswordUrl), mode: LaunchMode.externalApplication),
                          child: const Text('Mot de passe oublié ?', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      if (_error.isNotEmpty) ...[KfAlert(_error), const SizedBox(height: KfSpace.s4)],
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: _submitting
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: KfColors.onBrand))
                            : const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (_biometric) ...[
                        const SizedBox(height: KfSpace.s3),
                        OutlinedButton.icon(
                          onPressed: _submitting ? null : _signInWithBiometric,
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          icon: Icon(LucideIcons.fingerprint, color: KfColors.brand),
                          label: const Text('Se connecter avec l’empreinte', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: KfSpace.s6),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Pas encore de compte ?', style: TextStyle(fontSize: 14, color: KfColors.inkMuted)),
                    TextButton(
                      onPressed: () => launchUrl(Uri.parse(AppConfig.signupUrl), mode: LaunchMode.externalApplication),
                      child: const Text('Créer mon compte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  Text(
                    'Collaborateur d’une entreprise déjà inscrite ? Demandez une invitation à son administrateur.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: KfColors.inkMuted),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
