import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../widgets/kit.dart';
import 'more_tab.dart';

// Mon compte : identité, profil de droits, entreprise ; changement de mot de passe.
// Le nom et les droits se modifient sur le site (écran Utilisateurs, par un administrateur).
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Auth.to;
    return Scaffold(
      backgroundColor: KfColors.surface,
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListView(padding: const EdgeInsets.all(KfSpace.s4), children: [
        Center(child: KfAvatar(auth.name, size: 80)),
        const SizedBox(height: KfSpace.s3),
        Text(auth.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        Text(auth.email, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: KfColors.inkMuted)),
        const KfOverline('Informations'),
        KfGroup(dividerIndent: 64, children: [
          KfSettingRow(icon: LucideIcons.mail, title: 'Adresse email', subtitle: auth.email),
          KfSettingRow(icon: LucideIcons.shieldCheck, title: 'Profil', subtitle: auth.roleName),
          Obx(() => KfSettingRow(icon: LucideIcons.building2, title: 'Entreprise', subtitle: auth.companyName.value)),
        ]),
        const KfOverline('Sécurité'),
        KfGroup(dividerIndent: 64, children: [
          KfSettingRow(icon: LucideIcons.keyRound, title: 'Changer mon mot de passe', subtitle: 'Un lien vous est envoyé par email', onTap: changePassword),
          KfSettingRow(
            icon: LucideIcons.externalLink,
            title: 'Gérer mon compte sur le site',
            subtitle: 'Nom, utilisateurs et droits de l’entreprise',
            onTap: () => launchUrl(Uri.parse(AppConfig.siteUrl), mode: LaunchMode.externalApplication),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.all(KfSpace.s4),
          child: Text(
            'Votre nom et votre profil sont gérés par l’administrateur de votre entreprise, depuis le site Kin Factures.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: KfColors.inkMuted),
          ),
        ),
      ]),
    );
  }
}
