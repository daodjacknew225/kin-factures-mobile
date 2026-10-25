import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../invoices/invoice_rules.dart';
import 'product_form_page.dart';

// Produits et services (comme /produits du site) : recherche, actifs ou désactivés ;
// création et modification avec le droit « produits.gerer ».
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Json>? _products;
  String _error = '';
  String _search = '';
  String _scope = 'active';

  bool get _canManage => Auth.to.can('produits.gerer');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.to.get('/products') as List;
      final list = data.cast<Map>().map((p) => Map<String, dynamic>.from(p)).toList()
        ..sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
      if (mounted) {
        setState(() {
          _products = list;
          _error = '';
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = 'Impossible de charger les produits : ${error.message}');
    }
  }

  Future<void> _open([Json? product]) async {
    final saved = await Get.to<String>(() => ProductFormPage(product: product));
    if (saved != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    final inactive = _scope == 'inactive';
    final query = _search.trim().toLowerCase();
    final scoped = (products ?? const <Json>[]).where((p) => (p['is_active'] == false) == inactive).toList();
    final rows = scoped
        .where((p) => query.isEmpty || '${p['name']} ${p['reference'] ?? ''} ${p['description'] ?? ''}'.toLowerCase().contains(query))
        .toList();
    final inactiveCount = (products ?? const <Json>[]).where((p) => p['is_active'] == false).length;
    final activeCount = (products?.length ?? 0) - inactiveCount;

    return Scaffold(
      backgroundColor: KfColors.surface,
      appBar: AppBar(
        backgroundColor: KfColors.surface,
        shape: const Border(),
        title: const Text('Produits et services'),
        actions: [
          if (_canManage)
            IconButton(tooltip: 'Nouveau produit', onPressed: _open, icon: Icon(LucideIcons.plus, color: KfColors.brand)),
        ],
      ),
      body: RefreshIndicator(
        color: KfColors.brand,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.only(bottom: KfSpace.s8), children: [
          const SizedBox(height: KfSpace.s2),
          KfSearchField(hint: 'Désignation ou référence…', onChanged: (v) => setState(() => _search = v)),
          if (inactiveCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: KfSpace.s3),
              child: KfFilterPills(
                options: [('active', 'Actifs', activeCount), ('inactive', 'Désactivés', inactiveCount)],
                selected: _scope,
                onSelected: (id) => setState(() => _scope = id),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, 0),
            child: products == null
                ? (_error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const KfListSkeleton(rows: 6))
                : rows.isEmpty
                    ? KfGroup(children: [
                        KfEmptyState(
                          icon: LucideIcons.package,
                          title: scoped.isEmpty ? (inactive ? 'Aucun produit désactivé' : 'Aucun produit pour le moment') : 'Aucun résultat',
                          message: scoped.isEmpty && !inactive ? 'Ajoutez vos produits et services pour les reprendre sur vos factures.' : null,
                          action: scoped.isEmpty && !inactive && _canManage ? 'Nouveau produit' : null,
                          onAction: _open,
                        ),
                      ])
                    : KfGroup(children: [
                        for (final product in rows)
                          KfRow(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: KfColors.brandSoft, borderRadius: BorderRadius.circular(10)),
                              child: Icon(product['kind'] == 'service' ? LucideIcons.briefcase : LucideIcons.package,
                                  size: 18, color: KfColors.brand),
                            ),
                            title: product['name'] as String,
                            subtitle: [
                              product['reference'],
                              'par ${product['unit']}',
                              'TVA ${formatDecimal(numOf(product['tax_rate']))} %',
                            ].whereType<String>().join(' · '),
                            trailing: KfAmount(numOf(product['unit_price']), product['currency'] as String, size: AmountSize.sm),
                            onTap: _canManage ? () => _open(product) : null,
                          ),
                      ]),
          ),
        ]),
      ),
    );
  }
}
