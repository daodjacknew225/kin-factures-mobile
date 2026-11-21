import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/kit.dart';
import '../invoices/invoice_rules.dart';
import 'payout_form_page.dart';
import 'payouts.dart';

// Solde et retraits (comme /solde du site) : les paiements en ligne des clients sont encaissés par
// Kin Factures puis crédités ici (montant net reçu) ; l'entreprise demande un retrait vers son
// compte Mobile Money (envoyé automatiquement sous le plafond de la plateforme). Droit
// « retraits.demander ». Tirer vers le bas pour actualiser.
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Json? _data;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = Map<String, dynamic>.from(await Api.to.get('/wallet') as Map);
      if (mounted) {
        setState(() {
          _data = data;
          _error = '';
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = 'Impossible de charger le solde : ${error.message}');
    }
  }

  List<Json> _list(String key) => ((_data?[key] as List?) ?? const []).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  num _balance(String currency) => numOf((_data?['balances'] as Map?)?[currency]);
  num _minimum(String currency) => numOf((_data?['minimums'] as Map?)?[currency]);

  Future<void> _request() async {
    final data = _data;
    if (data == null) return;
    final payout = await Get.to<Json>(() => PayoutFormPage(
          balances: {'USD': _balance('USD'), 'CDF': _balance('CDF')},
          minimums: {'USD': _minimum('USD'), 'CDF': _minimum('CDF')},
        ));
    if (payout != null) _load();
  }

  Future<void> _cancel(Json payout) async {
    final amount = formatAmount(numOf(payout['amount']), payout['currency'] as String);
    final ok = await confirmAction(
      title: 'Annuler la demande de retrait',
      message: 'La demande de $amount sera annulée et le montant remis sur votre solde.',
      confirmLabel: 'Annuler la demande',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.to.post('/wallet/payouts/${payout['id']}/cancel');
      showNotice('Demande de retrait annulée : le montant est de nouveau disponible.');
      _load();
    } on ApiException catch (error) {
      showNotice(error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final payouts = _list('payouts');
    final entries = _list('entries');
    final open = payouts.where(isPayoutOpen).toList();
    num openTotal(String currency) => open.where((p) => p['currency'] == currency).fold<num>(0, (sum, p) => sum + numOf(p['amount']));
    final showCdf = _balance('CDF') > 0 || openTotal('CDF') > 0;

    return Scaffold(
      backgroundColor: KfColors.surface,
      appBar: AppBar(
        backgroundColor: KfColors.surface,
        shape: const Border(),
        title: const Text('Solde et retraits'),
        actions: [
          if (data != null)
            IconButton(tooltip: 'Demander un retrait', onPressed: _request, icon: Icon(LucideIcons.plus, color: KfColors.brand)),
        ],
      ),
      body: RefreshIndicator(
        color: KfColors.brand,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s2, KfSpace.s4, KfSpace.s8), children: [
          if (data == null)
            _error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const KfListSkeleton(rows: 6)
          else ...[
            _BalanceCard(
              usd: _balance('USD'),
              cdf: showCdf ? _balance('CDF') : null,
              minimum: formatAmount(_minimum('USD'), 'USD'),
            ),
            const SizedBox(height: KfSpace.s3),
            KfCard(
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: KfColors.pendingSoft, borderRadius: BorderRadius.circular(10)),
                  child: Icon(LucideIcons.clock, size: 18, color: KfColors.pending),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Retraits en cours', style: TextStyle(fontSize: 13, color: KfColors.inkMuted)),
                    const SizedBox(height: 2),
                    Text(
                      open.isEmpty ? 'Aucune demande en cours' : '${open.length} demande${open.length > 1 ? 's' : ''} en cours de traitement',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: KfColors.ink),
                    ),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  KfAmount(openTotal('USD'), 'USD', size: AmountSize.sm),
                  if (showCdf) KfAmount(openTotal('CDF'), 'CDF', size: AmountSize.sm),
                ]),
              ]),
            ),
            const SizedBox(height: KfSpace.s4),
            FilledButton.icon(
              onPressed: _request,
              icon: const Icon(LucideIcons.arrowUpRight, size: 18),
              label: const Text('Demander un retrait'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            if (_error.isNotEmpty) ...[const SizedBox(height: KfSpace.s3), KfAlert(_error)],
            KfOverline('Demandes de retrait'),
            payouts.isEmpty
                ? KfGroup(children: [
                    const KfEmptyState(icon: LucideIcons.arrowUpRight, title: 'Aucune demande de retrait pour le moment'),
                  ])
                : KfGroup(children: [
                    for (final payout in payouts)
                      KfRow(
                        leading: _RoundIcon(icon: LucideIcons.smartphone, color: KfColors.inkSoft, background: KfColors.surfaceSunken),
                        title: '${operatorName(payout['operator'] as String?)} · ${payout['phone']}',
                        subtitle: [
                          formatDateTime(payout['requested_at'] as String?),
                          ?payoutDetail(payout),
                          if (payout['status'] == 'pending') 'toucher pour annuler',
                        ].join(' · '),
                        subtitleColor: payout['status'] == 'failed' || payout['status'] == 'rejected' ? KfColors.danger : null,
                        trailing: KfAmount(numOf(payout['amount']), payout['currency'] as String, size: AmountSize.sm),
                        trailingBottom: payoutPill(payout['status'] as String?),
                        onTap: payout['status'] == 'pending' ? () => _cancel(payout) : null,
                      ),
                  ]),
            KfOverline('Mouvements du solde'),
            entries.isEmpty
                ? KfGroup(children: [
                    const KfEmptyState(
                      icon: LucideIcons.wallet,
                      title: 'Aucun mouvement',
                      message: 'Votre solde sera crédité dès le premier paiement en ligne d’un client.',
                    ),
                  ])
                : KfGroup(children: [
                    for (final entry in entries)
                      KfRow(
                        leading: numOf(entry['amount']) < 0
                            ? _RoundIcon(icon: LucideIcons.arrowUpRight, color: KfColors.inkSoft, background: KfColors.surfaceSunken)
                            : _RoundIcon(icon: LucideIcons.arrowDownLeft, color: KfColors.brand, background: KfColors.brandSoft),
                        title: entry['description'] as String? ?? '—',
                        subtitle: formatDateTime(entry['created_at'] as String?),
                        trailing: KfAmount(
                          numOf(entry['amount']),
                          entry['currency'] as String,
                          size: AmountSize.sm,
                          color: numOf(entry['amount']) < 0 ? KfColors.ink : KfColors.brand,
                        ),
                      ),
                  ]),
          ],
        ]),
      ),
    );
  }
}

// Solde disponible, sur le bandeau vert de l'application
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.usd, required this.cdf, required this.minimum});
  final num usd;
  final num? cdf;
  final String minimum;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(KfSpace.s6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [KfColors.heroStart, KfColors.heroEnd]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Solde disponible', style: TextStyle(fontSize: 13, color: KfColors.onHero.withValues(alpha: 0.75))),
          const SizedBox(height: KfSpace.s2),
          KfAmount(usd, 'USD', size: AmountSize.xl, color: KfColors.onHero),
          if (cdf != null) ...[const SizedBox(height: 2), KfAmount(cdf, 'CDF', size: AmountSize.md, color: KfColors.onHero)],
          const SizedBox(height: KfSpace.s3),
          Text('Retrait minimum : $minimum', style: TextStyle(fontSize: 12, color: KfColors.onHero.withValues(alpha: 0.75))),
        ]),
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, required this.background});
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color),
      );
}
