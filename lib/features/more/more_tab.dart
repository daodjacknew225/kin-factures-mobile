import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/biometric_login.dart';
import '../../core/privacy.dart';
import '../../core/theme_controller.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/kit.dart';
import '../products/products_page.dart';
import 'account_page.dart';

// Onglet « Plus » : profil, gestion, préférences (apparence, montants masqués), sécurité
// (empreinte, mot de passe), aide et à propos, déconnexion.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Auth.to;
    return Scaffold(
      backgroundColor: KfColors.surface,
      body: ListView(padding: EdgeInsets.zero, children: [
        const KfPageHeader(title: 'Plus'),
        Padding(
          padding: const EdgeInsets.fromLTRB(KfSpace.s4, 0, KfSpace.s4, KfSpace.s8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Profil
            KfGroup(children: [
              Obx(() => KfRow(
                    leading: KfAvatar(auth.name, size: 48),
                    title: auth.name,
                    subtitle: '${auth.roleName} · ${auth.companyName.value}',
                    trailing: Icon(LucideIcons.chevronRight, size: 18, color: KfColors.inkMuted),
                    onTap: () => Get.to(() => const AccountPage()),
                  )),
            ]),

            const KfOverline('Gestion'),
            KfGroup(dividerIndent: 64, children: [
              KfSettingRow(icon: LucideIcons.package, title: 'Produits et services', onTap: () => Get.to(() => const ProductsPage())),
              if (auth.can('retraits.demander'))
                const KfSettingRow(icon: LucideIcons.wallet, title: 'Solde et retraits', subtitle: 'Bientôt dans l’application'),
            ]),

            const KfOverline('Préférences'),
            KfGroup(dividerIndent: 64, children: [
              Obx(() => KfSettingRow(
                    icon: LucideIcons.sunMoon,
                    title: 'Apparence',
                    subtitle: switch (ThemeController.to.choice.value) {
                      ThemeChoice.system => 'Automatique (comme le téléphone)',
                      ThemeChoice.light => 'Clair',
                      ThemeChoice.dark => 'Sombre',
                    },
                    onTap: _chooseTheme,
                  )),
              Obx(() => KfSettingRow(
                    icon: LucideIcons.eyeOff,
                    title: 'Masquer les montants',
                    subtitle: 'Pour montrer l’écran sans dévoiler vos chiffres',
                    trailing: Switch(value: Privacy.to.hidden.value, onChanged: (_) => Privacy.to.toggle(), activeThumbColor: KfColors.brand),
                    onTap: Privacy.to.toggle,
                  )),
            ]),

            const KfOverline('Sécurité'),
            KfGroup(dividerIndent: 64, children: [
              const _BiometricSwitch(),
              KfSettingRow(icon: LucideIcons.keyRound, title: 'Changer mon mot de passe', subtitle: 'Un lien vous est envoyé par email', onTap: changePassword),
            ]),

            const KfOverline('Aide et à propos'),
            KfGroup(dividerIndent: 64, children: [
              KfSettingRow(icon: LucideIcons.messageCircle, title: 'Contacter le support', subtitle: 'WhatsApp, téléphone ou email', onTap: _contactSupport),
              KfSettingRow(icon: LucideIcons.bug, title: 'Signaler un problème', onTap: _reportProblem),
              KfSettingRow(
                icon: LucideIcons.externalLink,
                title: 'Ouvrir le site Kin Factures',
                subtitle: 'Paramètres, utilisateurs, factures récurrentes…',
                onTap: () => launchUrl(Uri.parse(AppConfig.siteUrl), mode: LaunchMode.externalApplication),
              ),
              KfSettingRow(icon: LucideIcons.fileText, title: 'Conditions d’utilisation', onTap: () => launchUrl(Uri.parse(AppConfig.termsUrl))),
              KfSettingRow(icon: LucideIcons.shieldCheck, title: 'Confidentialité', onTap: () => launchUrl(Uri.parse(AppConfig.privacyUrl))),
              const _VersionRow(),
            ]),

            const SizedBox(height: KfSpace.s6),
            KfGroup(children: [
              KfSettingRow(icon: LucideIcons.logOut, title: 'Se déconnecter', danger: true, onTap: _signOut),
            ]),
          ]),
        ),
      ]),
    );
  }

  Future<void> _signOut() async {
    final ok = await confirmAction(
      title: 'Se déconnecter',
      message: 'Vous devrez vous reconnecter pour accéder à vos factures sur ce téléphone.',
      confirmLabel: 'Se déconnecter',
      danger: true,
    );
    if (ok) Auth.to.signOut();
  }
}

// Apparence : clair, sombre ou automatique
Future<void> _chooseTheme() => Get.bottomSheet<void>(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, KfSpace.s4),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KfSheetHandle(),
            const Padding(
              padding: EdgeInsets.fromLTRB(KfSpace.s1, KfSpace.s4, 0, KfSpace.s3),
              child: Text('Apparence', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            KfGroup(dividerIndent: 64, children: [
              for (final (choice, icon, label, hint) in [
                (ThemeChoice.system, LucideIcons.smartphone, 'Automatique', 'Suit le réglage du téléphone'),
                (ThemeChoice.light, LucideIcons.sun, 'Clair', null),
                (ThemeChoice.dark, LucideIcons.moon, 'Sombre', null),
              ])
                KfSettingRow(
                  icon: icon,
                  title: label,
                  subtitle: hint,
                  trailing: ThemeController.to.choice.value == choice ? Icon(LucideIcons.check, color: KfColors.brand, size: 20) : null,
                  onTap: () {
                    Get.back();
                    ThemeController.to.select(choice);
                  },
                ),
            ]),
          ]),
        ),
      ),
      backgroundColor: KfColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    );

