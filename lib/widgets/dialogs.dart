import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/theme.dart';

// Confirmation avant une action (ConfirmDialog du site) : true si l'utilisateur confirme.
// danger : bouton rouge (supprimer, annuler une facture).
Future<bool> confirmAction({
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
  Widget? extra,
}) async {
  final ok = await Get.dialog<bool>(
    AlertDialog(
      backgroundColor: KfColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KfRadius.lg)),
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: const TextStyle(fontSize: 14, height: 20 / 14, color: KfColors.inkSoft)),
        ?extra,
      ]),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          style: TextButton.styleFrom(foregroundColor: KfColors.inkMuted),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Get.back(result: true),
          style: FilledButton.styleFrom(
            backgroundColor: danger ? KfColors.danger : KfColors.brand,
            minimumSize: const Size(0, 40),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

// Message bref en bas de l'écran (succès ou erreur)
void showNotice(String message, {bool error = false}) {
  final context = Get.context;
  if (context == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? KfColors.danger : KfColors.ink,
      duration: Duration(seconds: error ? 6 : 4),
    ));
}
