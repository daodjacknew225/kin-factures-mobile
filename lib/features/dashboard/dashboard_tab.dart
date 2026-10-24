import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../invoices/invoice_detail_page.dart';
import '../invoices/invoice_rules.dart';
import '../shell/shell_page.dart';

// Tableau de bord (mêmes calculs que DashboardPage.jsx du site) : encaissé ce mois, en attente,
// en retard (par devise), clients actifs, factures récentes, à relancer, derniers paiements en ligne.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

const _onlineMethods = ['paypal', 'flexpay', 'maishapay'];

class _Dashboard {
  _Dashboard(this.currency);
  final String currency;
  Map<String, double> paid = {}, pending = {}, overdue = {};
  int paidCount = 0, pendingCount = 0, overdueCount = 0, clientCount = 0, newClients = 0;
  List<Json> recent = [], late = [], lastPayments = [];
}

class _DashboardTabState extends State<DashboardTab> {
  _Dashboard? _data;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
    Get.find<ShellController>().onTabShown(0, _load);
  }

  List<Json> _list(Object? data) => (data as List).cast<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  Map<String, double> _sumByCurrency(Iterable<Json> rows, String field) {
    final totals = <String, double>{'USD': 0, 'CDF': 0};
    for (final row in rows) {
      final code = row['currency'] as String;
      totals[code] = (totals[code] ?? 0) + numOf(row[field]).toDouble();
    }
    return totals;
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.to.get('/settings'),
        Api.to.get('/invoices'),
        Api.to.get('/payments'),
        Api.to.get('/clients'),
      ]);
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month);
      bool thisMonth(Object? iso) {
        final date = iso is String ? DateTime.tryParse(iso)?.toLocal() : null;
        return date != null && !date.isBefore(monthStart);
      }

      final invoices = _list(results[1]).where((i) => i['direction'] != 'received').toList()
        ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
      final byId = {for (final i in invoices) i['id']: i};
      final payments = _list(results[2]).where((p) => byId.containsKey(p['invoice_id'])).toList();
      final clients = _list(results[3]).where((c) => c['is_archived'] != true).toList();

      final pending = invoices.where((i) => ['sent', 'partially_paid'].contains(i['display_status']));
      final overdue = invoices.where((i) => i['display_status'] == 'overdue').toList()
        ..sort((a, b) => (a['due_date'] as String).compareTo(b['due_date'] as String));

      final data = _Dashboard(((results[0] as Map)['default_currency'] as String?) ?? 'USD')
        ..paid = _sumByCurrency(payments.where((p) => thisMonth(p['paid_at'] ?? p['created_at'])), 'amount')
        ..paidCount = invoices.where((i) => i['status'] == 'paid' && thisMonth(i['paid_at'])).length
        ..pending = _sumByCurrency(pending, 'balance_due')
        ..pendingCount = pending.length
        ..overdue = _sumByCurrency(overdue, 'balance_due')
        ..overdueCount = overdue.length
        ..clientCount = clients.length
        ..newClients = clients.where((c) => thisMonth(c['created_at'])).length
        ..recent = invoices.take(5).toList()
        ..late = overdue.take(5).toList()
        ..lastPayments = payments
            .where((p) => _onlineMethods.contains(p['method']))
            .take(3)
            .map((p) => {...p, 'client_name': byId[p['invoice_id']]?['client_name']})
            .toList();
      if (mounted) {
        setState(() {
        _data = data;
        _error = '';
      });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = 'Impossible de charger le tableau de bord : ${error.message}');
    }
  }

  Future<void> _openInvoice(String id) async {
    final changed = await Get.to<bool>(() => InvoiceDetailPage(id: id));
    if (changed == true) _load();
  }

  int _daysSince(String isoDay) {
    final today = DateTime.now();
    return DateTime.utc(today.year, today.month, today.day).difference(DateTime.parse('${isoDay}T00:00:00Z')).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final firstName = Auth.to.firstName;
    return Scaffold(
      appBar: AppBar(title: Obx(() => Text(Auth.to.companyName.value.isEmpty ? 'Tableau de bord' : Auth.to.companyName.value))),
      body: data == null
          ? (_error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const KfLoader())
          : RefreshIndicator(
              color: KfColors.brand,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(KfSpace.s4), children: [
                Text(firstName.isEmpty ? 'Bonjour' : 'Bonjour $firstName', style: Theme.of(context).textTheme.headlineSmall),
                Text('Voici l’état de vos factures en ${currentMonthLabel()}.', style: Theme.of(context).textTheme.bodySmall),
                if (_error.isNotEmpty) ...[const SizedBox(height: KfSpace.s4), KfAlert(_error)],
                const SizedBox(height: KfSpace.s4),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: KfSpace.s2,
                  crossAxisSpacing: KfSpace.s2,
                  childAspectRatio: 1.3,
                  children: [
                    _StatCard(label: 'Encaissé ce mois', dot: KfColors.brand, amounts: data.paid, currency: data.currency,
                        note: plural(data.paidCount, 'facture payée', 'factures payées')),
                    _StatCard(label: 'En attente', dot: KfColors.pending, amounts: data.pending, currency: data.currency,
                        note: plural(data.pendingCount, 'facture', 'factures')),
                    _StatCard(label: 'En retard', dot: KfColors.danger, amounts: data.overdue, currency: data.currency,
                        note: plural(data.overdueCount, 'facture', 'factures')),
                    _StatCard(label: 'Clients actifs', dot: KfColors.inkMuted, value: '${data.clientCount}',
                        note: plural(data.newClients, 'nouveau ce mois', 'nouveaux ce mois')),
                  ],
                ),
                const SizedBox(height: KfSpace.s6),

                KfSectionTitle('À relancer', trailing: data.late.isEmpty ? null : Text('${data.overdueCount}', style: const TextStyle(color: KfColors.danger, fontWeight: FontWeight.w600))),
                Card(
                  child: data.late.isEmpty
                      ? const Padding(padding: EdgeInsets.all(KfSpace.s4), child: Text('Aucune facture en retard.', style: TextStyle(color: KfColors.inkMuted)))
                      : Column(children: [
                          for (var i = 0; i < data.late.length; i++) ...[
                            if (i > 0) const Divider(),
                            ListTile(
                              onTap: () => _openInvoice(data.late[i]['id'] as String),
                              title: Text(data.late[i]['client_name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                '${data.late[i]['number']} · en retard de ${plural(_daysSince(data.late[i]['due_date'] as String), 'jour')}',
                                style: const TextStyle(fontSize: 13, color: KfColors.danger),
                              ),
                              trailing: KfAmount(numOf(data.late[i]['balance_due']), data.late[i]['currency'] as String, size: AmountSize.sm),
                            ),
                          ],
                        ]),
                ),
                const SizedBox(height: KfSpace.s6),

                KfSectionTitle(
                  'Factures récentes',
                  trailing: TextButton(onPressed: () => Get.find<ShellController>().select(1), child: const Text('Voir tout')),
                ),
                Card(
                  child: data.recent.isEmpty
                      ? const Padding(padding: EdgeInsets.all(KfSpace.s4), child: Text('Aucune facture pour le moment.', style: TextStyle(color: KfColors.inkMuted)))
                      : Column(children: [
                          for (var i = 0; i < data.recent.length; i++) ...[
                            if (i > 0) const Divider(),
                            ListTile(
                              onTap: () => _openInvoice(data.recent[i]['id'] as String),
                              title: Text(data.recent[i]['client_name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(children: [statusBadge(data.recent[i]['display_status'] as String?)]),
                              ),
                              trailing: KfAmount(numOf(data.recent[i]['total']), data.recent[i]['currency'] as String, size: AmountSize.sm),
                            ),
                          ],
                        ]),
                ),
                const SizedBox(height: KfSpace.s6),

                const KfSectionTitle('Derniers paiements en ligne'),
                Card(
                  child: data.lastPayments.isEmpty
                      ? const Padding(padding: EdgeInsets.all(KfSpace.s4), child: Text('Aucun paiement pour le moment.', style: TextStyle(color: KfColors.inkMuted)))
                      : Column(children: [
                          for (var i = 0; i < data.lastPayments.length; i++) ...[
                            if (i > 0) const Divider(),
                            ListTile(
                              onTap: () => _openInvoice(data.lastPayments[i]['invoice_id'] as String),
                              title: Text(data.lastPayments[i]['client_name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                '${paymentMethodLabels[data.lastPayments[i]['method']] ?? ''} · ${formatDateTime((data.lastPayments[i]['paid_at'] ?? data.lastPayments[i]['created_at']) as String?)}',
                                style: const TextStyle(fontSize: 13, color: KfColors.inkMuted),
                              ),
                              trailing: KfAmount(numOf(data.lastPayments[i]['amount']), data.lastPayments[i]['currency'] as String,
                                  size: AmountSize.sm, color: KfColors.brand),
                            ),
                          ],
                        ]),
                ),
                const SizedBox(height: KfSpace.s6),
              ]),
            ),
    );
  }
}

// Carte d'indicateur (kf-stat du site) : montant dans la devise principale, autre devise en dessous
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.dot, this.amounts, this.currency, this.value, required this.note});
  final String label;
  final Color dot;
  final Map<String, double>? amounts;
  final String? currency;
  final String? value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final others = amounts?.entries.where((e) => e.key != currency && e.value != 0).toList() ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KfSpace.s3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: KfColors.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: amounts != null
                ? KfAmount(amounts![currency] ?? 0, currency!, size: AmountSize.lg)
                : Text(value ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
          ),
          for (final other in others) KfAmount(other.value, other.key, size: AmountSize.sm),
          const Spacer(),
          Text(note, style: const TextStyle(fontSize: 12, color: KfColors.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
