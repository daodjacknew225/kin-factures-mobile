import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme.dart';
import '../clients/clients_tab.dart';
import '../dashboard/dashboard_tab.dart';
import '../invoices/invoices_tab.dart';
import '../more/more_tab.dart';
import '../../core/theme_controller.dart';
import 'quick_actions.dart';

// Écran principal : menu du bas (Accueil, Factures, « + », Clients, Plus). Chaque onglet garde son
// état et se recharge quand on y revient ou après une action rapide.
class ShellController extends GetxController {
  final index = 0.obs;
  final _refresh = 0.obs;

  void select(int value) => index.value = value;

  // Une donnée a changé (action rapide) : les onglets se rechargent
  void changed() => _refresh.value++;

  void onTabShown(int tab, VoidCallback reload) {
    ever<int>(index, (value) {
      if (value == tab) reload();
    });
    ever<int>(_refresh, (_) => reload());
  }
}

class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = Get.put(ShellController());
    return Obx(() => AnnotatedRegion<SystemUiOverlayStyle>(
          // Accueil : bandeau vert foncé sous la barre d'état (icônes claires)
          value: shell.index.value == 0 ? SystemUiOverlayStyle.light : ThemeController.statusBarStyle,
          child: Scaffold(
            body: IndexedStack(
              index: shell.index.value,
              children: const [DashboardTab(), InvoicesTab(), ClientsTab(), MoreTab()],
            ),
            bottomNavigationBar: _BottomBar(index: shell.index.value, onSelect: shell.select),
          ),
        ));
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: KfColors.surfaceRaised,
          border: Border(top: BorderSide(color: KfColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(children: [
              _NavItem(icon: LucideIcons.house, label: 'Accueil', active: index == 0, onTap: () => onSelect(0)),
              _NavItem(icon: LucideIcons.receipt, label: 'Factures', active: index == 1, onTap: () => onSelect(1)),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: 'Créer',
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        showCreateMenu();
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: KfColors.brand,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: KfColors.brand.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Icon(LucideIcons.plus, color: KfColors.onBrand, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
              _NavItem(icon: LucideIcons.users, label: 'Clients', active: index == 2, onTap: () => onSelect(2)),
              _NavItem(icon: LucideIcons.menu, label: 'Plus', active: index == 3, onTap: () => onSelect(3)),
            ]),
          ),
        ),
      );
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Semantics(
          selected: active,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () {
              if (!active) HapticFeedback.selectionClick();
              onTap();
            },
            radius: 36,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 22, color: active ? KfColors.brand : KfColors.inkMuted),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? KfColors.brand : KfColors.inkMuted)),
            ]),
          ),
        ),
      );
}
