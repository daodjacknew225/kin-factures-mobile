import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Modifier le client' : 'Nouveau client')),
      body: ListView(padding: const EdgeInsets.all(KfSpace.s4), children: [
        for (final (key, label, keyboard) in _fields) ...[
          TextField(
            controller: _controllers[key],
            enabled: !_saving,
            keyboardType: keyboard,
            textCapitalization: key == 'email' ? TextCapitalization.none : TextCapitalization.sentences,
            autocorrect: key != 'email',
            minLines: key == 'notes' || key == 'address' ? 2 : 1,
            maxLines: key == 'notes' || key == 'address' ? 4 : 1,
            onChanged: (_) {
              if (_errors.containsKey(key)) setState(() => _errors.remove(key));
            },
            decoration: InputDecoration(labelText: label, errorText: _errors[key]),
          ),
          const SizedBox(height: KfSpace.s3),
        ],
        if (_formError.isNotEmpty) ...[KfAlert(_formError), const SizedBox(height: KfSpace.s3)],
        const SizedBox(height: KfSpace.s6),
      ]),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, KfSpace.s3),
          decoration: const BoxDecoration(color: KfColors.surfaceRaised, border: Border(top: BorderSide(color: KfColors.line))),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Enregistrement…' : (_editing ? 'Enregistrer' : 'Ajouter le client')),
          ),
        ),
      ),
    );
  }
}
