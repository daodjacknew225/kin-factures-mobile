import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/kit.dart';
import '../invoices/invoice_rules.dart';

// Fiche client : création (POST /clients) ou modification (PATCH /clients/:id), mêmes champs que le
// site. Retourne l'identifiant du client enregistré.
class ClientFormPage extends StatefulWidget {
  const ClientFormPage({super.key, this.client});
  final Json? client;

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

const _fields = [
  ('name', 'Raison sociale ou nom *', TextInputType.text),
  ('contact_name', 'Personne à contacter', TextInputType.name),
  ('email', 'Adresse email', TextInputType.emailAddress),
  ('phone', 'Téléphone', TextInputType.phone),
  ('address', 'Adresse', TextInputType.streetAddress),
  ('city', 'Ville', TextInputType.text),
  ('country', 'Pays', TextInputType.text),
  ('rccm', 'RCCM', TextInputType.text),
  ('nif', 'N° d’impôt (NIF)', TextInputType.text),
  ('notes', 'Notes internes', TextInputType.multiline),
];

class _ClientFormPageState extends State<ClientFormPage> {
  late final Map<String, TextEditingController> _controllers = {
    for (final (key, _, _) in _fields) key: TextEditingController(text: (widget.client?[key] as String?) ?? ''),
  };
  Map<String, String> _errors = {};
  String _formError = '';
  bool _saving = false;

  bool get _editing => widget.client != null;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final values = {for (final e in _controllers.entries) e.key: e.value.text.trim()};
    final errors = <String, String>{};
    if (values['name']!.isEmpty) errors['name'] = 'La raison sociale est obligatoire.';
    final email = values['email']!;
    if (email.isNotEmpty && !RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) errors['email'] = 'Adresse email invalide.';
    setState(() {
      _errors = errors;
      _formError = '';
    });
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    final body = {for (final e in values.entries) e.key: e.value.isEmpty ? null : e.value};
    try {
      final saved = await (_editing ? Api.to.patch('/clients/${widget.client!['id']}', body) : Api.to.post('/clients', body)) as Map;
      Get.back(result: saved['id'] as String);
      showNotice(_editing ? 'Client modifié.' : 'Client ${saved['name']} ajouté.');
    } on ApiException catch (error) {
      setState(() {
        _saving = false;
        _errors = {for (final f in error.fields) '${f['field']}': '${f['message']}'};
        _formError = _errors.isEmpty ? error.message : '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String key, String label, TextInputType keyboard, {String? hint, bool multiline = false}) => Padding(
          padding: const EdgeInsets.only(bottom: KfSpace.s4),
          child: KfLabeledField(
            label: label,
            controller: _controllers[key]!,
            hint: hint,
            keyboardType: multiline ? TextInputType.multiline : keyboard,
            enabled: !_saving,
            errorText: _errors[key],
            minLines: multiline ? 2 : null,
            maxLines: multiline ? 4 : 1,
            textCapitalization: key == 'email' ? TextCapitalization.none : TextCapitalization.sentences,
            onChanged: (_) {
              if (_errors.containsKey(key)) setState(() => _errors.remove(key));
            },
          ),
        );

    return Scaffold(
      backgroundColor: KfColors.surface,
      appBar: AppBar(
        backgroundColor: KfColors.surface,
        shape: const Border(),
        title: Text(_editing ? 'Modifier le client' : 'Nouveau client'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(KfSpace.s4, 0, KfSpace.s4, KfSpace.s8), children: [
        KfFormSection(
          title: 'Identité',
          child: KfCard(
            child: Column(children: [
              field('name', 'Raison sociale ou nom *', TextInputType.text, hint: 'Ex. Société Alpha'),
              field('contact_name', 'Personne à contacter', TextInputType.name),
            ]),
          ),
        ),
        KfFormSection(
          title: 'Coordonnées',
          child: KfCard(
            child: Column(children: [
              field('email', 'Adresse email', TextInputType.emailAddress, hint: 'La facture lui sera envoyée ici'),
              field('phone', 'Téléphone', TextInputType.phone, hint: '+243 …'),
              field('address', 'Adresse', TextInputType.streetAddress, multiline: true),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: field('city', 'Ville', TextInputType.text)),
                const SizedBox(width: KfSpace.s3),
                Expanded(child: field('country', 'Pays', TextInputType.text)),
              ]),
            ]),
          ),
        ),
        KfFormSection(
          title: 'Administratif',
          child: KfCard(
            child: Column(children: [
              field('rccm', 'RCCM', TextInputType.text),
              field('nif', 'N° d’impôt (NIF)', TextInputType.text),
            ]),
          ),
        ),
        KfFormSection(
          title: 'Notes internes',
          child: KfCard(child: field('notes', 'Notes (non visibles par le client)', TextInputType.multiline, multiline: true)),
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
              child: Text(_saving ? 'Enregistrement…' : (_editing ? 'Enregistrer' : 'Ajouter le client')),
            ),
          ),
        ),
      ),
    );
  }
}
