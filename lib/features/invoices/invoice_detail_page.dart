import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
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

  Future<void> _share() async {
    final invoice = _invoice;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Get.back(result: _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_data == null
              ? 'Facture'
              : _invoice['status'] == 'draft'
                  ? 'Brouillon'
                  : _invoice['number'] as String? ?? 'Facture'),
          leading: BackButton(onPressed: () => Get.back(result: _changed)),
        ),
        body: _data == null
            ? (_error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const KfLoader())
            : RefreshIndicator(color: KfColors.brand, onRefresh: _load, child: _content()),
        bottomNavigationBar: _data == null ? null : _actions(),
      ),
    );
  }

  Widget _content() {
    final data = _data!;
    final invoice = _invoice;
    final currency = invoice['currency'] as String;
    final items = (data['items'] as List).cast<Map>();
    final payments = (data['payments'] as List).cast<Map>();
    final client = data['client'] as Map?;
    final text = Theme.of(context).textTheme;
    final open = isOpen(invoice);

    return ListView(padding: const EdgeInsets.all(KfSpace.s4), children: [
      // En-tête : client, statut, montant
      Card(
        child: Padding(
          padding: const EdgeInsets.all(KfSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(invoice['client_name'] as String? ?? '—', style: text.titleMedium?.copyWith(fontSize: 17))),
              statusBadge(invoice['display_status'] as String?),
            ]),
            if (client?['email'] != null) Text(client!['email'] as String, style: text.bodySmall),
            const SizedBox(height: KfSpace.s4),
            KfAmount(numOf(invoice['total']), currency, size: AmountSize.xl),
            const SizedBox(height: KfSpace.s2),
            _infoRow('Émise le', formatDate(invoice['issue_date'] as String?)),
            _infoRow('Échéance', formatDate(invoice['due_date'] as String?),
                danger: invoice['display_status'] == 'overdue'),
            if (numOf(invoice['amount_paid']) > 0) _infoRow('Déjà payé', formatAmount(numOf(invoice['amount_paid']), currency)),
            if (open) _infoRow('Reste à payer', formatAmount(numOf(invoice['balance_due']), currency), strong: true),
            if (invoice['schedule_id'] != null || data['source_schedule'] != null)
              Padding(
                padding: const EdgeInsets.only(top: KfSpace.s2),
                child: KfAlert(
                  'Facture récurrente : la série se gère sur le site Kin Factures.',
                  tone: AlertTone.pending,
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: KfSpace.s4),

      // Lignes et totaux
      const KfSectionTitle('Détail'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(KfSpace.s4),
          child: Column(children: [
            for (final item in items) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['description'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      '${formatDecimal(numOf(item['quantity']))} × ${formatAmount(numOf(item['unit_price']), currency)}'
                      ' · TVA ${formatDecimal(numOf(item['tax_rate']))} %',
                      style: text.bodySmall,
                    ),
                  ]),
                ),
                KfAmount(numOf(item['line_subtotal']), currency, size: AmountSize.sm),
              ]),
              const Divider(height: KfSpace.s6),
            ],
            _infoRow('Sous-total', formatAmount(numOf(invoice['subtotal']), currency)),
            _infoRow('TVA', formatAmount(numOf(invoice['tax_total']), currency)),
            _infoRow('Total', formatAmount(numOf(invoice['total']), currency), strong: true),
          ]),
        ),
      ),

      // Paiements reçus
      if (payments.isNotEmpty) ...[
        const SizedBox(height: KfSpace.s4),
        const KfSectionTitle('Paiements reçus'),
        Card(
          child: Column(children: [
            for (var i = 0; i < payments.length; i++) ...[
              if (i > 0) const Divider(),
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: KfColors.brand),
                title: Text(paymentMethodLabels[payments[i]['method']] ?? '${payments[i]['method']}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(formatDateTime(payments[i]['paid_at'] as String? ?? payments[i]['created_at'] as String?),
                    style: text.bodySmall),
                trailing: KfAmount(numOf(payments[i]['amount']), currency, size: AmountSize.sm, color: KfColors.brand),
              ),
            ],
          ]),
        ),
      ],

      if ((invoice['notes'] as String?)?.isNotEmpty == true) ...[
        const SizedBox(height: KfSpace.s4),
        const KfSectionTitle('Notes'),
        Card(child: Padding(padding: const EdgeInsets.all(KfSpace.s4), child: Text(invoice['notes'] as String))),
      ],

      // Lien de paiement
      if (paymentLink(invoice) != null && open) ...[
        const SizedBox(height: KfSpace.s4),
        OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse(paymentLink(invoice)!), mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Voir la page de paiement'),
        ),
      ],
      const SizedBox(height: KfSpace.s6),
    ]);
  }

  Widget _infoRow(String label, String value, {bool strong = false, bool danger = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: KfColors.inkMuted))),
          Text(value,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                color: danger ? KfColors.danger : KfColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ]),
      );

  // Barre d'actions en bas, selon le statut et les droits
  Widget? _actions() {
    final invoice = _invoice;
    final buttons = <Widget>[];
    final more = <(String, IconData, VoidCallback, bool)>[];

    if (invoice['status'] == 'draft') {
      if (!canManageDraft(invoice)) return null;
      buttons.add(FilledButton(onPressed: _busy ? null : _edit, child: const Text('Modifier le brouillon')));
      more.add(('Supprimer le brouillon', Icons.delete_outline, _deleteDraft, true));
    } else {
      final open = isOpen(invoice);
      if (open && paymentLink(invoice) != null) {
        buttons.add(FilledButton.icon(
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.share_outlined, size: 18),
          label: const Text('Partager'),
        ));
      }
      if (canRecordPayment(invoice)) {
        buttons.add(OutlinedButton(onPressed: _busy ? null : _recordPayment, child: const Text('Encaisser')));
      }
      if (canEmail(invoice) && _clientEmail != null) {
        final emailed = (_data!['emails'] as List).cast<Map>().any((e) => e['kind'] == 'invoice' && e['status'] == 'sent');
        if (open) more.add(('Relancer par email', Icons.notifications_active_outlined, () => _sendEmail('reminder'), false));
        more.add((emailed ? 'Renvoyer la facture par email' : 'Envoyer la facture par email', Icons.mail_outline,
            () => _sendEmail('invoice'), false));
      }
      if (canCancel(invoice)) more.add(('Annuler la facture', Icons.block, _cancel, true));
    }
    if (buttons.isEmpty && more.isEmpty) return null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, KfSpace.s3),
        decoration: BoxDecoration(
          color: KfColors.surfaceRaised,
          border: Border(top: BorderSide(color: KfColors.line)),
        ),
        child: Row(children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: KfSpace.s2),
            Expanded(child: buttons[i]),
          ],
          if (more.isNotEmpty) ...[
            if (buttons.isNotEmpty) const SizedBox(width: KfSpace.s2),
            SizedBox(
              height: 48,
              width: buttons.isEmpty ? null : 48,
              child: PopupMenuButton<int>(
                tooltip: 'Autres actions',
                enabled: !_busy,
                color: KfColors.surfaceRaised,
                onSelected: (index) => more[index].$3(),
                itemBuilder: (_) => [
                  for (var i = 0; i < more.length; i++)
                    PopupMenuItem(
                      value: i,
                      child: Row(children: [
                        Icon(more[i].$2, size: 20, color: more[i].$4 ? KfColors.danger : KfColors.inkMuted),
                        const SizedBox(width: KfSpace.s3),
                        Text(more[i].$1, style: TextStyle(color: more[i].$4 ? KfColors.danger : KfColors.ink)),
                      ]),
                    ),
                ],
                child: Container(
                  alignment: Alignment.center,
                  padding: buttons.isEmpty ? const EdgeInsets.symmetric(horizontal: KfSpace.s4) : null,
                  decoration: BoxDecoration(
                    border: Border.all(color: KfColors.line),
                    borderRadius: BorderRadius.circular(KfRadius.md),
                  ),
                  child: buttons.isEmpty
                      ? const Text('Actions', style: TextStyle(fontWeight: FontWeight.w500))
                      : const Icon(Icons.more_horiz),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
