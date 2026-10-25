// Adresses de Kin Factures. Production par défaut ; pour l'API locale depuis l'émulateur Android :
//   flutter run --dart-define=SITE_URL=http://10.0.2.2:5173 --dart-define=API_URL=http://10.0.2.2:3001/api
class AppConfig {
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://factures.kinpay.cd');
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: '$siteUrl/api');

  // Pages du site ouvertes dans le navigateur (non reprises dans l'application)
  static const signupUrl = '$siteUrl/inscription';
  static const forgotPasswordUrl = '$siteUrl/mot-de-passe-oublie';
  static const termsUrl = '$siteUrl/cgu';
  static const privacyUrl = '$siteUrl/confidentialite';
  static String paymentUrl(String token) => '$siteUrl/payer/$token';

  static const setPasswordUrl = '$siteUrl/definir-mot-de-passe';

  // Support Kin Factures (éditeur : CONGOLESE YOUTH SARL, voir les mentions légales du site)
  static const supportEmail = 'jean.patrick@x-paycash.com';
  static const supportPhone = '+243814864186';
  static const supportWhatsApp = 'https://wa.me/243814864186';

  // Verrouillage après inactivité (comme le site : 15 minutes ; raccourci possible pour les essais :
  // --dart-define=IDLE_LOCK_SECONDS=40)
  static const idleLock = Duration(seconds: int.fromEnvironment('IDLE_LOCK_SECONDS', defaultValue: 15 * 60));
}
