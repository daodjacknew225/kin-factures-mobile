import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../app/theme.dart';

// Apparence : clair, sombre ou automatique (suit le réglage du téléphone). Le choix est mémorisé ;
// à chaque changement, la palette KfColors est remplacée et toute l'application est redessinée.
enum ThemeChoice { system, light, dark }

class ThemeController extends GetxService with WidgetsBindingObserver {
  static ThemeController get to => Get.find();
  static const _key = 'kf_theme';

  final choice = ThemeChoice.system.obs;
  final version = 0.obs; // change à chaque nouvelle palette (reconstruit l'application)

  ThemeController init() {
    final saved = GetStorage().read<String>(_key);
    choice.value = ThemeChoice.values.firstWhere((c) => c.name == saved, orElse: () => ThemeChoice.system);
    WidgetsBinding.instance.addObserver(this);
    _apply(rebuild: false);
    return this;
  }

  bool get isDark => switch (choice.value) {
        ThemeChoice.dark => true,
        ThemeChoice.light => false,
        ThemeChoice.system => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
      };

  void select(ThemeChoice value) {
    choice.value = value;
    GetStorage().write(_key, value.name);
    _apply();
  }

  // Réglage du téléphone modifié (mode automatique)
  @override
  void didChangePlatformBrightness() {
    if (choice.value == ThemeChoice.system) _apply();
  }

  void _apply({bool rebuild = true}) {
    KfColors.use(isDark ? kfDark : kfLight);
    SystemChrome.setSystemUIOverlayStyle(statusBarStyle);
    version.value++;
    if (rebuild) Get.forceAppUpdate();
  }

  // Icônes de la barre d'état lisibles sur le fond des écrans (hors bandeau vert)
  static SystemUiOverlayStyle get statusBarStyle => KfColors.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
