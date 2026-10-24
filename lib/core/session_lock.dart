import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import '../app/config.dart';
import 'auth.dart';

// Verrouillage après 15 minutes sans activité, comme le site : au premier plan (minuteur) et au
// retour dans l'application (temps passé en arrière-plan). La session reste ouverte côté serveur ;
// on déverrouille par empreinte (ou code du téléphone) ou en ressaisissant son mot de passe.
class SessionLock extends GetxService with WidgetsBindingObserver {
  static SessionLock get to => Get.find();

  final locked = false.obs;
  final biometricAvailable = false.obs;
  final _localAuth = LocalAuthentication();
  DateTime _lastActivity = DateTime.now();
  Timer? _timer;

  Future<SessionLock> init() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      biometricAvailable.value = await _localAuth.isDeviceSupported();
    } catch (_) {
      biometricAvailable.value = false;
    }
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
    return this;
  }

  // Toute interaction (toucher l'écran) repousse le verrouillage
  void markActivity() {
    if (!locked.value) _lastActivity = DateTime.now();
  }

  void _check() {
    if (Auth.to.signedIn && !locked.value && DateTime.now().difference(_lastActivity) >= AppConfig.idleLock) {
      locked.value = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void unlock() {
    _lastActivity = DateTime.now();
    locked.value = false;
  }

  // Empreinte, visage ou code du téléphone ; false si annulé ou indisponible
  Future<bool> unlockWithDevice() async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Déverrouillez Kin Factures',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Déverrouiller Kin Factures',
            signInHint: 'Touchez le capteur d’empreinte',
            cancelButton: 'Annuler',
          ),
        ],
      );
      if (ok) unlock();
      return ok;
    } catch (_) {
      return false;
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
