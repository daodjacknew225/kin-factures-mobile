import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../shell/shell_page.dart';
import 'invoice_detail_page.dart';
import 'invoice_form_page.dart';
import 'invoice_rules.dart';

// Onglet Factures : factures émises par l'entreprise, recherche (numéro, client) et filtres par statut
// (comme la page /factures du site). Tirer vers le bas pour actualiser.
class InvoicesTab extends StatefulWidget {
  const InvoicesTab({super.key});

  @override
  State<InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<InvoicesTab> {
  List<Json>? _invoices;
  String _error = '';
  String _search = '';
  String _tab = 'all';

  @override
  void initState() {
    super.initState();
    _load();
    Get.find<ShellController>().onTabShown(1, _load);
  }

  Future<void> _load() async {
    try {
      final data = await Api.to.get('/invoices') as List;
      final list = data.cast<Map>().map((i) => Map<String, dynamic>.from(i)).where((i) => i['direction'] != 'received').toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      if (mounted) {
        setState(() {
        _invoices = list;
        _error = '';
      });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = 'Impossible de charger les factures : ${error.message}');
    }
  }

  Future<void> _openDetail(String id) async {
    final changed = await Get.to<bool>(() => InvoiceDetailPage(id: id));
    if (changed == true) _load();
  }

  // Nouvelle facture : une fois enregistrée, on ouvre son détail
  Future<void> _create() async {
    final id = await Get.to<String>(() => const InvoiceFormPage());
    if (id == null) return;
    _load();
    await _openDetail(id);
  }

  String _normalize(String text) => text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final invoices = _invoices;
    final query = _normalize(_search);
    final searched = (invoices ?? const <Json>[])
        .where((i) => query.isEmpty || _normalize('${i['number'] ?? ''} ${i['client_name'] ?? ''}').contains(query))
        .toList();
    final tab = invoiceTabs.firstWhere((t) => t.id == _tab);
    final rows = searched.where((i) => tab.match(i['display_status'] as String)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Factures')),
      floatingActionButton: Auth.to.can('factures.creer')
          ? FloatingActionButton.extended(
              onPressed: _create,
              backgroundColor: KfColors.brand,
              foregroundColor: KfColors.onBrand,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle facture'),
            )
          : null,
      body: _error.isNotEmpty && invoices == null
          ? KfErrorView(_error, onRetry: _load)
          : invoices == null
              ? const KfLoader()
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s4, KfSpace.s4, KfSpace.s2),
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'Numéro ou client…',
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4),
                      children: [
                        for (final t in invoiceTabs)
                          Padding(
                            padding: const EdgeInsets.only(right: KfSpace.s2),
                            child: ChoiceChip(
                              label: Text('${t.label} ${searched.where((i) => t.match(i['display_status'] as String)).length}'),
                              selected: _tab == t.id,
                              onSelected: (_) => setState(() => _tab = t.id),
                              selectedColor: KfColors.brandSoft,
                              backgroundColor: KfColors.surfaceRaised,
                              side: BorderSide(color: _tab == t.id ? KfColors.brand : KfColors.line),
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _tab == t.id ? KfColors.brand : KfColors.inkMuted,
                              ),
                              showCheckmark: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_error.isNotEmpty)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4), child: KfAlert(_error)),
                  Expanded(
                    child: RefreshIndicator(
                      color: KfColors.brand,
                      onRefresh: _load,
                      child: rows.isEmpty
                          ? ListView(children: [
                              const SizedBox(height: 80),
                              KfEmpty(
                                invoices.isEmpty
                                    ? 'Aucune facture pour le moment.'
                                    : query.isNotEmpty
                                        ? 'Aucune facture ne correspond à cette recherche.'
                                        : 'Aucune facture dans cet onglet.',
                                icon: Icons.receipt_long_outlined,
                              ),
                            ])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s2, KfSpace.s4, 96),
                              itemCount: rows.length,
                              separatorBuilder: (_, _) => const SizedBox(height: KfSpace.s2),
                              itemBuilder: (_, index) => _InvoiceCard(
                                invoice: rows[index],
                                onTap: () => _openDetail(rows[index]['id'] as String),
                              ),
                            ),
                    ),
                  ),
                ]),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onTap});
  final Json invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = invoice['display_status'] as String;
    final draft = invoice['status'] == 'draft';
    final open = isOpen(invoice);
    final late = status == 'overdue';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KfSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  invoice['client_name'] as String? ?? '—',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: KfSpace.s2),
              KfAmount(numOf(invoice['total']), invoice['currency'] as String, size: AmountSize.md),
            ]),
            const SizedBox(height: KfSpace.s1),
            Row(children: [
              Expanded(
                child: Text(
                  [
                    if (!draft) invoice['number'] as String? ?? '', // brouillon : pas encore de numéro (voir le badge)
                    if (invoice['schedule_id'] != null) 'Récurrente',
                    'échéance ${formatDate(invoice['due_date'] as String?)}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 13, color: late ? KfColors.danger : KfColors.inkMuted),
                ),
              ),
              statusBadge(status),
            ]),
            if (open && numOf(invoice['amount_paid']) > 0) ...[
              const SizedBox(height: KfSpace.s1),
              Text(
                'Reste à payer : ${formatAmount(numOf(invoice['balance_due']), invoice['currency'] as String)}',
                style: const TextStyle(fontSize: 13, color: KfColors.pending, fontWeight: FontWeight.w500),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
