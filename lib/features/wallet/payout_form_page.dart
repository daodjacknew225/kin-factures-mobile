import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/kit.dart';
import '../invoices/invoice_rules.dart';
import 'payouts.dart';

// Demande de retrait vers un compte Mobile Money (POST /wallet/payouts) : le montant est mis de
// côté tout de suite ; sous le plafond de la plateforme il part automatiquement. Retourne la
// demande enregistrée.
class PayoutFormPage extends StatefulWidget {
  const PayoutFormPage({super.key, required this.balances, required this.minimums});
  final Map<String, num> balances;
  final Map<String, num> minimums;

  @override
  State<PayoutFormPage> createState() => _PayoutFormPageState();
}

class _PayoutFormPageState extends State<PayoutFormPage> {
  final _amount = TextEditingController();
  final _phone = TextEditingController(text: '+243');
  final _holder = TextEditingController();
  late String _currency = (widget.balances['USD'] ?? 0) > 0 || (widget.balances['CDF'] ?? 0) <= 0 ? 'USD' : 'CDF';
  String _operator = 'mpesa';
  Map<String, String> _errors = {};
  String _formError = '';
  bool _saving = false;

  num get _available => widget.balances[_currency] ?? 0;
  num get _minimum => widget.minimums[_currency] ?? 0;

  @override
  void dispose() {
    for (final c in [_amount, _phone, _holder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final amount = parseAmount(_amount.text);
    final phone = _phone.text.replaceAll(RegExp(r'[\s.()-]'), '');
    final errors = <String, String>{
      if (amount == null || amount <= 0)
        'amount': 'Saisissez un montant supérieur à zéro.'
      else if (amount < _minimum)
        'amount': 'Le minimum d’un retrait est de ${formatAmount(_minimum, _currency)}.'
      else if (amount > _available)
        'amount': 'Solde insuffisant : ${formatAmount(_available, _currency)} disponibles.',
      if (!RegExp(r'^\+\d{8,15}$').hasMatch(phone)) 'phone': 'Numéro au format international, ex. +243810000000.',
      if (_holder.text.trim().length < 2) 'holder_name': 'Indiquez le nom du titulaire du compte.',
    };
    setState(() {
      _errors = errors;
      _formError = '';
    });
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      final saved = Map<String, dynamic>.from(await Api.to.post('/wallet/payouts', {
        'currency': _currency,
        'amount': amount,
        'operator': _operator,
        'phone': phone,
        'holder_name': _holder.text.trim(),
      }) as Map);
      Get.back(result: saved);
      final text = formatAmount(numOf(saved['amount']), saved['currency'] as String);
      showNotice(switch (saved['status']) {
        'paid' => 'Retrait de $text envoyé sur votre compte Mobile Money.',
        'processing' => 'Retrait de $text en cours d’envoi : vous serez prévenu par email.',
        'failed' => 'Retrait de $text non envoyé : le montant est remis sur votre solde.',
        _ => 'Demande de retrait de $text envoyée : vous serez prévenu par email dès le transfert.',
      });
    } on ApiException catch (error) {
      setState(() {
        _saving = false;
        _errors = {for (final f in error.fields) '${f['field']}': '${f['message']}'};
        _formError = _errors.isEmpty ? error.message : '';
      });
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KfColors.inkSoft)),
      );

  @override
  Widget build(BuildContext context) {
    final hasCdf = (widget.balances['CDF'] ?? 0) > 0;
    return Scaffold(
      backgroundColor: KfColors.surface,
      appBar: AppBar(backgroundColor: KfColors.surface, shape: const Border(), title: const Text('Demander un retrait')),
      body: ListView(padding: const EdgeInsets.fromLTRB(KfSpace.s4, 0, KfSpace.s4, KfSpace.s8), children: [
        KfFormSection(
          title: 'Montant',
          child: KfCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (hasCdf) ...[
                KfSegmented(
                  options: const [('USD', 'USD'), ('CDF', 'CDF')],
                  selected: _currency,
                  enabled: !_saving,
                  onChanged: (v) => setState(() => _currency = v),
                ),
                const SizedBox(height: KfSpace.s4),
              ],
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Disponible : '),
                  TextSpan(text: formatAmount(_available, _currency), style: TextStyle(fontWeight: FontWeight.w600, color: KfColors.ink)),
                  TextSpan(text: ' · minimum ${formatAmount(_minimum, _currency)}'),
                ]),
                style: TextStyle(fontSize: 13, color: KfColors.inkMuted),
              ),
              const SizedBox(height: KfSpace.s4),
              KfLabeledField(
                label: 'Montant ($_currency)',
                controller: _amount,
                hint: '0,00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: !_saving,
                errorText: _errors['amount'],
              ),
            ]),
          ),
        ),
        KfFormSection(
          title: 'Compte Mobile Money',
          child: KfCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Opérateur'),
              KfChoicePills(
                options: payoutOperators,
                selected: _operator,
                enabled: !_saving,
                onChanged: (v) => setState(() => _operator = v),
              ),
              const SizedBox(height: KfSpace.s4),
              KfLabeledField(
                label: 'Numéro Mobile Money',
                controller: _phone,
                hint: '+243 81 234 5678',
                keyboardType: TextInputType.phone,
                enabled: !_saving,
                errorText: _errors['phone'],
              ),
              const SizedBox(height: KfSpace.s4),
              KfLabeledField(
                label: 'Nom du titulaire du compte',
                controller: _holder,
                enabled: !_saving,
                errorText: _errors['holder_name'],
                textCapitalization: TextCapitalization.words,
              ),
            ]),
          ),
        ),
        const SizedBox(height: KfSpace.s4),
        Text(
          'Le montant est mis de côté dès la demande. Il revient sur votre solde si la demande est annulée, refusée ou ne peut pas être envoyée.',
          style: TextStyle(fontSize: 12, height: 17 / 12, color: KfColors.inkMuted),
        ),
        if (_formError.isNotEmpty) ...[const SizedBox(height: KfSpace.s4), KfAlert(_formError)],
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: KfColors.surfaceRaised, border: Border(top: BorderSide(color: KfColors.line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, KfSpace.s3),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_saving ? 'Envoi…' : 'Demander le retrait'),
            ),
          ),
        ),
      ),
    );
  }
}
