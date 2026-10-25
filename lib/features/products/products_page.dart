import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
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
  bool _inactive = false;

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
    final query = _search.trim().toLowerCase();
    final scoped = (products ?? const <Json>[]).where((p) => (p['is_active'] == false) == _inactive).toList();
    final rows = scoped
        .where((p) => query.isEmpty || '${p['name']} ${p['reference'] ?? ''} ${p['description'] ?? ''}'.toLowerCase().contains(query))
        .toList();
    final inactiveCount = (products ?? const <Json>[]).where((p) => p['is_active'] == false).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Produits et services')),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _open,
              backgroundColor: KfColors.brand,
              foregroundColor: KfColors.onBrand,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau produit'),
            )
          : null,
      body: products == null
          ? (_error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const KfLoader())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s4, KfSpace.s4, KfSpace.s2),
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                    hintText: 'Désignation ou référence…',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (inactiveCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4),
                  child: Row(children: [
                    for (final inactive in [false, true])
                      Padding(
                        padding: const EdgeInsets.only(right: KfSpace.s2),
                        child: ChoiceChip(
                          label: Text(inactive ? 'Désactivés $inactiveCount' : 'Actifs ${products.length - inactiveCount}'),
                          selected: _inactive == inactive,
                          onSelected: (_) => setState(() => _inactive = inactive),
                          selectedColor: KfColors.brandSoft,
                          backgroundColor: KfColors.surfaceRaised,
                          side: BorderSide(color: _inactive == inactive ? KfColors.brand : KfColors.line),
                          labelStyle: TextStyle(fontWeight: FontWeight.w500, color: _inactive == inactive ? KfColors.brand : KfColors.inkMuted),
                          showCheckmark: false,
                        ),
                      ),
                  ]),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: KfColors.brand,
                  onRefresh: _load,
                  child: rows.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          KfEmpty(
                            scoped.isEmpty
                                ? (_inactive ? 'Aucun produit désactivé.' : 'Aucun produit pour le moment.')
                                : 'Aucun produit ne correspond à cette recherche.',
                            icon: Icons.inventory_2_outlined,
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s2, KfSpace.s4, 96),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: KfSpace.s2),
                          itemBuilder: (_, index) {
                            final product = rows[index];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: _canManage ? () => _open(product) : null,
                                title: Text(product['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  [
                                    product['reference'],
                                    product['kind'] == 'service' ? 'Service' : 'Produit',
                                    'par ${product['unit']}',
                                    'TVA ${formatDecimal(numOf(product['tax_rate']))} %',
                                  ].whereType<String>().join(' · '),
                                  style: TextStyle(fontSize: 13, color: KfColors.inkMuted),
                                ),
                                trailing: KfAmount(numOf(product['unit_price']), product['currency'] as String, size: AmountSize.sm),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ]),
    );
  }
}
