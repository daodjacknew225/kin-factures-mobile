import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/kit.dart';
import '../shell/quick_actions.dart';
import 'invoice_form_page.dart';
import 'invoice_rules.dart';
import 'payment_sheet.dart';

// Détail d'une facture (comme /factures/:id du site) : montants, lignes, paiements, et actions
// selon le statut et les droits. Retourne true à la page précédente si la facture a changé.
class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({super.key, required this.id});
  final String id;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Json? _data;
  String _error = '';
  bool _busy = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.to.get('/invoices/${widget.id}');
      if (mounted) {
        setState(() {
        _data = Map<String, dynamic>.from(data as Map);
        _error = '';
      });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = 'Impossible de charger la facture : ${error.message}');
    }
  }

  // Action sur la facture : sablier, message de succès ou d'erreur, rechargement
  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      _changed = true;
      await _load();
      if (message != null) showNotice(message);
    } on ApiException catch (error) {
      showNotice(error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Json get _invoice => Map<String, dynamic>.from(_data!['invoice'] as Map);
  String? get _clientEmail => (_data!['client'] as Map?)?['email'] as String? ?? _invoice['client_email'] as String?;

  Future<void> _sendEmail(String kind) async {
    final invoice = _invoice;
    final reminder = kind == 'reminder';
    final ok = await confirmAction(
      title: reminder ? 'Relancer le client' : 'Envoyer la facture par email',
      message: reminder
          ? 'Envoyer un rappel de paiement de ${formatAmount(numOf(invoice['balance_due']), invoice['currency'] as String)} à $_clientEmail ?'
          : 'Envoyer la facture ${invoice['number']} et son lien de paiement à $_clientEmail ?',
      confirmLabel: reminder ? 'Envoyer la relance' : 'Envoyer',
    );
    if (!ok) return;
    await _run(() async {
      final result = await Api.to.post('/invoices/${widget.id}/send', {'kind': kind}) as Map;
      return '${reminder ? 'Relance envoyée' : 'Email envoyé'} à ${result['recipient']}.';
    });
  }

  Future<void> _cancel() async {
    final invoice = _invoice;
    final ok = await confirmAction(
      title: 'Annuler la facture',
      message: 'La facture ${invoice['number']} sera annulée : le client ne pourra plus la payer. Cette action est irréversible.',
      confirmLabel: 'Annuler la facture',
      danger: true,
    );
    if (!ok) return;
    await _run(() async {
      await Api.to.post('/invoices/${widget.id}/cancel');
      return 'Facture annulée.';
    });
  }

  Future<void> _deleteDraft() async {
    final ok = await confirmAction(
      title: 'Supprimer le brouillon',
      message: 'Supprimer définitivement ce brouillon ? Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Api.to.delete('/invoices/${widget.id}');
      Get.back(result: true);
      showNotice('Brouillon supprimé.');
    } on ApiException catch (error) {
      showNotice(error.message, error: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordPayment() async {
    final saved = await showPaymentSheet(_invoice);
    if (saved == true) {
      await _run(() async => 'Paiement enregistré.');
    }
  }

  Future<void> _edit() async {
    final saved = await Get.to<String>(() => InvoiceFormPage(invoiceId: widget.id));
    if (saved != null) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final invoice = data == null ? null : _invoice;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Get.back(result: _changed);
      },
      child: Scaffold(
        backgroundColor: KfColors.surface,
        appBar: AppBar(
          backgroundColor: KfColors.surface,
          shape: const Border(),
          title: Text(invoice == null ? 'Facture' : (invoice['status'] == 'draft' ? 'Brouillon' : invoice['number'] as String? ?? 'Facture')),
          leading: BackButton(onPressed: () => Get.back(result: _changed)),
          actions: [if (invoice != null) ?_menu(invoice)],
        ),
        body: data == null
            ? (_error.isNotEmpty
                ? KfErrorView(_error, onRetry: _load)
                : const Padding(padding: EdgeInsets.all(KfSpace.s4), child: KfListSkeleton(rows: 5)))
            : RefreshIndicator(color: KfColors.brand, onRefresh: _load, child: _content(data, invoice!)),
      ),
    );
  }

  // Menu « … » : actions moins fréquentes
  Widget? _menu(Json invoice) {
    final items = <(String, IconData, VoidCallback, bool)>[];
    if (invoice['status'] == 'draft') {
      if (canManageDraft(invoice)) items.add(('Supprimer le brouillon', LucideIcons.trash2, _deleteDraft, true));
    } else {
      final emailed = (_data!['emails'] as List).cast<Map>().any((e) => e['kind'] == 'invoice' && e['status'] == 'sent');
      if (canEmail(invoice) && _clientEmail != null) {
        items.add((emailed ? 'Renvoyer la facture par email' : 'Envoyer la facture par email', LucideIcons.mail, () => _sendEmail('invoice'), false));
      }
      if (canCancel(invoice)) items.add(('Annuler la facture', LucideIcons.ban, _cancel, true));
    }
    if (items.isEmpty) return null;
    return PopupMenuButton<int>(
      tooltip: 'Autres actions',
      enabled: !_busy,
      icon: const Icon(LucideIcons.ellipsis),
      color: KfColors.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KfRadius.lg)),
      onSelected: (index) => items[index].$3(),
      itemBuilder: (_) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(children: [
              Icon(items[i].$2, size: 18, color: items[i].$4 ? KfColors.danger : KfColors.inkMuted),
              const SizedBox(width: KfSpace.s3),
              Text(items[i].$1, style: TextStyle(color: items[i].$4 ? KfColors.danger : KfColors.ink)),
            ]),
          ),
      ],
    );
  }

  Widget _content(Json data, Json invoice) {
    final currency = invoice['currency'] as String;
    final items = (data['items'] as List).cast<Map>();
    final payments = (data['payments'] as List).cast<Map>();
    final client = data['client'] as Map?;
    final open = isOpen(invoice);
    final draft = invoice['status'] == 'draft';
    final total = numOf(invoice['total']);
    final paid = numOf(invoice['amount_paid']);
    final overdue = invoice['display_status'] == 'overdue';
    final link = paymentLink(invoice);

    // Actions principales (boutons ronds), selon le statut et les droits
    final actions = <Widget>[
      if (draft && canManageDraft(invoice)) KfQuickAction(icon: LucideIcons.pencil, label: 'Modifier', onTap: _busy ? null : _edit),
      if (open && link != null) KfQuickAction(icon: LucideIcons.share2, label: 'Partager', onTap: _busy ? null : () => shareInvoiceLink(invoice)),
      if (canRecordPayment(invoice)) KfQuickAction(icon: LucideIcons.banknote, label: 'Encaisser', onTap: _busy ? null : _recordPayment),
      if (open && canEmail(invoice) && _clientEmail != null)
        KfQuickAction(icon: LucideIcons.bellRing, label: 'Relancer', onTap: _busy ? null : () => _sendEmail('reminder')),
      if (link != null && !draft)
        KfQuickAction(icon: LucideIcons.globe, label: 'Paiement', onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication)),
    ];

    return ListView(padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s2, KfSpace.s4, KfSpace.s8), children: [
      // Synthèse : client, statut, montant, avancement du paiement, dates
      Container(
        padding: const EdgeInsets.all(KfSpace.s4),
        decoration: BoxDecoration(
          color: KfColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KfColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            KfAvatar(invoice['client_name'] as String? ?? '?', size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(invoice['client_name'] as String? ?? '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (client?['email'] != null)
                  Text(client!['email'] as String,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: KfColors.inkMuted)),
              ]),
            ),
            statusPill(invoice['display_status'] as String?),
          ]),
          const SizedBox(height: KfSpace.s6),
          Text(open ? 'Reste à payer' : 'Montant total', style: TextStyle(fontSize: 13, color: KfColors.inkMuted)),
          const SizedBox(height: 2),
          KfAmount(open ? numOf(invoice['balance_due']) : total, currency, size: AmountSize.xl),
          if (!draft && total > 0 && paid > 0) ...[
            const SizedBox(height: KfSpace.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (paid / total).clamp(0, 1).toDouble(),
                minHeight: 8,
                backgroundColor: KfColors.surfaceSunken,
                color: KfColors.brand,
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Text('Payé ${shownAmount(paid, currency)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KfColors.brand)),
              ),
              Text('sur ${shownAmount(total, currency)}', style: TextStyle(fontSize: 12, color: KfColors.inkMuted)),
            ]),
          ],
          const SizedBox(height: KfSpace.s4),
          Divider(height: 1, color: KfColors.line),
          const SizedBox(height: KfSpace.s3),
          Row(children: [
            Expanded(child: _dateBlock('Émise le', formatDate(invoice['issue_date'] as String?))),
            Expanded(child: _dateBlock('Échéance', formatDate(invoice['due_date'] as String?), danger: overdue)),
          ]),
        ]),
      ),

      if (actions.isNotEmpty) ...[
        const SizedBox(height: KfSpace.s4),
        Row(children: [for (final action in actions) Expanded(child: action)]),
      ],

      if (invoice['schedule_id'] != null || data['source_schedule'] != null) ...[
        const SizedBox(height: KfSpace.s4),
        const KfAlert('Facture récurrente : la série se gère sur le site Kin Factures.', tone: AlertTone.pending),
      ],

      // Lignes et totaux
      const KfOverline('Détail'),
      KfGroup(dividerIndent: KfSpace.s4, children: [
        for (final item in items)
          KfRow(
            title: item['description'] as String,
            subtitle: '${formatDecimal(numOf(item['quantity']))} × ${formatAmount(numOf(item['unit_price']), currency)}'
                ' · TVA ${formatDecimal(numOf(item['tax_rate']))} %',
            trailing: KfAmount(numOf(item['line_subtotal']), currency, size: AmountSize.sm),
          ),
        Padding(
          padding: const EdgeInsets.all(KfSpace.s4),
          child: Column(children: [
            _totalRow('Sous-total', numOf(invoice['subtotal']), currency),
            _totalRow('TVA', numOf(invoice['tax_total']), currency),
            const SizedBox(height: KfSpace.s1),
            Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              KfAmount(total, currency, size: AmountSize.md),
            ]),
          ]),
        ),
      ]),

      // Paiements reçus
      if (payments.isNotEmpty) ...[
        const KfOverline('Paiements reçus'),
        KfGroup(children: [
          for (final payment in payments)
            KfRow(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: KfColors.brandSoft, shape: BoxShape.circle),
                child: Icon(LucideIcons.arrowDownLeft, size: 20, color: KfColors.brand),
              ),
              title: paymentMethodLabels[payment['method']] ?? '${payment['method']}',
              subtitle: formatDateTime(payment['paid_at'] as String? ?? payment['created_at'] as String?),
              trailing: KfAmount(numOf(payment['amount']), currency, size: AmountSize.sm, color: KfColors.brand),
            ),
        ]),
      ],

      if ((invoice['notes'] as String?)?.isNotEmpty == true) ...[
        const KfOverline('Notes'),
        KfGroup(children: [
          Padding(
            padding: const EdgeInsets.all(KfSpace.s4),
            child: Text(invoice['notes'] as String, style: TextStyle(fontSize: 14, color: KfColors.inkSoft)),
          ),
        ]),
      ],
    ]);
  }

  Widget _dateBlock(String label, String value, {bool danger = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: KfColors.inkMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: danger ? KfColors.danger : KfColors.ink)),
      ]);

  Widget _totalRow(String label, num value, String currency) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: KfColors.inkMuted))),
          KfAmount(value, currency, size: AmountSize.sm, color: KfColors.inkSoft),
        ]),
      );
}
