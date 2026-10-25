import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../invoices/invoice_rules.dart';
import '../shell/quick_actions.dart';
import '../shell/shell_page.dart';
import 'client_detail_page.dart';

// Onglet Clients (comme /clients du site) : recherche, clients actifs ou archivés, création.
class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  List<Json>? _clients;
  String _error = '';
  String _search = '';
  String _scope = 'active';

  @override
  void initState() {
    super.initState();
    _load();
    Get.find<ShellController>().onTabShown(2, _load);
  }

  Future<void> _load() async {
    try {
      final data = await Api.to.get('/clients') as List;
      final list = data.cast<Map>().map((c) => Map<String, dynamic>.from(c)).toList()
        ..sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
      if (mounted) {
        setState(() {
          _clients = list;
          _error = '';
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = 'Impossible de charger les clients : ${error.message}');
    }
  }

  Future<void> _openDetail(String id) async {
    final changed = await Get.to<bool>(() => ClientDetailPage(id: id));
    if (changed == true) _load();
  }

  Future<void> _create() async {
    await quickNewClient();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final clients = _clients;
    final archived = _scope == 'archived';
    final query = _search.trim().toLowerCase();
    final scoped = (clients ?? const <Json>[]).where((c) => (c['is_archived'] == true) == archived).toList();
    final rows = scoped
        .where((c) => query.isEmpty ||
            [c['name'], c['contact_name'], c['email'], c['phone'], c['city']].whereType<String>().join(' ').toLowerCase().contains(query))
        .toList();
    final archivedCount = (clients ?? const <Json>[]).where((c) => c['is_archived'] == true).length;
    final activeCount = (clients?.length ?? 0) - archivedCount;

    return Scaffold(
      backgroundColor: KfColors.surface,
      body: RefreshIndicator(
        color: KfColors.brand,
        onRefresh: _load,
        edgeOffset: MediaQuery.of(context).padding.top,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: KfPageHeader(
              title: 'Clients',
              subtitle: clients == null
                  ? null
                  : Text(plural(activeCount, 'client actif', 'clients actifs'), style: TextStyle(fontSize: 14, color: KfColors.inkMuted)),
              trailing: IconButton(
                tooltip: 'Nouveau client',
                onPressed: _create,
                style: IconButton.styleFrom(backgroundColor: KfColors.brandSoft, foregroundColor: KfColors.brand, fixedSize: const Size(44, 44)),
                icon: const Icon(LucideIcons.userPlus, size: 20),
              ),
            ),
          ),
          SliverToBoxAdapter(child: KfSearchField(hint: 'Nom, contact, email, ville…', onChanged: (v) => setState(() => _search = v))),
          if (archivedCount > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: KfSpace.s3),
                child: KfFilterPills(
                  options: [('active', 'Actifs', activeCount), ('archived', 'Archivés', archivedCount)],
                  selected: _scope,
                  onSelected: (id) => setState(() => _scope = id),
                ),
              ),
            ),
          if (_error.isNotEmpty && clients != null)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, 0), child: KfAlert(_error))),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s3, KfSpace.s4, KfSpace.s8),
            sliver: SliverToBoxAdapter(
              child: clients == null
                  ? (_error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const KfListSkeleton(rows: 7))
                  : rows.isEmpty
                      ? KfGroup(children: [
                          KfEmptyState(
                            icon: LucideIcons.users,
                            title: scoped.isEmpty ? (archived ? 'Aucun client archivé' : 'Aucun client pour le moment') : 'Aucun résultat',
                            message: scoped.isEmpty && !archived ? 'Ajoutez vos clients pour leur envoyer des factures.' : null,
                            action: scoped.isEmpty && !archived ? 'Nouveau client' : null,
                            onAction: _create,
                          ),
                        ])
                      : KfGroup(children: [
                          for (final client in rows)
                            KfRow(
                              leading: KfAvatar(client['name'] as String),
                              title: client['name'] as String,
                              subtitle: [client['contact_name'], client['email'] ?? client['phone'], client['city']]
                                  .whereType<String>()
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              trailing: Icon(LucideIcons.chevronRight, size: 18, color: KfColors.inkMuted),
                              onTap: () => _openDetail(client['id'] as String),
                            ),
                        ]),
            ),
          ),
        ]),
      ),
    );
  }
}
