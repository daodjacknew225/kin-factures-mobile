import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import 'invoice_rules.dart';

// Paiement reçu hors ligne (espèces, virement) : POST /invoices/:id/payments (droit « paiements.saisir »).
// Le statut de la facture (partiellement payée, payée) est recalculé par l'API.
Future<bool?> showPaymentSheet(Json invoice) => Get.bottomSheet<bool>(
      _PaymentSheet(invoice: invoice),
      isScrollControlled: true,
      backgroundColor: KfColors.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    );

class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({required this.invoice});
  final Json invoice;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final _amount = TextEditingController(text: formatNumber(numOf(widget.invoice['balance_due'])));
  String _method = 'cash';
  DateTime _date = DateTime.now();
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.parse(widget.invoice['issue_date'] as String),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final currency = widget.invoice['currency'] as String;
    final balance = numOf(widget.invoice['balance_due']);
    final amount = parseAmount(_amount.text);
    if (amount == null || amount <= 0) return setState(() => _error = 'Saisissez un montant supérieur à zéro.');
    if (amount > balance) {
      return setState(() => _error = 'Le montant dépasse le reste à payer (${formatAmount(balance, currency)}).');
    }
    final today = isoDayOf(DateTime.now()) == isoDayOf(_date);
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await Api.to.post('/invoices/${widget.invoice['id']}/payments', {
        'amount': amount,
        'method': _method,
        // Aujourd'hui : l'heure du serveur ; autre jour : midi de ce jour
        if (!today) 'paid_at': '${isoDayOf(_date)}T12:00:00.000Z',
      });
      Get.back(result: true);
    } on ApiException catch (error) {
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.invoice['currency'] as String;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(KfRadius.lg), borderSide: BorderSide(color: color, width: width));
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(KfSpace.s6, KfSpace.s3, KfSpace.s6, KfSpace.s6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          const KfSheetHandle(),
          const SizedBox(height: KfSpace.s4),
          const Text('Encaisser un paiement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            '${widget.invoice['client_name'] ?? ''} · ${widget.invoice['number']} · reste ${formatAmount(numOf(widget.invoice['balance_due']), currency)}',
            style: TextStyle(fontSize: 13, color: KfColors.inkMuted),
          ),
          const SizedBox(height: KfSpace.s6),
          Text('Montant reçu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KfColors.inkSoft)),
          const SizedBox(height: 6),
          TextField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              suffixText: currency,
              filled: true,
              fillColor: KfColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: border(KfColors.line),
              enabledBorder: border(KfColors.line),
              focusedBorder: border(KfColors.brand, 1.5),
            ),
          ),
          const SizedBox(height: KfSpace.s4),
          Text('Moyen de paiement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KfColors.inkSoft)),
          const SizedBox(height: 6),
          KfSegmented(
            options: const [('cash', 'Espèces'), ('bank_transfer', 'Virement')],
            selected: _method,
            enabled: !_saving,
            onChanged: (value) => setState(() => _method = value),
          ),
          const SizedBox(height: KfSpace.s4),
          Text('Reçu le', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KfColors.inkSoft)),
          const SizedBox(height: 6),
          InkWell(
            onTap: _saving ? null : _pickDate,
            borderRadius: BorderRadius.circular(KfRadius.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: KfColors.surface,
                borderRadius: BorderRadius.circular(KfRadius.lg),
                border: Border.all(color: KfColors.line),
              ),
              child: Row(children: [
                Icon(LucideIcons.calendar, size: 18, color: KfColors.inkMuted),
                const SizedBox(width: 10),
                Expanded(child: Text(formatDateLong(isoDayOf(_date)), style: const TextStyle(fontSize: 15))),
                Icon(LucideIcons.chevronDown, size: 18, color: KfColors.inkMuted),
              ]),
            ),
          ),
          const SizedBox(height: KfSpace.s6),
          if (_error.isNotEmpty) ...[KfAlert(_error), const SizedBox(height: KfSpace.s4)],
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: Text(_saving ? 'Enregistrement…' : 'Enregistrer le paiement', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
