import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../core/privacy.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../invoices/invoice_detail_page.dart';
import '../invoices/invoice_rules.dart';
import '../shell/quick_actions.dart';
import '../shell/shell_page.dart';

// Accueil (mêmes calculs que DashboardPage.jsx du site) : bandeau vert avec l'encaissé du mois et
// les actions rapides, puis en attente / en retard, factures à relancer, activité récente.
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
  int paidCount = 0, pendingCount = 0, overdueCount = 0;
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
    return Scaffold(
      backgroundColor: KfColors.surface,
      body: RefreshIndicator(
        color: KfColors.brand,
        onRefresh: _load,
        edgeOffset: MediaQuery.of(context).padding.top,
        child: ListView(padding: EdgeInsets.zero, children: [
          // Le bandeau et les tuiles suivent « Masquer les montants »
          Obx(() {
            Privacy.to.hidden.value;
            return _Hero(data: data);
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s4, KfSpace.s4, KfSpace.s8),
            child: data == null
                ? (_error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const _BodySkeleton())
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_error.isNotEmpty) ...[KfAlert(_error), const SizedBox(height: KfSpace.s3)],
                    Obx(() => Row(key: ValueKey(Privacy.to.hidden.value), children: [
                      Expanded(child: _Tile(label: 'En attente', dot: KfColors.pending, amounts: data.pending, currency: data.currency, count: data.pendingCount)),
                      const SizedBox(width: KfSpace.s3),
                      Expanded(child: _Tile(label: 'En retard', dot: KfColors.danger, amounts: data.overdue, currency: data.currency, count: data.overdueCount, alert: data.overdueCount > 0)),
                    ])),

                    KfOverline('À relancer', action: data.overdueCount > 0 ? 'Tout voir' : null, onAction: () => Get.find<ShellController>().select(1)),
                    data.late.isEmpty
                        ? const _AllGood()
                        : KfGroup(children: [
                            for (final invoice in data.late)
                              KfRow(
                                leading: KfAvatar(invoice['client_name'] as String? ?? '?'),
                                title: invoice['client_name'] as String? ?? '—',
                                subtitle: '${invoice['number']} · en retard de ${plural(_daysSince(invoice['due_date'] as String), 'jour')}',
                                subtitleColor: KfColors.danger,
                                trailing: KfAmount(numOf(invoice['balance_due']), invoice['currency'] as String, size: AmountSize.sm),
                                onTap: () => _openInvoice(invoice['id'] as String),
                              ),
                          ]),

                    KfOverline('Factures récentes', action: 'Tout voir', onAction: () => Get.find<ShellController>().select(1)),
                    data.recent.isEmpty
                        ? KfGroup(children: [
                            KfEmptyState(
                              icon: LucideIcons.receipt,
                              title: 'Aucune facture pour le moment',
                              message: 'Créez votre première facture : votre client la reçoit avec un lien de paiement.',
                              action: Auth.to.can('factures.creer') ? 'Nouvelle facture' : null,
                              onAction: quickNewInvoice,
                            ),
                          ])
                        : KfGroup(children: [
                            for (final invoice in data.recent)
                              KfRow(
                                leading: KfAvatar(invoice['client_name'] as String? ?? '?'),
                                title: invoice['client_name'] as String? ?? '—',
                                subtitle: invoice['status'] == 'draft'
                                    ? 'Créée le ${formatDate(invoice['created_at'] as String?)}'
                                    : '${invoice['number']} · ${formatDate(invoice['issue_date'] as String?)}',
                                trailing: KfAmount(numOf(invoice['total']), invoice['currency'] as String, size: AmountSize.sm),
                                trailingBottom: statusPill(invoice['display_status'] as String?),
                                onTap: () => _openInvoice(invoice['id'] as String),
                              ),
                          ]),

                    if (data.lastPayments.isNotEmpty) ...[
                      const KfOverline('Paiements en ligne'),
                      KfGroup(children: [
                        for (final payment in data.lastPayments)
                          KfRow(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: KfColors.brandSoft, shape: BoxShape.circle),
                              child: Icon(LucideIcons.arrowDownLeft, size: 20, color: KfColors.brand),
                            ),
                            title: payment['client_name'] as String? ?? '—',
                            subtitle:
                                '${paymentMethodLabels[payment['method']] ?? ''} · ${formatDateTime((payment['paid_at'] ?? payment['created_at']) as String?)}',
                            trailing: KfAmount(numOf(payment['amount']), payment['currency'] as String, size: AmountSize.sm, color: KfColors.brand),
                            onTap: () => _openInvoice(payment['invoice_id'] as String),
                          ),
                      ]),
                    ],
                  ]),
          ),
        ]),
      ),
    );
  }
}

