import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

// « Masquer les montants » (comme les applications bancaires) : les montants affichés deviennent
// « ••••• USD » quand on montre son téléphone. Choix mémorisé ; les formulaires restent lisibles.
class Privacy extends GetxService {
  static Privacy get to => Get.find();
  static const _key = 'kf_hide_amounts';

  final hidden = false.obs;

  Privacy init() {
    hidden.value = GetStorage().read<bool>(_key) ?? false;
    return this;
  }

  void toggle() {
    hidden.value = !hidden.value;
    GetStorage().write(_key, hidden.value);
  }
}
