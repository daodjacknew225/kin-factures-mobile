import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/kit.dart';
import '../invoices/invoice_rules.dart';

// Produit ou service : création (POST /products) ou modification (PATCH /products/:id),
// activation / désactivation (droit « produits.gerer »). La référence (PRD-0001…) est attribuée
// par l'API. Retourne l'identifiant du produit enregistré.
class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.product});
  final Json? product;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  late final _name = TextEditingController(text: widget.product?['name'] as String? ?? '');
  late final _description = TextEditingController(text: widget.product?['description'] as String? ?? '');
  late final _unit = TextEditingController(text: widget.product?['unit'] as String? ?? 'unité');
  late final _price = TextEditingController(text: widget.product == null ? '' : _plain(numOf(widget.product!['unit_price'])));
  late final _tax = TextEditingController(text: widget.product == null ? '16' : _plain(numOf(widget.product!['tax_rate'])));
  late String _kind = widget.product?['kind'] as String? ?? 'service';
  late String _currency = widget.product?['currency'] as String? ?? 'USD';
  Map<String, String> _errors = {};
  String _formError = '';
  bool _saving = false;

  bool get _editing => widget.product != null;

  static String _plain(num value) =>
      (value == value.roundToDouble() ? value.toInt().toString() : value.toString()).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    // Nouveau produit : TVA et devise par défaut de l'entreprise
    if (!_editing) {
      Api.to.get('/settings').then((settings) {
        if (!mounted || settings is! Map) return;
        setState(() {
          _currency = (settings['default_currency'] as String?) ?? _currency;
          _tax.text = _plain(numOf(settings['default_tax_rate'] ?? 16));
        });
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _unit, _price, _tax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final price = parseAmount(_price.text);
    final tax = parseAmount(_tax.text);
    final errors = <String, String>{
      if (_name.text.trim().isEmpty) 'name': 'La désignation est obligatoire.',
      if (_unit.text.trim().isEmpty) 'unit': 'L’unité est obligatoire.',
      if (price == null || price < 0) 'unit_price': 'Indiquez un prix positif ou nul.',
      if (tax == null || tax < 0 || tax > 100) 'tax_rate': 'Taux entre 0 et 100.',
    };
    setState(() {
      _errors = errors;
      _formError = '';
    });
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    final body = {
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'kind': _kind,
      'unit': _unit.text.trim(),
      'unit_price': price,
      'currency': _currency,
      'tax_rate': tax,
    };
    try {
      final saved = await (_editing ? Api.to.patch('/products/${widget.product!['id']}', body) : Api.to.post('/products', body)) as Map;
      Get.back(result: saved['id'] as String);
      showNotice(_editing ? 'Produit modifié.' : 'Produit ${saved['reference'] ?? ''} ajouté.');
    } on ApiException catch (error) {
      setState(() {
        _saving = false;
        _errors = {for (final f in error.fields) '${f['field']}': '${f['message']}'};
        _formError = _errors.isEmpty ? error.message : '';
      });
    }
  }

  Future<void> _toggleActive() async {
    final active = widget.product!['is_active'] != false;
    final ok = await confirmAction(
      title: active ? 'Désactiver le produit' : 'Réactiver le produit',
      message: active
          ? '${widget.product!['name']} ne sera plus proposé sur les nouvelles factures. Les factures existantes ne changent pas.'
          : '${widget.product!['name']} sera de nouveau proposé sur les nouvelles factures.',
      confirmLabel: active ? 'Désactiver' : 'Réactiver',
      danger: active,
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await Api.to.post('/products/${widget.product!['id']}/active', {'active': !active});
      Get.back(result: widget.product!['id'] as String);
      showNotice(active ? 'Produit désactivé.' : 'Produit réactivé.');
    } on ApiException catch (error) {
      setState(() => _saving = false);
      showNotice(error.message, error: true);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KfColors.inkSoft)),
      );

  Widget _suffix(String text) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Center(widthFactor: 1, child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: KfColors.inkMuted))),
      );

  @override
  Widget build(BuildContext context) {
    final active = !_editing || widget.product!['is_active'] != false;
    return Scaffold(
      backgroundColor: KfColors.surface,
      appBar: AppBar(
        backgroundColor: KfColors.surface,
        shape: const Border(),
        title: Text(_editing ? (widget.product!['reference'] as String? ?? 'Produit') : 'Nouveau produit'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _toggleActive,
              style: TextButton.styleFrom(foregroundColor: active ? KfColors.danger : KfColors.brand),
              child: Text(active ? 'Désactiver' : 'Réactiver'),
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(KfSpace.s4, 0, KfSpace.s4, KfSpace.s8), children: [
        if (!active) ...[
          const SizedBox(height: KfSpace.s2),
          const KfAlert('Produit désactivé : il n’est plus proposé sur les nouvelles factures.', tone: AlertTone.pending),
        ],
        KfFormSection(
          title: 'Description',
          child: KfCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Type'),
              KfSegmented(
                options: const [('service', 'Service'), ('produit', 'Produit')],
                selected: _kind,
                enabled: !_saving,
                onChanged: (v) => setState(() => _kind = v),
              ),
              const SizedBox(height: KfSpace.s4),
              KfLabeledField(
                label: 'Désignation *',
                controller: _name,
                hint: 'Ex. Conseil en gestion',
                enabled: !_saving,
                errorText: _errors['name'],
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: KfSpace.s4),
              KfLabeledField(
                label: 'Description',
                controller: _description,
                hint: 'Facultative',
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
              ),
            ]),
          ),
        ),
        KfFormSection(
          title: 'Prix',
          child: KfCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _label('Devise du prix'),
              KfSegmented(
                options: const [('USD', 'USD'), ('CDF', 'CDF')],
                selected: _currency,
                enabled: !_saving,
                onChanged: (v) => setState(() => _currency = v),
              ),
              const SizedBox(height: KfSpace.s4),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 3,
                  child: KfLabeledField(
                    label: 'Prix unitaire *',
                    controller: _price,
                    hint: '0,00',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !_saving,
                    errorText: _errors['unit_price'],
                    suffix: _suffix(_currency),
                  ),
                ),
                const SizedBox(width: KfSpace.s3),
                Expanded(
                  flex: 2,
                  child: KfLabeledField(
                    label: 'Unité *',
                    controller: _unit,
                    hint: 'heure, jour…',
                    enabled: !_saving,
                    errorText: _errors['unit'],
                  ),
                ),
              ]),
              const SizedBox(height: KfSpace.s4),
              KfLabeledField(
                label: 'TVA',
                controller: _tax,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: !_saving,
                errorText: _errors['tax_rate'],
                suffix: _suffix('%'),
              ),
            ]),
          ),
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
              child: Text(_saving ? 'Enregistrement…' : (_editing ? 'Enregistrer' : 'Ajouter le produit')),
            ),
          ),
        ),
      ),
    );
  }
}
