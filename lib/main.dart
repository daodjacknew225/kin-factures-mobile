import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/routes.dart';
import 'app/theme.dart';
import 'core/api.dart';
import 'core/auth.dart';
import 'core/session_lock.dart';
import 'features/lock/lock_screen.dart';

// Kin Factures, application mobile des entreprises (Android).
// Même API que le site factures.kinpay.cd ; connexion par jeton (voir core/api.dart).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await GetStorage.init();
  await Get.putAsync(() => Api().init());
  await Get.putAsync(() => SessionLock().init());
  await Get.putAsync(() => Auth().init());
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  runApp(const KinFacturesApp());
}

class KinFacturesApp extends StatelessWidget {
  const KinFacturesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Kin Factures',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: Auth.to.signedIn ? Routes.home : Routes.login,
      getPages: appPages,
      // Chaque toucher repousse le verrouillage ; l'écran de verrouillage passe par-dessus tout
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => SessionLock.to.markActivity(),
        child: Obx(() => Stack(children: [
              // Écran verrouillé : le contenu caché n'est plus lisible (lecteur d'écran)
              if (child != null) ExcludeSemantics(excluding: SessionLock.to.locked.value && Auth.to.signedIn, child: child),
              // Overlay propre : les champs de saisie en ont besoin (hors du navigateur de pages)
              if (SessionLock.to.locked.value && Auth.to.signedIn)
                Overlay(initialEntries: [OverlayEntry(builder: (_) => const LockScreen())]),
            ])),
      ),
    );
  }
}
