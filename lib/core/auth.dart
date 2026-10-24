import 'package:get/get.dart';

import '../app/routes.dart';
import 'api.dart';

// Compte connecté, son profil et ses droits (GET /api/auth/me), comme AuthContext du site.
// can() sert uniquement à afficher ou masquer un bouton : l'API applique les droits.
class Auth extends GetxService {
  static Auth get to => Get.find();

  final me = Rxn<Map<String, dynamic>>();
  final companyName = ''.obs;

  Api get _api => Api.to;

  bool get signedIn => me.value != null;
  String get email => (me.value?['user']?['email'] ?? '') as String;
  String get name => (me.value?['user']?['name'] ?? '') as String;
  String get firstName => name.trim().split(RegExp(r'\s+')).first;
  String get roleName => (me.value?['role']?['name'] ?? '') as String;
  bool can(String permission) => ((me.value?['permissions'] ?? const []) as List).contains(permission);

  Future<Auth> init() async {
    _api.onUnauthorized = _sessionExpired;
    if (_api.hasToken) {
      try {
        await refresh();
      } on ApiException catch (error) {
        // Hors connexion au démarrage : on garde le jeton, l'écran affichera l'erreur
        if (error.status != 0) await _api.saveToken(null);
      }
    }
    return this;
  }

  // Recharge le compte (et le nom de l'entreprise) ; null si le jeton n'est plus valable
  Future<void> refresh() async {
    final data = await _api.get('/auth/me');
    if (data == null) {
      await _api.saveToken(null);
      me.value = null;
      return;
    }
    me.value = Map<String, dynamic>.from(data as Map);
    final settings = await _api.get('/settings');
    companyName.value = ((settings as Map?)?['company_name'] ?? '') as String;
  }

  // Connexion email + mot de passe : l'API renvoie le jeton dans l'en-tête set-auth-token
  Future<void> signIn(String email, String password) async {
    final response = await _api.raw('POST', '/auth/sign-in/email', body: {
      'email': email.trim(),
      'password': password,
      'rememberMe': true,
    });
    final status = response.statusCode ?? 0;
    final token = response.headers.value('set-auth-token');
    if (status < 200 || status >= 300 || token == null) throw _signInError(Api.errorOf(response));
    await _api.saveToken(token);
    await refresh();
    if (!signedIn) throw ApiException(401, 'Connexion impossible. Réessayez.');
  }

  // Messages de connexion selon la réponse de l'API (comme le site : Better Auth répond en anglais)
  static ApiException _signInError(ApiException error) => ApiException(error.status, switch (error.status) {
        401 => 'Email ou mot de passe incorrect.',
        403 => 'Ce compte est désactivé. Contactez l’administrateur de votre entreprise.',
        429 => 'Trop de tentatives de connexion. Réessayez dans une minute.',
        _ => error.message,
      });

  Future<void> signOut() async {
    try {
      await _api.post('/auth/sign-out');
    } on ApiException {
      // Déjà déconnecté côté serveur ou hors connexion : on oublie le jeton quand même
    }
    await _api.saveToken(null);
    me.value = null;
    companyName.value = '';
    Get.offAllNamed(Routes.login);
  }

  void _sessionExpired() {
    if (!signedIn) return;
    _api.saveToken(null);
    me.value = null;
    Get.offAllNamed(Routes.login, arguments: 'Votre session a expiré : reconnectez-vous.');
  }
}
