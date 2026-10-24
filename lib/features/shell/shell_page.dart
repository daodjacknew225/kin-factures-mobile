import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../clients/clients_tab.dart';
import '../dashboard/dashboard_tab.dart';
import '../invoices/invoices_tab.dart';
import '../more/more_tab.dart';

// Écran principal : menu du bas (Accueil, Factures, Clients, Plus). Chaque onglet garde son état.
class ShellController extends GetxController {
  final index = 0.obs;
  void select(int value) => index.value = value;

  // Chaque onglet se recharge quand on y revient (données modifiées ailleurs)
  void onTabShown(int tab, VoidCallback reload) => ever<int>(index, (value) {
        if (value == tab) reload();
      });
}

class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = Get.put(ShellController());
    return Obx(() => Scaffold(
          body: IndexedStack(
            index: shell.index.value,
            children: const [
              DashboardTab(),
              InvoicesTab(),
              ClientsTab(),
              MoreTab(),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: KfColors.line))),
            child: NavigationBar(
              selectedIndex: shell.index.value,
              onDestinationSelected: shell.select,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Accueil'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Factures'),
                NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clients'),
                NavigationDestination(icon: Icon(Icons.menu), label: 'Plus'),
              ],
            ),
          ),
        ));
  }
}

