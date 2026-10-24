import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../clients/client_form_page.dart';
import 'invoice_rules.dart';
import 'pickers.dart';

// Nouvelle facture ou modification d'un brouillon (comme /factures/nouvelle du site) :
// client, devise (pour toutes les lignes), date et délai de paiement, lignes de produits,
// moyens de paiement proposés, notes ; « Enregistrer le brouillon » ou « Émettre ».
// Les montants affichés sont un aperçu : l'API recalcule et enregistre les vrais totaux.
// La récurrence se règle sur le site ; celle d'un brouillon est renvoyée telle quelle.
// Retourne l'identifiant de la facture enregistrée (null si rien n'a changé).
class InvoiceFormPage extends StatefulWidget {
  const InvoiceFormPage({super.key, this.invoiceId, this.clientId});
  final String? invoiceId;
  final String? clientId; // nouvelle facture depuis la fiche d'un client

  @override
  State<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _Line {
  _Line({this.productId, this.description = '', this.taxRate, String quantity = '1', String unitPrice = ''})
      : quantity = TextEditingController(text: quantity),
        unitPrice = TextEditingController(text: unitPrice);
  String? productId;
  String description;
  num? taxRate;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  String? catalogPrice; // prix catalogue dans une autre devise (rappel)

  num get qty => parseAmount(quantity.text) ?? 0;
  num get price => parseAmount(unitPrice.text) ?? 0;

  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
  }
}

class _InvoiceFormPageState extends State<InvoiceFormPage> {
  bool _loading = true;
  String _loadError = '';
  bool _saving = false;
  String _formError = '';
  Map<String, String> _errors = {};

  late Json _settings;
  late List<Json> _clients;
  late List<Json> _products;
  late List<Json> _providers;
  Json? _recurrence; // récurrence existante du brouillon, renvoyée telle quelle
  bool _generated = false; // facture générée par une série : pas de récurrence propre

  String? _clientId;
  String _currency = 'USD';
  String _issueDate = isoDayOf(DateTime.now());
  int _termDays = 30;
  final List<_Line> _lines = [];
  final Set<String> _paymentMethods = {};
  final _notes = TextEditingController();
  bool _currencyChanged = false;

  bool get _editing => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  List<Json> _list(Object? data) => (data as List).cast<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final results = await Future.wait([
        Api.to.get('/settings'),
        Api.to.get('/clients'),
        Api.to.get('/products'),
        Api.to.get('/payment-providers'),
        if (_editing) Api.to.get('/invoices/${widget.invoiceId}'),
      ]);
      _settings = Map<String, dynamic>.from(results[0] as Map);
      _clients = _list(results[1]).where((c) => c['is_archived'] != true).toList()
        ..sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
      _products = _list(results[2]).where((p) => p['is_active'] != false).toList()
        ..sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
      _providers = _list(results[3]);

