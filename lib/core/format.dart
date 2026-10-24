import 'package:intl/intl.dart';

// Formatage des montants et des dates, comme src/lib/format.js du site

final _amount = NumberFormat.decimalPatternDigits(locale: 'fr_FR', decimalDigits: 2);

// 18450 → « 18 450,00 »
String formatNumber(num? value) => _amount.format(value ?? 0);

// 18450, 'USD' → « 18 450,00 USD »
String formatAmount(num? value, String currency) => '${formatNumber(value)} $currency';

DateTime? _parse(String? iso) => iso == null || iso.isEmpty ? null : DateTime.tryParse(iso)?.toLocal();

// « 2026-10-25 » → « 25/10/2026 »
String formatDate(String? iso) {
  final date = _parse(iso);
  return date == null ? '' : DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
}

// « 2026-10-25 » → « 25 octobre 2026 »
String formatDateLong(String? iso) {
  final date = _parse(iso);
  return date == null ? '' : DateFormat('d MMMM yyyy', 'fr_FR').format(date);
}

// « 2026-10-11T11:42:00Z » → « 11/10/2026 à 12:42 » (heure locale)
String formatDateTime(String? iso) {
  final date = _parse(iso);
  return date == null ? '' : DateFormat("dd/MM/yyyy 'à' HH:mm", 'fr_FR').format(date);
}

// Mois en cours : « octobre 2026 »
String currentMonthLabel([DateTime? now]) => DateFormat('MMMM yyyy', 'fr_FR').format(now ?? DateTime.now());

// 2 → « 2 factures », 1 → « 1 facture »
String plural(int count, String singular, [String? pluralForm]) =>
    '$count ${count > 1 ? (pluralForm ?? '${singular}s') : singular}';

// Montant saisi « 1 250,50 » → 1250.5 (null si invalide)
double? parseAmount(String text) => double.tryParse(text.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.'));
