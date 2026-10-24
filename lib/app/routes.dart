import 'package:get/get.dart';

import '../features/login/login_page.dart';
import '../features/shell/shell_page.dart';

// Écrans de l'application (navigation GetX)
class Routes {
  static const login = '/connexion';
  static const home = '/';
}

final appPages = [
  GetPage(name: Routes.login, page: () => const LoginPage()),
  GetPage(name: Routes.home, page: () => const ShellPage()),
];
