import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/kit.dart';
import '../invoices/invoice_detail_page.dart';
import '../invoices/invoice_form_page.dart';
import '../invoices/invoice_rules.dart';
import 'client_form_page.dart';

// Fiche d'un client : coordonnées (appel, email en un geste), ses factures et ce qu'il reste à
// payer, nouvelle facture, modification, archivage. Retourne true si quelque chose a changé.
class ClientDetailPage extends StatefulWidget {
  const ClientDetailPage({super.key, required this.id});
  final String id;

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  Json? _client;
  List<Json> _invoices = [];
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
      final results = await Future.wait([Api.to.get('/clients'), Api.to.get('/invoices')]);
      final client = (results[0] as List).cast<Map>().firstWhereOrNull((c) => c['id'] == widget.id);
      if (client == null) throw ApiException(404, 'Client introuvable.');
      final invoices = (results[1] as List)
          .cast<Map>()
          .map((i) => Map<String, dynamic>.from(i))
          .where((i) => i['client_id'] == widget.id && i['direction'] != 'received')
          .toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      if (mounted) {
        setState(() {
        _client = Map<String, dynamic>.from(client);
        _invoices = invoices;
        _error = '';
      });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = 'Impossible de charger le client : ${error.message}');
    }
  }

  // Modifier ou archiver : son créateur, ou « Modifier les clients des autres »
  bool get _canEdit => _client!['created_by'] == Auth.to.userId || Auth.to.can('clients.modifier_tout');

  Future<void> _edit() async {
    final saved = await Get.to<String>(() => ClientFormPage(client: _client));
    if (saved != null) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _newInvoice() async {
    final id = await Get.to<String>(() => InvoiceFormPage(clientId: widget.id));
    if (id == null) return;
    _changed = true;
    await _load();
    await Get.to<bool>(() => InvoiceDetailPage(id: id));
    await _load();
  }

  Future<void> _toggleArchive() async {
    final archived = _client!['is_archived'] == true;
    final ok = await confirmAction(
      title: archived ? 'Réactiver le client' : 'Archiver le client',
      message: archived
          ? '${_client!['name']} sera de nouveau proposé sur les nouvelles factures.'
          : '${_client!['name']} ne sera plus proposé sur les nouvelles factures. Ses factures sont conservées.',
      confirmLabel: archived ? 'Réactiver' : 'Archiver',
      danger: !archived,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Api.to.post('/clients/${widget.id}/archive', {'archived': !archived});
      _changed = true;
      await _load();
      showNotice(archived ? 'Client réactivé.' : 'Client archivé.');
    } on ApiException catch (error) {
      showNotice(error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
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
          title: const Text('Client'),
          leading: BackButton(onPressed: () => Get.back(result: _changed)),
          actions: [
            if (client != null && _canEdit)
              PopupMenuButton<String>(
                tooltip: 'Autres actions',
                enabled: !_busy,
                icon: const Icon(LucideIcons.ellipsis),
                color: KfColors.surfaceRaised,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KfRadius.lg)),
                onSelected: (value) => value == 'edit' ? _edit() : _toggleArchive(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(LucideIcons.pencil, size: 18, color: KfColors.inkMuted),
                      const SizedBox(width: KfSpace.s3),
                      const Text('Modifier la fiche'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(children: [
                      Icon(client['is_archived'] == true ? LucideIcons.archiveRestore : LucideIcons.archive,
                          size: 18, color: client['is_archived'] == true ? KfColors.inkMuted : KfColors.danger),
                      const SizedBox(width: KfSpace.s3),
                      Text(client['is_archived'] == true ? 'Réactiver le client' : 'Archiver le client',
                          style: TextStyle(color: client['is_archived'] == true ? KfColors.ink : KfColors.danger)),
                    ]),
                  ),
                ],
              ),
          ],
        ),
        body: client == null
            ? (_error.isNotEmpty
                ? KfErrorView(_error, onRetry: _load)
                : const Padding(padding: EdgeInsets.all(KfSpace.s4), child: KfListSkeleton(rows: 4)))
            : RefreshIndicator(color: KfColors.brand, onRefresh: _load, child: _content(client)),
      ),
    );
  }

  Widget _content(Json client) {
    final email = client['email'] as String?;
    final phone = client['phone'] as String?;
    final digits = phone?.replaceAll(RegExp(r'[^0-9]'), '');
    final open = _invoices.where(isOpen).toList();
    double due(String currency) =>
        open.where((i) => i['currency'] == currency).fold(0, (sum, i) => sum + numOf(i['balance_due']).toDouble());
    final archived = client['is_archived'] == true;
    final canInvoice = !archived && Auth.to.can('factures.creer');
    final address = [client['address'], client['city'], client['country']].whereType<String>().where((s) => s.isNotEmpty).join(', ');

    return ListView(padding: const EdgeInsets.fromLTRB(KfSpace.s4, 0, KfSpace.s4, KfSpace.s8), children: [
      // En-tête : initiales, nom, contact, actions
      Center(child: KfAvatar(client['name'] as String, size: 72)),
      const SizedBox(height: KfSpace.s3),
      Text(client['name'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      if (client['contact_name'] != null)
        Text(client['contact_name'] as String, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: KfColors.inkMuted)),
      if (archived) ...[
        const SizedBox(height: KfSpace.s2),
        Center(child: KfPill('Archivé', color: KfColors.inkMuted, background: KfColors.surfaceSunken)),
      ],
      const SizedBox(height: KfSpace.s4),
      Row(children: [
        Expanded(
          child: KfQuickAction(
            icon: LucideIcons.phone,
            label: 'Appeler',
            onTap: phone == null ? null : () => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', ''))),
          ),
        ),
        Expanded(
          child: KfQuickAction(
            icon: LucideIcons.messageCircle,
            label: 'WhatsApp',
            onTap: digits == null || digits.isEmpty ? null : () => launchUrl(Uri.parse('https://wa.me/$digits'), mode: LaunchMode.externalApplication),
          ),
        ),
        Expanded(
          child: KfQuickAction(
            icon: LucideIcons.mail,
            label: 'Email',
            onTap: email == null ? null : () => launchUrl(Uri(scheme: 'mailto', path: email)),
          ),
        ),
        Expanded(child: KfQuickAction(icon: LucideIcons.filePlus, label: 'Facture', onTap: canInvoice && !_busy ? _newInvoice : null)),
      ]),

      // Reste à payer
      if (open.isNotEmpty) ...[
        const SizedBox(height: KfSpace.s4),
        Container(
          padding: const EdgeInsets.all(KfSpace.s4),
          decoration: BoxDecoration(color: KfColors.pendingSoft, borderRadius: BorderRadius.circular(KfRadius.lg)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reste à payer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KfColors.pending)),
                for (final currency in ['USD', 'CDF'])
                  if (due(currency) > 0) KfAmount(due(currency), currency, size: AmountSize.lg, color: KfColors.pending),
              ]),
            ),
            Text(plural(open.length, 'facture ouverte', 'factures ouvertes'), style: TextStyle(fontSize: 13, color: KfColors.pending)),
          ]),
        ),
      ],

      // Coordonnées
      const KfOverline('Coordonnées'),
      KfGroup(dividerIndent: 64, children: [
        if (email != null) KfSettingRow(icon: LucideIcons.mail, title: 'Email', subtitle: email, onTap: () => launchUrl(Uri(scheme: 'mailto', path: email))),
        if (phone != null)
          KfSettingRow(icon: LucideIcons.phone, title: 'Téléphone', subtitle: phone, onTap: () => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')))),
        if (address.isNotEmpty) KfSettingRow(icon: LucideIcons.mapPin, title: 'Adresse', subtitle: address),
        if (client['rccm'] != null || client['nif'] != null)
          KfSettingRow(
            icon: LucideIcons.badgeCheck,
            title: 'Identifiants',
            subtitle: [if (client['rccm'] != null) 'RCCM ${client['rccm']}', if (client['nif'] != null) 'NIF ${client['nif']}'].join(' · '),
          ),
        if (client['notes'] != null) KfSettingRow(icon: LucideIcons.notebookPen, title: 'Notes', subtitle: client['notes'] as String),
        if (email == null && phone == null && address.isEmpty && client['rccm'] == null && client['nif'] == null && client['notes'] == null)
          KfSettingRow(
            icon: LucideIcons.info,
            title: 'Aucune coordonnée',
            subtitle: _canEdit ? 'Touchez pour compléter la fiche' : null,
            onTap: _canEdit ? _edit : null,
          ),
      ]),

      // Factures du client
      KfOverline('Factures (${_invoices.length})'),
      _invoices.isEmpty
          ? KfGroup(children: [
              KfEmptyState(
                icon: LucideIcons.receipt,
                title: 'Aucune facture',
                message: 'Les factures de ce client apparaîtront ici.',
                action: canInvoice ? 'Nouvelle facture' : null,
                onAction: _newInvoice,
              ),
            ])
          : KfGroup(dividerIndent: KfSpace.s4, children: [
              for (final invoice in _invoices)
                KfRow(
                  title: invoice['status'] == 'draft' ? 'Brouillon' : (invoice['number'] as String? ?? ''),
                  subtitle: formatDate(invoice['issue_date'] as String?),
                  trailing: KfAmount(numOf(invoice['total']), invoice['currency'] as String, size: AmountSize.sm),
                  trailingBottom: statusPill(invoice['display_status'] as String?),
                  onTap: () async {
                    final changed = await Get.to<bool>(() => InvoiceDetailPage(id: invoice['id'] as String));
                    if (changed == true) _load();
                  },
                ),
            ]),
    ]);
  }
}
