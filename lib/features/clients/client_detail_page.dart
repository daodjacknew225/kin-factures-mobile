import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
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
        appBar: AppBar(
          title: Text(client?['name'] as String? ?? 'Client'),
          leading: BackButton(onPressed: () => Get.back(result: _changed)),
          actions: [
            if (client != null && _canEdit)
              PopupMenuButton<String>(
                tooltip: 'Autres actions',
                enabled: !_busy,
                color: KfColors.surfaceRaised,
                onSelected: (value) => value == 'edit' ? _edit() : _toggleArchive(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Modifier la fiche')),
                  PopupMenuItem(value: 'archive', child: Text(client['is_archived'] == true ? 'Réactiver le client' : 'Archiver le client')),
                ],
              ),
          ],
        ),
        body: client == null
            ? (_error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const KfLoader())
            : RefreshIndicator(color: KfColors.brand, onRefresh: _load, child: _content(client)),
        bottomNavigationBar: client == null || client['is_archived'] == true || !Auth.to.can('factures.creer')
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, KfSpace.s3),
                  decoration: BoxDecoration(color: KfColors.surfaceRaised, border: Border(top: BorderSide(color: KfColors.line))),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _newInvoice,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nouvelle facture'),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _content(Json client) {
    final email = client['email'] as String?;
    final phone = client['phone'] as String?;
    final open = _invoices.where(isOpen).toList();
    double due(String currency) =>
        open.where((i) => i['currency'] == currency).fold(0, (sum, i) => sum + numOf(i['balance_due']).toDouble());

    return ListView(padding: const EdgeInsets.all(KfSpace.s4), children: [
      if (client['is_archived'] == true) ...[
        const KfAlert('Client archivé : il n’est plus proposé sur les nouvelles factures.', tone: AlertTone.pending),
        const SizedBox(height: KfSpace.s4),
      ],
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          if (client['contact_name'] != null) _info(Icons.person_outline, client['contact_name'] as String),
          if (email != null)
            _info(Icons.mail_outline, email, onTap: () => launchUrl(Uri(scheme: 'mailto', path: email))),
          if (phone != null)
            _info(Icons.phone_outlined, phone, onTap: () => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')))),
          if (client['address'] != null || client['city'] != null)
            _info(Icons.place_outlined,
                [client['address'], client['city'], client['country']].whereType<String>().where((s) => s.isNotEmpty).join(', ')),
          if (client['rccm'] != null || client['nif'] != null)
            _info(Icons.badge_outlined,
                [if (client['rccm'] != null) 'RCCM ${client['rccm']}', if (client['nif'] != null) 'NIF ${client['nif']}'].join(' · ')),
          if (client['notes'] != null) _info(Icons.notes, client['notes'] as String),
          if ([client['contact_name'], email, phone, client['address'], client['city'], client['rccm'], client['nif'], client['notes']]
              .every((v) => v == null))
            _info(Icons.info_outline, 'Aucune coordonnée : modifiez la fiche pour en ajouter.'),
        ]),
      ),
      const SizedBox(height: KfSpace.s4),
      if (open.isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(KfSpace.s4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reste à payer · ${plural(open.length, 'facture ouverte', 'factures ouvertes')}',
                  style: TextStyle(fontSize: 13, color: KfColors.inkMuted)),
              const SizedBox(height: KfSpace.s1),
              for (final currency in ['USD', 'CDF'])
                if (due(currency) > 0) KfAmount(due(currency), currency, size: AmountSize.lg, color: KfColors.pending),
            ]),
          ),
        ),
      if (open.isNotEmpty) const SizedBox(height: KfSpace.s4),
      KfSectionTitle('Factures', trailing: Text('${_invoices.length}', style: TextStyle(color: KfColors.inkMuted))),
      Card(
        child: _invoices.isEmpty
            ? Padding(padding: EdgeInsets.all(KfSpace.s4), child: Text('Aucune facture pour ce client.', style: TextStyle(color: KfColors.inkMuted)))
            : Column(children: [
                for (var i = 0; i < _invoices.length; i++) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    onTap: () async {
                      final changed = await Get.to<bool>(() => InvoiceDetailPage(id: _invoices[i]['id'] as String));
                      if (changed == true) _load();
                    },
                    title: Text(
                      _invoices[i]['status'] == 'draft' ? 'Brouillon' : (_invoices[i]['number'] as String? ?? ''),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        statusBadge(_invoices[i]['display_status'] as String?),
                        const SizedBox(width: KfSpace.s2),
                        Text(formatDate(_invoices[i]['issue_date'] as String?), style: TextStyle(fontSize: 12, color: KfColors.inkMuted)),
                      ]),
                    ),
                    trailing: KfAmount(numOf(_invoices[i]['total']), _invoices[i]['currency'] as String, size: AmountSize.sm),
                  ),
                ],
              ]),
      ),
      const SizedBox(height: KfSpace.s6),
    ]);
  }

  Widget _info(IconData icon, String text, {VoidCallback? onTap}) => ListTile(
        onTap: onTap,
        leading: Icon(icon, color: KfColors.inkMuted),
        title: Text(text, style: TextStyle(color: onTap == null ? KfColors.ink : KfColors.brand)),
        dense: true,
      );
}
