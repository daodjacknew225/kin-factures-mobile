import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../shell/quick_actions.dart';
import '../shell/shell_page.dart';
import 'invoice_detail_page.dart';
import 'invoice_rules.dart';

// Onglet Factures : factures émises par l'entreprise, reste à encaisser, recherche (numéro, client)
// et filtres par statut (comme la page /factures du site). Tirer vers le bas pour actualiser.
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

    // Reste à encaisser (factures émises non soldées), par devise
    final due = <String, double>{};
    for (final invoice in (invoices ?? const <Json>[]).where(isOpen)) {
      final code = invoice['currency'] as String;
      due[code] = (due[code] ?? 0) + numOf(invoice['balance_due']).toDouble();
    }
    final dueText = due.entries.where((e) => e.value > 0).map((e) => formatAmount(e.value, e.key)).join(' · ');

    return Scaffold(
      backgroundColor: KfColors.surface,
      body: RefreshIndicator(
        color: KfColors.brand,
        onRefresh: _load,
        edgeOffset: MediaQuery.of(context).padding.top,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: KfPageHeader(
              title: 'Factures',
              subtitle: invoices == null
                  ? null
                  : Text(
                      dueText.isEmpty ? 'Tout est encaissé' : 'À encaisser : $dueText',
                      style: TextStyle(fontSize: 14, color: KfColors.inkMuted),
                    ),
            ),
          ),
          SliverToBoxAdapter(child: KfSearchField(hint: 'Rechercher un numéro ou un client', onChanged: (v) => setState(() => _search = v))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: KfSpace.s3, bottom: KfSpace.s3),
              child: KfFilterPills(
                options: [
                  for (final t in invoiceTabs) (t.id, t.label, invoices == null ? null : searched.where((i) => t.match(i['display_status'] as String)).length),
                ],
                selected: _tab,
                onSelected: (id) => setState(() => _tab = id),
              ),
            ),
          ),
          if (_error.isNotEmpty && invoices != null)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(KfSpace.s4, 0, KfSpace.s4, KfSpace.s3), child: KfAlert(_error))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(KfSpace.s4, 0, KfSpace.s4, KfSpace.s8),
            sliver: SliverToBoxAdapter(
              child: invoices == null
                  ? (_error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const KfListSkeleton(rows: 7))
                  : rows.isEmpty
                      ? KfGroup(children: [
                          KfEmptyState(
                            icon: LucideIcons.receipt,
                            title: invoices.isEmpty
                                ? 'Aucune facture pour le moment'
                                : query.isNotEmpty
                                    ? 'Aucun résultat'
                                    : 'Rien dans cet onglet',
                            message: invoices.isEmpty
                                ? 'Créez votre première facture : votre client la reçoit avec un lien de paiement.'
                                : query.isNotEmpty
                                    ? 'Aucune facture ne correspond à « ${_search.trim()} ».'
                                    : null,
                            action: invoices.isEmpty && Auth.to.can('factures.creer') ? 'Nouvelle facture' : null,
                            onAction: quickNewInvoice,
                          ),
                        ])
                      : KfGroup(children: [
                          for (final invoice in rows) _InvoiceRow(invoice: invoice, onTap: () => _openDetail(invoice['id'] as String)),
                        ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice, required this.onTap});
  final Json invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = invoice['display_status'] as String;
    final draft = invoice['status'] == 'draft';
    final partial = isOpen(invoice) && numOf(invoice['amount_paid']) > 0;
    final parts = [
      if (!draft) invoice['number'] as String? ?? '', // brouillon : la pastille le dit
      if (partial)
        'reste ${formatAmount(numOf(invoice['balance_due']), invoice['currency'] as String)}'
      else
        'éch. ${formatDate(invoice['due_date'] as String?)}',
      if (invoice['schedule_id'] != null) 'récurrente',
    ];
    return KfRow(
      leading: KfAvatar(invoice['client_name'] as String? ?? '?'),
      title: invoice['client_name'] as String? ?? '—',
      subtitle: parts.join(' · '),
      subtitleColor: status == 'overdue' ? KfColors.danger : (partial ? KfColors.pending : null),
      trailing: KfAmount(numOf(invoice['total']), invoice['currency'] as String, size: AmountSize.sm),
      trailingBottom: statusPill(status),
      onTap: onTap,
    );
  }
}
