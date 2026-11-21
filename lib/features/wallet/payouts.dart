import '../../app/theme.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../invoices/invoice_rules.dart';

// Retraits Mobile Money : opérateurs et statuts (comme src/modules/wallet/payouts.js du site)
const payoutOperators = [
  ('mpesa', 'M-Pesa'),
  ('orange', 'Orange Money'),
  ('airtel', 'Airtel Money'),
  ('africell', 'Afrimoney'),
];

String operatorName(String? id) => payoutOperators.firstWhere((op) => op.$1 == id, orElse: () => (id ?? '', id ?? '—')).$2;

// processing : envoi Mobile Money automatique en cours ; failed : envoi refusé (montant remis sur le solde)
const _statusLabels = {
  'pending': ('En attente', BadgeTone.pending),
  'processing': ('En cours d’envoi', BadgeTone.pending),
  'paid': ('Payé', BadgeTone.paid),
  'rejected': ('Refusé', BadgeTone.overdue),
  'cancelled': ('Annulé', BadgeTone.neutral),
  'failed': ('Non envoyé', BadgeTone.overdue),
};

KfPill payoutPill(String? status) {
  final (label, tone) = _statusLabels[status] ?? (status ?? '—', BadgeTone.neutral);
  final (color, background) = switch (tone) {
    BadgeTone.paid => (KfColors.brand, KfColors.brandSoft),
    BadgeTone.pending => (KfColors.pending, KfColors.pendingSoft),
    BadgeTone.overdue => (KfColors.danger, KfColors.dangerSoft),
    BadgeTone.neutral => (KfColors.inkMuted, KfColors.surfaceSunken),
  };
  return KfPill(label, color: color, background: background, strike: status == 'cancelled');
}

// Retrait pas encore réglé : montant toujours « en cours » pour l'entreprise
bool isPayoutOpen(Json payout) => payout['status'] == 'pending' || payout['status'] == 'processing';

// Détail : référence et frais d'envoi, ou motif du refus / de l'échec
String? payoutDetail(Json payout) {
  final status = payout['status'];
  if (status == 'paid') {
    final fee = numOf(payout['fee']);
    return fee > 0 ? 'Réf. ${payout['reference']} · frais ${formatDecimal(fee)} ${payout['currency']}' : 'Réf. ${payout['reference']}';
  }
  if (status == 'rejected' || status == 'failed') return 'Motif : ${payout['reject_reason']}';
  return null;
}
