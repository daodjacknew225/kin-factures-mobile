import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
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
      backgroundColor: KfColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(children: [
          const SizedBox(height: KfSpace.s3),
          const KfSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(KfSpace.s6, KfSpace.s4, KfSpace.s3, KfSpace.s3),
            child: Row(children: [
              Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Fermer', onPressed: Get.back, icon: const Icon(LucideIcons.x)),
            ]),
          ),
          KfSearchField(hint: 'Rechercher…', onChanged: (value) => setState(() => _query = value)),
          const SizedBox(height: KfSpace.s3),
          Expanded(
            child: rows.isEmpty
                ? SingleChildScrollView(
                    child: KfEmptyState(
                      icon: LucideIcons.search,
                      title: widget.items.isEmpty ? 'Liste vide' : 'Aucun résultat',
                      message: widget.items.isEmpty ? widget.emptyText : null,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(KfSpace.s4, 0, KfSpace.s4, KfSpace.s4),
                    child: KfGroup(children: [
                      for (final item in rows)
                        KfRow(
                          leading: widget.trailing == null
                              ? KfAvatar(widget.label(item))
                              : Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: KfColors.brandSoft, borderRadius: BorderRadius.circular(10)),
                                  child: Icon(LucideIcons.package, size: 18, color: KfColors.brand),
                                ),
                          title: widget.label(item),
                          subtitle: widget.subtitle?.call(item),
                          trailing: widget.trailing?.call(item),
                          onTap: () => Get.back(result: item),
                        ),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}
