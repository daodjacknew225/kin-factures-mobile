import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../widgets/common.dart';
import 'invoice_rules.dart';

// Choix d'un client ou d'un produit dans une liste avec recherche (fenêtre en bas de l'écran)
Future<Json?> pickFromList({
  required String title,
  required List<Json> items,
  required String Function(Json) label,
  String Function(Json)? subtitle,
  Widget Function(Json)? trailing,
  required String emptyText,
}) =>
    Get.bottomSheet<Json>(
      _PickerSheet(title: title, items: items, label: label, subtitle: subtitle, trailing: trailing, emptyText: emptyText),
      isScrollControlled: true,
      backgroundColor: KfColors.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(KfRadius.lg))),
    );

Future<Json?> pickClient(List<Json> clients) => pickFromList(
      title: 'Choisir un client',
      items: clients,
      label: (c) => c['name'] as String,
      subtitle: (c) => [c['email'], c['city']].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      emptyText: 'Aucun client : ajoutez-en un depuis l’onglet Clients.',
    );

Future<Json?> pickProduct(List<Json> products) => pickFromList(
      title: 'Choisir un produit ou service',
      items: products,
      label: (p) => p['name'] as String,
      subtitle: (p) => [p['reference'], p['unit']].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      trailing: (p) => KfAmount(numOf(p['unit_price']), p['currency'] as String, size: AmountSize.sm),
      emptyText: 'Aucun produit actif : ajoutez-en un depuis Plus › Produits.',
    );

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.label,
    this.subtitle,
    this.trailing,
    required this.emptyText,
  });
  final String title;
  final List<Json> items;
  final String Function(Json) label;
  final String Function(Json)? subtitle;
  final Widget Function(Json)? trailing;
  final String emptyText;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final rows = widget.items
        .where((item) => query.isEmpty || '${widget.label(item)} ${widget.subtitle?.call(item) ?? ''}'.toLowerCase().contains(query))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: EdgeInsets.zero, // le clavier est déjà pris en compte par la fenêtre
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KfSpace.s6, KfSpace.s6, KfSpace.s6, KfSpace.s3),
              child: Row(children: [
                Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)),
                IconButton(tooltip: 'Fermer', onPressed: Get.back, icon: const Icon(Icons.close)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KfSpace.s6),
              child: TextField(
                autofocus: widget.items.length > 8,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Rechercher…',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: KfSpace.s2),
            Expanded(
              child: rows.isEmpty
                  ? KfEmpty(widget.items.isEmpty ? widget.emptyText : 'Aucun résultat.')
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(indent: KfSpace.s6),
                      itemBuilder: (_, index) {
                        final item = rows[index];
                        final subtitle = widget.subtitle?.call(item) ?? '';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: KfSpace.s6),
                          title: Text(widget.label(item), style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: subtitle.isEmpty ? null : Text(subtitle, style: const TextStyle(fontSize: 13, color: KfColors.inkMuted)),
                          trailing: widget.trailing?.call(item),
                          onTap: () => Get.back(result: item),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
