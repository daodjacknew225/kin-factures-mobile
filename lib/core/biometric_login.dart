import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

// Connexion par empreinte (ou visage) : l'email et le mot de passe sont gardés dans le coffre chiffré
// du téléphone (Android Keystore, flutter_secure_storage) et ne sont lus qu'après validation de
// l'empreinte dans l'application. Désactivée automatiquement si le mot de passe ne marche plus.
class BiometricLogin {
  static const _emailKey = 'kf_bio_email';
  static const _passwordKey = 'kf_bio_password';
  static const _declinedKey = 'kf_bio_declined'; // proposition refusée : on ne la refait pas
  static const _storage = FlutterSecureStorage();
  static final _localAuth = LocalAuthentication();

  // Le téléphone a une empreinte ou un visage enregistré
  static Future<bool> available() async {
    try {
      return await _localAuth.canCheckBiometrics && (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> enabled() async => (await _storage.read(key: _emailKey)) != null;

  static Future<String?> savedEmail() => _storage.read(key: _emailKey);

  // À proposer après une connexion par mot de passe ?
  static Future<bool> shouldOffer() async =>
      GetStorage().read<bool>(_declinedKey) != true && !await enabled() && await available();

  static void decline() => GetStorage().write(_declinedKey, true);

  // Empreinte demandée ; false si annulée, refusée ou indisponible
  static Future<bool> _authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Kin Factures',
            signInHint: 'Touchez le capteur d’empreinte',
            cancelButton: 'Annuler',
          ),
        ],
      );
    } catch (_) {
      return false;
    }
  }

  // Active la connexion par empreinte (confirmée par une empreinte)
  static Future<bool> enable(String email, String password) async {
    if (!await _authenticate('Confirmez votre empreinte pour l’activer')) return false;
    await _storage.write(key: _emailKey, value: email.trim());
    await _storage.write(key: _passwordKey, value: password);
    GetStorage().remove(_declinedKey);
    return true;
  }

  static Future<void> disable() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }

  // Identifiants après validation de l'empreinte ; null si annulé
  static Future<(String, String)?> unlock() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email == null || password == null) return null;
    if (!await _authenticate('Connectez-vous à Kin Factures')) return null;
    return (email, password);
  }
}