      if (_editing) {
        final detail = Map<String, dynamic>.from(results[4] as Map);
        final invoice = Map<String, dynamic>.from(detail['invoice'] as Map);
        if (invoice['status'] != 'draft') {
          Get.back();
          showNotice('Une facture émise ne se modifie plus.', error: true);
          return;
        }
        _clientId = invoice['client_id'] as String?;
        _currency = invoice['currency'] as String;
        _issueDate = invoice['issue_date'] as String;
        _termDays = daysBetween(_issueDate, invoice['due_date'] as String);
        _notes.text = (invoice['notes'] as String?) ?? '';
        _paymentMethods.addAll(((invoice['payment_methods'] as List?) ?? const []).cast<String>());
        for (final item in (detail['items'] as List).cast<Map>()) {
          _lines.add(_Line(
            productId: item['product_id'] as String?,
            description: item['description'] as String,
            taxRate: numOf(item['tax_rate']),
            quantity: _plain(numOf(item['quantity'])),
            unitPrice: _plain(numOf(item['unit_price'])),
          ));
        }
        final schedule = detail['source_schedule'] as Map?;
        _generated = invoice['schedule_id'] != null && schedule == null;
        if (schedule != null) {
          _recurrence = {
            'frequency': schedule['frequency'],
            'end_date': schedule['end_date'],
            'max_count': schedule['max_count'],
          };
        }
      } else {
        _currency = (_settings['default_currency'] as String?) ?? 'USD';
        _termDays = numOf(_settings['default_payment_terms_days']).toInt();
        _paymentMethods.addAll(_providers.where((p) => p['is_default'] == true).map((p) => p['id'] as String));
        _lines.add(_Line());
        _clientId = widget.clientId;
      }
      setState(() => _loading = false);
    } on ApiException catch (error) {
      setState(() {
        _loading = false;
        _loadError = 'Impossible de préparer le formulaire : ${error.message}';
      });
    }
  }

  // 2.0 → « 2 », 12.5 → « 12,5 » (saisie modifiable)
  String _plain(num value) => (value == value.roundToDouble() ? value.toInt().toString() : value.toString()).replaceAll('.', ',');

  Json? get _client => _clients.firstWhereOrNull((c) => c['id'] == _clientId);
  String get _dueDate => addDays(_issueDate, _termDays);
  num get _defaultTax => numOf(_settings['default_tax_rate'] ?? 16);

  // Aperçu des totaux, avec le même arrondi par ligne que la base
  (double, double, double) get _totals {
    double subtotal = 0;
    double tax = 0;
    for (final line in _lines) {
      final base = line.qty * line.price;
      subtotal += round2(base);
      tax += round2(base * (line.taxRate ?? _defaultTax) / 100);
    }
    return (round2(subtotal), round2(tax), round2(subtotal + tax));
  }

  void _chooseCurrency(String value) {
    if (value == _currency) return;
    setState(() {
      _currency = value;
      if (_lines.any((l) => l.productId != null || l.unitPrice.text.isNotEmpty)) _currencyChanged = true;
    });
  }

  Future<void> _chooseClient() async {
    final client = await pickClient(_clients);
    if (client != null) {
      setState(() {
        _clientId = client['id'] as String;
        _errors.remove('client');
      });
    }
  }

  // Client absent de la liste : création sur place, puis sélection
  Future<void> _newClient() async {
    final id = await Get.to<String>(() => const ClientFormPage());
    if (id == null) return;
    try {
      final clients = _list(await Api.to.get('/clients')).where((c) => c['is_archived'] != true).toList()
        ..sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
      setState(() {
        _clients = clients;
        _clientId = id;
        _errors.remove('client');
      });
    } on ApiException catch (error) {
      showNotice(error.message, error: true);
    }
  }

  Future<void> _chooseProduct(_Line line) async {
    final product = await pickProduct(_products);
    if (product == null) return;
    setState(() {
      line.productId = product['id'] as String;
      line.description = product['name'] as String;
      line.taxRate = numOf(product['tax_rate']);
      // Prix repris seulement s'il est dans la devise de la facture (pas de conversion)
      if (product['currency'] == _currency) {
        line.unitPrice.text = _plain(numOf(product['unit_price']));
        line.catalogPrice = null;
      } else {
        line.unitPrice.text = '';
        line.catalogPrice = formatAmount(numOf(product['unit_price']), product['currency'] as String);
      }
      _errors.remove('lines');
    });
  }

  Future<void> _pickIssueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_issueDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _issueDate = isoDayOf(picked));
  }

  Map<String, String> _validate() {
    final errors = <String, String>{};
    if (_clientId == null) errors['client'] = 'Choisissez un client.';
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      final n = _lines.length > 1 ? ' (ligne ${i + 1})' : '';
      if (line.description.isEmpty) {
        errors['lines'] = 'Choisissez un produit$n.';
      } else if (!(line.qty > 0)) {
        errors['lines'] = 'La quantité doit être supérieure à 0$n.';
      } else if (line.unitPrice.text.trim().isEmpty || parseAmount(line.unitPrice.text) == null || line.price < 0) {
        errors['lines'] = 'Indiquez le prix unitaire en $_currency$n.';
      }
      if (errors.containsKey('lines')) break;
    }
    if (_lines.isEmpty) errors['lines'] = 'Ajoutez au moins une ligne.';
    return errors;
  }

  Future<void> _save({required bool issue}) async {
    FocusScope.of(context).unfocus();
    final errors = _validate();
    setState(() {
      _errors = errors;
      _formError = '';
    });
    if (errors.isNotEmpty) return showNotice(errors.values.first, error: true);

    var sendEmail = false;
    final email = _client?['email'] as String?;
    if (issue) {
      sendEmail = email != null && email.isNotEmpty;
      final ok = await confirmAction(
        title: 'Émettre la facture',
        message: 'Un numéro sera attribué à la facture et elle ne pourra plus être modifiée.'
            '${_recurrence != null ? ' La série récurrente démarrera : à chaque échéance, une facture identique sera émise et envoyée au client.' : ''}',
        confirmLabel: 'Émettre la facture',
        extra: email == null || email.isEmpty
            ? const Padding(
                padding: EdgeInsets.only(top: KfSpace.s3),
                child: Text('Ce client n’a pas d’adresse email : partagez ensuite le lien de paiement.',
                    style: TextStyle(fontSize: 13, color: KfColors.inkMuted)),
              )
            : StatefulBuilder(
                builder: (context, setLocal) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: sendEmail,
                  onChanged: (value) => setLocal(() => sendEmail = value ?? false),
                  title: Text('Envoyer par email à $email', style: const TextStyle(fontSize: 14)),
                ),
              ),
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    final body = {
      'client_id': _clientId,
      'currency': _currency,
      'issue_date': _issueDate,
      'due_date': _dueDate,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'items': [
        for (final line in _lines)
          {
            'product_id': line.productId,
            'description': line.description,
            'quantity': line.qty,
            'unit_price': line.price,
            'tax_rate': line.taxRate ?? _defaultTax,
          },
      ],
      'issue': issue,
      'payment_methods': _paymentMethods.toList(),
      'recurrence': _generated ? null : _recurrence,
    };
    try {
      final saved = await (_editing ? Api.to.put('/invoices/${widget.invoiceId}', body) : Api.to.post('/invoices', body)) as Map;
      final id = saved['id'] as String;
      var notice = issue ? 'Facture ${saved['number']} émise.' : 'Brouillon enregistré.';
      // Un échec d'envoi n'annule pas l'émission (renvoi possible depuis le détail)
      if (issue && sendEmail) {
        try {
          final result = await Api.to.post('/invoices/$id/send', {'kind': 'invoice'}) as Map;
          notice = 'Facture ${saved['number']} émise et envoyée à ${result['recipient']}.';
        } on ApiException catch (error) {
          notice = 'Facture émise, mais l’email n’a pas pu être envoyé : ${error.message}';
        }
      }
      Get.back(result: id);
      showNotice(notice);
    } on ApiException catch (error) {
      final detail = error.fields.isEmpty ? '' : ' (${error.fields.map((f) => f['message']).join(', ')})';
      setState(() {
        _saving = false;
        _formError = 'Enregistrement impossible : ${error.message}$detail';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Modifier le brouillon' : 'Nouvelle facture')),
      body: _loading
          ? const KfLoader()
          : _loadError.isNotEmpty
              ? KfErrorView(_loadError, onRetry: _load)
              : _form(),
      bottomNavigationBar: _loading || _loadError.isNotEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, KfSpace.s3),
                decoration: const BoxDecoration(color: KfColors.surfaceRaised, border: Border(top: BorderSide(color: KfColors.line))),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => _save(issue: false),
                      child: const Text('Brouillon'),
                    ),
                  ),
                  const SizedBox(width: KfSpace.s2),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : () => _save(issue: true),
                      child: Text(_saving ? 'Enregistrement…' : 'Émettre la facture'),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _form() {
    final (subtotal, tax, total) = _totals;
    final text = Theme.of(context).textTheme;
    final client = _client;
    final terms = {0, 15, 30, numOf(_settings['default_payment_terms_days']).toInt(), _termDays}.where((d) => d >= 0).toList()..sort();
    final activeProviders = _providers.where((p) => p['is_active'] == true).toList();

    return ListView(padding: const EdgeInsets.all(KfSpace.s4), children: [
      // Client
      const KfSectionTitle('Client'),
      Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KfRadius.md),
          side: BorderSide(color: _errors.containsKey('client') ? KfColors.danger : KfColors.line),
        ),
        child: ListTile(
          onTap: _saving ? null : _chooseClient,
          leading: const Icon(Icons.person_outline, color: KfColors.inkMuted),
          title: Text(client?['name'] as String? ?? 'Choisir un client',
              style: TextStyle(fontWeight: FontWeight.w500, color: client == null ? KfColors.inkMuted : KfColors.ink)),
          subtitle: client == null
              ? null
              : Text((client['email'] as String?) ?? 'Pas d’adresse email', style: const TextStyle(fontSize: 13, color: KfColors.inkMuted)),
          trailing: const Icon(Icons.chevron_right, color: KfColors.inkMuted),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _saving ? null : _newClient,
          icon: const Icon(Icons.person_add_alt, size: 18),
          label: const Text('Nouveau client'),
        ),
      ),
      const SizedBox(height: KfSpace.s2),

      // Devise et dates
      const KfSectionTitle('Facture'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(KfSpace.s4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Devise', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: KfSpace.s2),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'USD', label: Text('USD')), ButtonSegment(value: 'CDF', label: Text('CDF'))],
              selected: {_currency},
              showSelectedIcon: false,
              onSelectionChanged: _saving ? null : (value) => _chooseCurrency(value.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: KfColors.brandSoft,
                selectedForegroundColor: KfColors.brand,
                side: const BorderSide(color: KfColors.line),
              ),
            ),
            const SizedBox(height: KfSpace.s1),
            Text('S’applique à toutes les lignes.', style: text.bodySmall),
            if (_currencyChanged) ...[
              const SizedBox(height: KfSpace.s2),
              const KfAlert('Devise modifiée : les prix déjà saisis ne sont pas convertis. Vérifiez-les.', tone: AlertTone.pending),
            ],
            const SizedBox(height: KfSpace.s4),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickIssueDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('Émise le ${formatDateLong(_issueDate)}'),
            ),
            const SizedBox(height: KfSpace.s4),
            const Text('Délai de paiement', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: KfSpace.s2),
            Wrap(spacing: KfSpace.s2, runSpacing: KfSpace.s2, children: [
              for (final days in terms)
                ChoiceChip(
                  label: Text(days == 0 ? 'À réception' : '$days jours'),
                  selected: _termDays == days,
                  onSelected: _saving ? null : (_) => setState(() => _termDays = days),
                  selectedColor: KfColors.brandSoft,
                  backgroundColor: KfColors.surfaceRaised,
                  side: BorderSide(color: _termDays == days ? KfColors.brand : KfColors.line),
                  labelStyle: TextStyle(color: _termDays == days ? KfColors.brand : KfColors.ink, fontWeight: FontWeight.w500),
                  showCheckmark: false,
                ),
            ]),
            const SizedBox(height: KfSpace.s1),
            Text('Échéance le ${formatDateLong(_dueDate)}', style: text.bodySmall),
          ]),
        ),
      ),
      const SizedBox(height: KfSpace.s6),

      // Lignes
      KfSectionTitle('Produits et services', trailing: Text(_currency, style: text.bodySmall)),
      for (var i = 0; i < _lines.length; i++) ...[_lineCard(i), const SizedBox(height: KfSpace.s2)],
      OutlinedButton.icon(
        onPressed: _saving ? null : () => setState(() => _lines.add(_Line())),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Ajouter une ligne'),
      ),
      const SizedBox(height: KfSpace.s4),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(KfSpace.s4),
          child: Column(children: [
            _totalRow('Sous-total', formatAmount(subtotal, _currency)),
            _totalRow('TVA', formatAmount(tax, _currency)),
            const Divider(height: KfSpace.s4),
            Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w600))),
              KfAmount(total, _currency, size: AmountSize.lg),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: KfSpace.s6),

      // Moyens de paiement
      const KfSectionTitle('Paiement en ligne proposé'),
      Card(
        child: activeProviders.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(KfSpace.s4),
                child: Text('Aucun moyen de paiement en ligne activé (Paramètres › Paiement sur le site).',
                    style: TextStyle(color: KfColors.inkMuted)),
              )
            : Column(children: [
                for (final provider in activeProviders)
                  Builder(builder: (_) {
                    final id = provider['id'] as String;
                    final accepted = ((provider['currencies'] as List?) ?? const []).contains(_currency);
                    return SwitchListTile(
                      value: accepted && _paymentMethods.contains(id),
                      onChanged: !accepted || _saving
                          ? null
                          : (on) => setState(() => on ? _paymentMethods.add(id) : _paymentMethods.remove(id)),
                      activeThumbColor: KfColors.brand,
                      title: Text(provider['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        accepted ? (provider['description'] as String? ?? '') : 'N’accepte pas les factures en $_currency',
                        style: const TextStyle(fontSize: 13, color: KfColors.inkMuted),
                      ),
                    );
                  }),
              ]),
      ),
      const SizedBox(height: KfSpace.s6),

      // Notes
      const KfSectionTitle('Notes'),
      TextField(
        controller: _notes,
        enabled: !_saving,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(hintText: 'Conditions, coordonnées bancaires… (visible sur la facture)'),
      ),
      if (_recurrence != null) ...[
        const SizedBox(height: KfSpace.s4),
        const KfAlert('Ce brouillon a une récurrence, réglée sur le site : elle est conservée.', tone: AlertTone.pending),
      ],
      if (_formError.isNotEmpty) ...[const SizedBox(height: KfSpace.s4), KfAlert(_formError)],
      const SizedBox(height: KfSpace.s6),
    ]);
  }

  Widget _lineCard(int index) {
    final line = _lines[index];
    final lineTotal = round2(line.qty * line.price);
    final hasError = _errors.containsKey('lines');
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KfRadius.md),
        side: BorderSide(color: hasError ? KfColors.danger : KfColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s2, KfSpace.s2, KfSpace.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: _saving ? null : () => _chooseProduct(line),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: KfSpace.s2),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                        line.description.isEmpty ? 'Choisir un produit' : line.description,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: line.description.isEmpty ? KfColors.brand : KfColors.ink,
                        ),
                      ),
                    ),
                    const Icon(Icons.expand_more, color: KfColors.inkMuted),
                  ]),
                ),
              ),
            ),
            if (_lines.length > 1)
              IconButton(
                tooltip: 'Retirer la ligne',
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _lines.removeAt(index).dispose();
                        }),
                icon: const Icon(Icons.delete_outline, color: KfColors.inkMuted),
              ),
          ]),
          const SizedBox(height: KfSpace.s2),
          Padding(
            padding: const EdgeInsets.only(right: KfSpace.s2),
            child: Row(children: [
              SizedBox(
                width: 84,
                child: TextField(
                  controller: line.quantity,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Qté'),
                ),
              ),
              const SizedBox(width: KfSpace.s2),
              Expanded(
                child: TextField(
                  controller: line.unitPrice,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: 'Prix unitaire', suffixText: _currency),
                ),
              ),
            ]),
          ),
          if (line.catalogPrice != null)
            Padding(
              padding: const EdgeInsets.only(top: KfSpace.s1),
              child: Text('Prix catalogue : ${line.catalogPrice} — saisissez le prix en $_currency.',
                  style: const TextStyle(fontSize: 12, color: KfColors.pending)),
            ),
          const SizedBox(height: KfSpace.s2),
          Padding(
            padding: const EdgeInsets.only(right: KfSpace.s2),
            child: Row(children: [
              Expanded(
                child: Text('TVA ${formatDecimal(line.taxRate ?? _defaultTax)} %',
                    style: const TextStyle(fontSize: 13, color: KfColors.inkMuted)),
              ),
              KfAmount(lineTotal, _currency, size: AmountSize.sm),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _totalRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: KfColors.inkMuted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ]),
      );
}