// Lien « choisir un nouveau mot de passe » envoyé par email (même parcours que sur le site)
Future<void> changePassword() async {
  final email = Auth.to.email;
  final ok = await confirmAction(
    title: 'Changer mon mot de passe',
    message: 'Un lien pour choisir un nouveau mot de passe va être envoyé à $email. Il est valable 24 heures.',
    confirmLabel: 'Envoyer le lien',
  );
  if (!ok) return;
  try {
    await Api.to.post('/auth/request-password-reset', {'email': email, 'redirectTo': AppConfig.setPasswordUrl});
    showNotice('Lien envoyé à $email. Pensez à regarder dans les courriers indésirables.');
  } on ApiException catch (error) {
    showNotice(error.message, error: true);
  }
}

Future<void> _contactSupport() => Get.bottomSheet<void>(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, KfSpace.s4),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KfSheetHandle(),
            const Padding(
              padding: EdgeInsets.fromLTRB(KfSpace.s1, KfSpace.s4, 0, KfSpace.s1),
              child: Text('Contacter le support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(KfSpace.s1, 0, 0, KfSpace.s3),
              child: Text('Une question, un souci ? L’équipe Kin Factures vous répond.', style: TextStyle(fontSize: 13, color: KfColors.inkMuted)),
            ),
            KfGroup(dividerIndent: 64, children: [
              KfSettingRow(
                icon: LucideIcons.messageCircle,
                title: 'WhatsApp',
                subtitle: '+243 814 864 186',
                onTap: () => launchUrl(Uri.parse(AppConfig.supportWhatsApp), mode: LaunchMode.externalApplication),
              ),
              KfSettingRow(
                icon: LucideIcons.phone,
                title: 'Appeler',
                subtitle: '+243 814 864 186',
                onTap: () => launchUrl(Uri(scheme: 'tel', path: AppConfig.supportPhone)),
              ),
              KfSettingRow(
                icon: LucideIcons.mail,
                title: 'Email',
                subtitle: AppConfig.supportEmail,
                onTap: () => launchUrl(Uri(scheme: 'mailto', path: AppConfig.supportEmail, query: 'subject=${Uri.encodeComponent('Kin Factures — question')}')),
              ),
            ]),
          ]),
        ),
      ),
      backgroundColor: KfColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    );

// Email pré-rempli avec la version de l'application et le compte (pour aider le support)
Future<void> _reportProblem() async {
  final info = await PackageInfo.fromPlatform();
  final body = 'Décrivez le problème (ce que vous faisiez, ce qui s’est passé) :\n\n\n'
      '—\nKin Factures ${info.version} (${info.buildNumber}) · Android\n'
      'Compte : ${Auth.to.email} · ${Auth.to.companyName.value}';
  await launchUrl(Uri(
    scheme: 'mailto',
    path: AppConfig.supportEmail,
    query: 'subject=${Uri.encodeComponent('Kin Factures — problème signalé')}&body=${Uri.encodeComponent(body)}',
  ));
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (_, snapshot) => KfSettingRow(
          icon: LucideIcons.info,
          title: 'Version',
          trailing: Text(
            snapshot.hasData ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})' : '…',
            style: TextStyle(fontSize: 14, color: KfColors.inkMuted),
          ),
        ),
      );
}

// Sécurité : activer ou désactiver la connexion par empreinte sur ce téléphone
class _BiometricSwitch extends StatefulWidget {
  const _BiometricSwitch();

  @override
  State<_BiometricSwitch> createState() => _BiometricSwitchState();
}

class _BiometricSwitchState extends State<_BiometricSwitch> {
  bool? _available;
  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.wait([BiometricLogin.available(), BiometricLogin.enabled()]).then((values) {
      if (!mounted) return;
      setState(() {
        _available = values[0];
        _enabled = values[1];
      });
    });
  }

  // Activation : le mot de passe est redemandé (il n'est jamais gardé en dehors du coffre)
  Future<void> _toggle(bool on) async {
    if (!on) {
      await BiometricLogin.disable();
      setState(() => _enabled = false);
      showNotice('Connexion par empreinte désactivée.');
      return;
    }
    final password = TextEditingController();
    final ok = await confirmAction(
      title: 'Connexion par empreinte',
      message: 'Saisissez votre mot de passe pour activer la connexion par empreinte sur ce téléphone.',
      confirmLabel: 'Continuer',
      extra: Padding(
        padding: const EdgeInsets.only(top: KfSpace.s4),
        child: TextField(controller: password, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'Mot de passe')),
      ),
    );
    if (!ok || password.text.isEmpty) return;
    setState(() => _busy = true);
    try {
      // Vérifie le mot de passe avant de le garder
      await Auth.to.signIn(Auth.to.email, password.text);
      if (await BiometricLogin.enable(Auth.to.email, password.text)) {
        setState(() => _enabled = true);
        showNotice('Connexion par empreinte activée.');
      }
    } catch (_) {
      showNotice('Mot de passe incorrect.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => KfSettingRow(
        icon: LucideIcons.fingerprint,
        title: 'Connexion par empreinte',
        subtitle: _available == false ? 'Aucune empreinte enregistrée sur ce téléphone' : 'Se connecter sans saisir le mot de passe',
        trailing: Switch(
          value: _enabled,
          onChanged: _available != true || _busy ? null : _toggle,
          activeThumbColor: KfColors.brand,
        ),
      );
}
