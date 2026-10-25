import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../core/api.dart';
import '../../widgets/common.dart';
import '../shell/shell_page.dart';
import '../invoices/invoice_rules.dart';
import 'client_detail_page.dart';
import 'client_form_page.dart';

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
  bool _archived = false;

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

  Future<void> _create() async {
    final id = await Get.to<String>(() => const ClientFormPage());
    if (id == null) return;
    await _load();
    await _openDetail(id);
  }

  Future<void> _openDetail(String id) async {
    final changed = await Get.to<bool>(() => ClientDetailPage(id: id));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final clients = _clients;
    final query = _search.trim().toLowerCase();
    final scoped = (clients ?? const <Json>[]).where((c) => (c['is_archived'] == true) == _archived).toList();
    final rows = scoped
        .where((c) => query.isEmpty ||
            [c['name'], c['contact_name'], c['email'], c['phone'], c['city']].whereType<String>().join(' ').toLowerCase().contains(query))
        .toList();
    final archivedCount = (clients ?? const <Json>[]).where((c) => c['is_archived'] == true).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: KfColors.brand,
        foregroundColor: KfColors.onBrand,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nouveau client'),
      ),
      body: clients == null
          ? (_error.isNotEmpty ? KfErrorView(_error, onRetry: _load) : const KfLoader())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s4, KfSpace.s4, KfSpace.s2),
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                    hintText: 'Nom, contact, email, ville…',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (archivedCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KfSpace.s4),
                  child: Row(children: [
                    for (final archived in [false, true])
                      Padding(
                        padding: const EdgeInsets.only(right: KfSpace.s2),
                        child: ChoiceChip(
                          label: Text(archived ? 'Archivés $archivedCount' : 'Actifs ${clients.length - archivedCount}'),
                          selected: _archived == archived,
                          onSelected: (_) => setState(() => _archived = archived),
                          selectedColor: KfColors.brandSoft,
                          backgroundColor: KfColors.surfaceRaised,
                          side: BorderSide(color: _archived == archived ? KfColors.brand : KfColors.line),
                          labelStyle: TextStyle(fontWeight: FontWeight.w500, color: _archived == archived ? KfColors.brand : KfColors.inkMuted),
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
                                ? (_archived ? 'Aucun client archivé.' : 'Aucun client pour le moment.')
                                : 'Aucun client ne correspond à cette recherche.',
                            icon: Icons.people_outline,
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(KfSpace.s4, KfSpace.s2, KfSpace.s4, 96),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: KfSpace.s2),
                          itemBuilder: (_, index) {
                            final client = rows[index];
                            final details = [client['contact_name'], client['email'] ?? client['phone'], client['city']]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' · ');
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: ListTile(
                                onTap: () => _openDetail(client['id'] as String),
                                leading: _Initials(client['name'] as String),
                                title: Text(client['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: details.isEmpty
                                    ? null
                                    : Text(details, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, color: KfColors.inkMuted)),
                                trailing: Icon(Icons.chevron_right, color: KfColors.inkMuted),
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

class _Initials extends StatelessWidget {
  const _Initials(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty ? '?' : (words.first[0] + (words.length > 1 ? words.last[0] : '')).toUpperCase();
    return CircleAvatar(
      backgroundColor: KfColors.brandSoft,
      child: Text(initials, style: TextStyle(color: KfColors.brand, fontWeight: FontWeight.w600, fontSize: 14)),
    );
  }
}
