import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import 'invoice_rules.dart';

// Paiement reçu hors ligne (espèces, virement) : POST /invoices/:id/payments (droit « paiements.saisir »).
// Le statut de la facture (partiellement payée, payée) est recalculé par l'API.
Future<bool?> showPaymentSheet(Json invoice) => Get.bottomSheet<bool>(
      _PaymentSheet(invoice: invoice),
      isScrollControlled: true,
      backgroundColor: KfColors.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(KfRadius.lg))),
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
    return Padding(
      padding: EdgeInsets.zero, // le clavier est déjà pris en compte par la fenêtre
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KfSpace.s6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text('Enregistrer un paiement', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: KfSpace.s1),
            Text(
              'Facture ${widget.invoice['number']} · reste à payer ${formatAmount(numOf(widget.invoice['balance_due']), currency)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: KfSpace.s6),
            TextField(
              controller: _amount,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Montant reçu', suffixText: currency),
            ),
            const SizedBox(height: KfSpace.s4),
            const Text('Moyen de paiement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: KfSpace.s2),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Espèces')),
                ButtonSegment(value: 'bank_transfer', label: Text('Virement')),
              ],
              selected: {_method},
              showSelectedIcon: false,
              onSelectionChanged: _saving ? null : (value) => setState(() => _method = value.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: KfColors.brandSoft,
                selectedForegroundColor: KfColors.brand,
                side: BorderSide(color: KfColors.line),
              ),
            ),
            const SizedBox(height: KfSpace.s4),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('Reçu le ${formatDateLong(isoDayOf(_date))}'),
            ),
            const SizedBox(height: KfSpace.s4),
            if (_error.isNotEmpty) ...[KfAlert(_error), const SizedBox(height: KfSpace.s4)],
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Enregistrement…' : 'Enregistrer le paiement'),
            ),
          ]),
        ),
      ),
    );
  }
}
