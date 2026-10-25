import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/kit.dart';
import '../clients/client_detail_page.dart';
import '../clients/client_form_page.dart';
import '../invoices/invoice_detail_page.dart';
import '../invoices/invoice_form_page.dart';
import '../invoices/invoice_rules.dart';
import '../invoices/payment_sheet.dart';
import 'shell_page.dart';

// Actions rapides (bandeau de l'accueil, bouton « + » du menu) : nouvelle facture, nouveau client,
// encaisser un paiement, partager un lien de paiement. Après une action, les onglets se rechargent.

void _changed() => Get.find<ShellController>().changed();

Future<void> quickNewInvoice() async {
  final id = await Get.to<String>(() => const InvoiceFormPage());
  if (id == null) return;
  _changed();
  await Get.to<bool>(() => InvoiceDetailPage(id: id));
  _changed();
}

Future<void> quickNewClient() async {
  final id = await Get.to<String>(() => const ClientFormPage());
  if (id == null) return;
  _changed();
  await Get.to<bool>(() => ClientDetailPage(id: id));
  _changed();
}

Future<void> quickRecordPayment() async {
  final invoice = await _pickOpenInvoice('Encaisser un paiement', 'Quelle facture le client a-t-il réglée ?');
  if (invoice == null) return;
  if (await showPaymentSheet(invoice) == true) {
    showNotice('Paiement enregistré sur la facture ${invoice['number']}.');
    _changed();
  }
}

Future<void> quickShareLink() async {
  final invoice = await _pickOpenInvoice('Partager un lien de paiement', 'Quelle facture envoyer au client ?');
  if (invoice != null) await shareInvoiceLink(invoice);
}

// Message prêt à envoyer (WhatsApp, SMS…) avec le lien de la page de paiement
Future<void> shareInvoiceLink(Json invoice) async {
  final link = paymentLink(invoice);
  if (link == null) return;
  final company = Auth.to.companyName.value;
  final amount = formatAmount(numOf(invoice['balance_due']), invoice['currency'] as String);
  await SharePlus.instance.share(ShareParams(
    subject: 'Facture ${invoice['number']}',
    text: 'Bonjour, voici la facture ${invoice['number']}${company.isEmpty ? '' : ' de $company'} : '
        '$amount à régler. Payez en ligne ici : $link',
  ));
}

// Menu du bouton « + »
Future<void> showCreateMenu() => Get.bottomSheet<void>(
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, KfSpace.s4),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: KfColors.line, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: KfSpace.s4),
            const Padding(
              padding: EdgeInsets.only(left: KfSpace.s1, bottom: KfSpace.s3),
              child: Text('Que voulez-vous faire ?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            KfGroup(dividerIndent: 64, children: [
              if (Auth.to.can('factures.creer'))
                _MenuRow(icon: LucideIcons.filePlus, title: 'Nouvelle facture', subtitle: 'Créer, émettre et envoyer', onTap: quickNewInvoice),
              _MenuRow(icon: LucideIcons.userPlus, title: 'Nouveau client', subtitle: 'Ajouter une fiche client', onTap: quickNewClient),
              if (Auth.to.can('paiements.saisir'))
                _MenuRow(icon: LucideIcons.banknote, title: 'Encaisser un paiement', subtitle: 'Espèces ou virement reçu', onTap: quickRecordPayment),
              _MenuRow(icon: LucideIcons.share2, title: 'Partager un lien de paiement', subtitle: 'Par WhatsApp, SMS…', onTap: quickShareLink),
            ]),
          ]),
        ),
      ),
      backgroundColor: KfColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    );

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) => KfRow(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: KfColors.brandSoft, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: KfColors.brand),
        ),
        title: title,
        subtitle: subtitle,
        trailing: Icon(LucideIcons.chevronRight, size: 18, color: KfColors.inkMuted),
        onTap: () {
          Get.back();
          onTap();
        },
      );
}

// Choix d'une facture encore à régler (les plus anciennes échéances d'abord)
Future<Json?> _pickOpenInvoice(String title, String hint) async {
  List<Json> invoices;
  try {
    invoices = (await Api.to.get('/invoices') as List)
        .cast<Map>()
        .map((i) => Map<String, dynamic>.from(i))
        .where((i) => i['direction'] != 'received' && isOpen(i) && numOf(i['balance_due']) > 0)
        .toList()
      ..sort((a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String));
  } on ApiException catch (error) {
    showNotice(error.message, error: true);
    return null;
  }
  return Get.bottomSheet<Json>(
    SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: Get.height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(KfSpace.s6, KfSpace.s6, KfSpace.s6, KfSpace.s1),
            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(KfSpace.s6, 0, KfSpace.s6, KfSpace.s3),
            child: Text(hint, style: TextStyle(fontSize: 13, color: KfColors.inkMuted)),
          ),
          Flexible(
            child: invoices.isEmpty
                ? const KfEmptyState(icon: LucideIcons.circleCheck, title: 'Rien à encaisser', message: 'Toutes vos factures émises sont réglées.')
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(KfSpace.s4, 0, KfSpace.s4, KfSpace.s4),
                    child: KfGroup(children: [
                      for (final invoice in invoices)
                        KfRow(
                          leading: KfAvatar(invoice['client_name'] as String? ?? '?'),
                          title: invoice['client_name'] as String? ?? '—',
                          subtitle: '${invoice['number']} · éch. ${formatDate(invoice['due_date'] as String?)}',
                          subtitleColor: invoice['display_status'] == 'overdue' ? KfColors.danger : null,
                          trailing: KfAmount(numOf(invoice['balance_due']), invoice['currency'] as String, size: AmountSize.sm),
                          onTap: () => Get.back(result: invoice),
                        ),
                    ]),
                  ),
          ),
        ]),
      ),
    ),
    isScrollControlled: true,
    backgroundColor: KfColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
  );
}
