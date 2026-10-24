import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config.dart';
import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/biometric_login.dart';
import '../../widgets/dialogs.dart';
import '../products/products_page.dart';

// Onglet « Plus » : compte connecté, autres écrans (produits, solde), liens du site, déconnexion
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Auth.to;
    final text = Theme.of(context).textTheme;
    final initials = auth.name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Plus')),
      body: ListView(
        padding: const EdgeInsets.all(KfSpace.s4),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(KfSpace.s4),
              child: Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: KfColors.brandSoft,
                  child: Text(initials.isEmpty ? '?' : initials,
                      style: const TextStyle(color: KfColors.brand, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: KfSpace.s4),
                Expanded(
                  child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(auth.name, style: text.titleMedium),
                        Text(auth.email, style: text.bodySmall),
                        const SizedBox(height: 2),
                        Text('${auth.roleName} · ${auth.companyName.value}', style: text.bodySmall),
                      ])),
                ),
              ]),
            ),
          ),
          const SizedBox(height: KfSpace.s4),
          _Group(children: [
            _Item(icon: Icons.inventory_2_outlined, label: 'Produits et services', onTap: () => Get.to(() => const ProductsPage())),
            if (auth.can('retraits.demander'))
              _Item(icon: Icons.account_balance_wallet_outlined, label: 'Solde et retraits', subtitle: 'Arrive à l’étape 5', onTap: null),
          ]),
          const SizedBox(height: KfSpace.s4),
          _Group(children: [
            _Item(
              icon: Icons.open_in_new,
              label: 'Ouvrir le site Kin Factures',
              subtitle: 'Paramètres, utilisateurs, factures récurrentes…',
              onTap: () => launchUrl(Uri.parse(AppConfig.siteUrl), mode: LaunchMode.externalApplication),
            ),
            _Item(icon: Icons.description_outlined, label: 'Conditions d’utilisation', onTap: () => launchUrl(Uri.parse(AppConfig.termsUrl))),
            _Item(icon: Icons.privacy_tip_outlined, label: 'Confidentialité', onTap: () => launchUrl(Uri.parse(AppConfig.privacyUrl))),
          ]),
          const SizedBox(height: KfSpace.s4),
          const _Group(children: [_BiometricSwitch()]),
          const SizedBox(height: KfSpace.s4),
          _Group(children: [
            _Item(icon: Icons.logout, label: 'Se déconnecter', danger: true, onTap: auth.signOut),
          ]),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 56), children[i]],
        ]),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, this.subtitle, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? KfColors.danger : KfColors.ink;
    return ListTile(
      leading: Icon(icon, color: danger ? KfColors.danger : KfColors.inkMuted),
      title: Text(label, style: TextStyle(color: onTap == null ? KfColors.inkMuted : color, fontWeight: FontWeight.w500)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 12, color: KfColors.inkMuted)),
      trailing: onTap == null || danger ? null : const Icon(Icons.chevron_right, color: KfColors.inkMuted),
      onTap: onTap,
    );
  }
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
  Widget build(BuildContext context) => SwitchListTile(
        value: _enabled,
        onChanged: _available != true || _busy ? null : _toggle,
        activeThumbColor: KfColors.brand,
        secondary: const Icon(Icons.fingerprint, color: KfColors.inkMuted),
        title: const Text('Connexion par empreinte', style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          _available == false ? 'Aucune empreinte enregistrée sur ce téléphone' : 'Se connecter sans saisir le mot de passe',
          style: const TextStyle(fontSize: 12, color: KfColors.inkMuted),
        ),
      );
}
