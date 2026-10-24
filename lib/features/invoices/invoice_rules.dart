import '../../app/config.dart';
import '../../core/auth.dart';
import '../../widgets/common.dart';

// Statuts, libellés et droits des factures : mêmes règles que le site
// (StatusBadge.jsx, invoices.js, InvoiceDetailPage.jsx). L'API applique les droits de son côté.

typedef Json = Map<String, dynamic>;

const statusLabels = {
  'draft': ('Brouillon', BadgeTone.neutral),
  'sent': ('En attente', BadgeTone.pending),
  'partially_paid': ('Partiellement payée', BadgeTone.pending),
  'paid': ('Payée', BadgeTone.paid),
  'overdue': ('En retard', BadgeTone.overdue),
  'cancelled': ('Annulée', BadgeTone.neutral),
};

KfBadge statusBadge(String? status) {
  final (label, tone) = statusLabels[status] ?? statusLabels['draft']!;
  return KfBadge(label, tone: tone, strike: status == 'cancelled');
}

// Onglets de la liste (display_status)
class InvoiceTab {
  const InvoiceTab(this.id, this.label, this.match);
  final String id;
  final String label;
  final bool Function(String status) match;
}

final invoiceTabs = [
  InvoiceTab('all', 'Toutes', (_) => true),
  InvoiceTab('draft', 'Brouillons', (s) => s == 'draft'),
  InvoiceTab('pending', 'En attente', (s) => s == 'sent' || s == 'partially_paid'),
  InvoiceTab('overdue', 'En retard', (s) => s == 'overdue'),
  InvoiceTab('paid', 'Payées', (s) => s == 'paid'),
];

const paymentMethodLabels = {
  'paypal': 'PayPal',
  'flexpay': 'FlexPay',
  'maishapay': 'Carte bancaire (MaishaPay)',
  'cash': 'Espèces',
  'bank_transfer': 'Virement bancaire',
};

num numOf(Object? value) => value is num ? value : num.tryParse('$value') ?? 0;

// Facture encore à régler (émise, pas encore payée ni annulée)
bool isOpen(Json invoice) => ['sent', 'partially_paid'].contains(invoice['status']);

// Lien de la page de paiement publique ; null pour un brouillon
String? paymentLink(Json invoice) {
  final token = invoice['payment_token'];
  if (token == null || invoice['status'] == 'draft') return null;
  return AppConfig.paymentUrl(token as String);
}

bool _isCreator(Json invoice) => invoice['created_by'] == Auth.to.userId;

// Brouillon modifiable / supprimable : son créateur, ou « Modifier les factures des autres »
bool canManageDraft(Json invoice) =>
    invoice['status'] == 'draft' &&
    ((_isCreator(invoice) && Auth.to.can('factures.creer')) || Auth.to.can('factures.modifier_tout'));

// Envoi ou relance par email : créateur, ou « Modifier les factures des autres »
bool canEmail(Json invoice) =>
    !['draft', 'cancelled'].contains(invoice['status']) && (_isCreator(invoice) || Auth.to.can('factures.modifier_tout'));

bool canCancel(Json invoice) => Auth.to.can('factures.annuler') && isOpen(invoice);

bool canRecordPayment(Json invoice) =>
    Auth.to.can('paiements.saisir') && isOpen(invoice) && numOf(invoice['balance_due']) > 0;

// « 2026-10-24 » + 30 jours → « 2026-11-23 »
String addDays(String isoDay, int days) {
  final date = DateTime.parse(isoDay).add(Duration(days: days));
  return isoDayOf(date);
}

String isoDayOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

int daysBetween(String from, String to) => DateTime.parse(to).difference(DateTime.parse(from)).inDays;

double round2(num value) => (value * 100).roundToDouble() / 100;