// Bandeau vert : entreprise, compte, encaissé du mois, actions rapides
class _Hero extends StatelessWidget {
  const _Hero({required this.data});
  final _Dashboard? data;

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    final others = data?.paid.entries.where((e) => e.key != data.currency && e.value != 0).toList() ?? const [];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KfColors.heroStart, KfColors.heroEnd],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(KfSpace.s6, MediaQuery.of(context).padding.top + KfSpace.s4, KfSpace.s6, KfSpace.s6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    Auth.to.companyName.value.isEmpty ? 'Kin Factures' : Auth.to.companyName.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: KfColors.onHero),
                  ),
                  Text(
                    Auth.to.firstName.isEmpty ? 'Bonjour' : 'Bonjour ${Auth.to.firstName}',
                    style: TextStyle(fontSize: 13, color: KfColors.onHero.withValues(alpha: 0.75)),
                  ),
                ])),
          ),
          GestureDetector(
            onTap: () => Get.find<ShellController>().select(3),
            child: KfAvatar(Auth.to.name, size: 42, inverted: true),
          ),
        ]),
        const SizedBox(height: KfSpace.s6),
        Row(children: [
          Text('Encaissé en ${currentMonthLabel()}', style: TextStyle(fontSize: 13, color: KfColors.onHero.withValues(alpha: 0.75))),
          const SizedBox(width: KfSpace.s1),
          // Œil : masquer / afficher les montants
          InkResponse(
            onTap: Privacy.to.toggle,
            radius: 20,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Privacy.to.hidden.value ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 16, color: KfColors.onHero.withValues(alpha: 0.75), semanticLabel: 'Masquer ou afficher les montants'),
            ),
          ),
        ]),
        const SizedBox(height: KfSpace.s1),
        if (data == null)
          KfSkeleton(child: KfBone(width: 180, height: 36, radius: 8, color: KfColors.onHero.withValues(alpha: 0.18)))
        else
          Text.rich(
            TextSpan(children: [
              TextSpan(text: Privacy.to.hidden.value ? '•••••' : formatNumber(data.paid[data.currency] ?? 0)),
              TextSpan(text: ' ${data.currency}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: KfColors.onHero.withValues(alpha: 0.7))),
            ]),
            style: const TextStyle(fontSize: 36, height: 44 / 36, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: KfColors.onHero,
                fontFeatures: [FontFeature.tabularFigures()]),
          ),
        for (final other in others)
          Text(shownAmount(other.value, other.key), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: KfColors.onHero.withValues(alpha: 0.85))),
        if (data != null)
          Text('${plural(data.paidCount, 'facture soldée', 'factures soldées')} ce mois',
              style: TextStyle(fontSize: 13, color: KfColors.onHero.withValues(alpha: 0.75))),
        const SizedBox(height: KfSpace.s6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: KfQuickAction(
              icon: LucideIcons.filePlus,
              label: 'Facture',
              inverted: true,
              onTap: Auth.to.can('factures.creer') ? quickNewInvoice : null,
            ),
          ),
          Expanded(
            child: KfQuickAction(
              icon: LucideIcons.banknote,
              label: 'Encaisser',
              inverted: true,
              onTap: Auth.to.can('paiements.saisir') ? quickRecordPayment : null,
            ),
          ),
          const Expanded(child: KfQuickAction(icon: LucideIcons.userPlus, label: 'Client', inverted: true, onTap: quickNewClient)),
          const Expanded(child: KfQuickAction(icon: LucideIcons.share2, label: 'Partager', inverted: true, onTap: quickShareLink)),
        ]),
      ]),
    );
  }
}

// Petite carte : en attente / en retard
class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.dot, required this.amounts, required this.currency, required this.count, this.alert = false});
  final String label;
  final Color dot;
  final Map<String, double> amounts;
  final String currency;
  final int count;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final others = amounts.entries.where((e) => e.key != currency && e.value != 0).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alert ? KfColors.dangerSoft : KfColors.surfaceRaised,
        borderRadius: BorderRadius.circular(KfRadius.lg),
        border: Border.all(color: alert ? KfColors.dangerSoft : KfColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: KfColors.inkSoft)),
        ]),
        const SizedBox(height: KfSpace.s2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: Privacy.to.hidden.value ? '•••••' : formatNumber(amounts[currency] ?? 0)),
              TextSpan(text: ' $currency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KfColors.inkMuted)),
            ]),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: alert ? KfColors.danger : KfColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        for (final other in others)
          Text(shownAmount(other.value, other.key), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KfColors.inkSoft)),
        const SizedBox(height: 2),
        Text(plural(count, 'facture'), style: TextStyle(fontSize: 12, color: KfColors.inkMuted)),
      ]),
    );
  }
}

class _AllGood extends StatelessWidget {
  const _AllGood();

  @override
  Widget build(BuildContext context) => KfGroup(children: [
        KfRow(
          leading: CircleAvatar(radius: 20, backgroundColor: KfColors.brandSoft, child: Icon(LucideIcons.circleCheck, size: 20, color: KfColors.brand)),
          title: 'Aucune facture en retard',
          subtitle: 'Vos clients sont à jour de leurs paiements.',
        ),
      ]);
}

class _BodySkeleton extends StatelessWidget {
  const _BodySkeleton();

  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KfSkeleton(
          child: Row(children: [
            Expanded(child: KfBone(height: 92, radius: 12)),
            SizedBox(width: KfSpace.s3),
            Expanded(child: KfBone(height: 92, radius: 12)),
          ]),
        ),
        SizedBox(height: KfSpace.s6),
        KfListSkeleton(rows: 4),
      ]);
}
