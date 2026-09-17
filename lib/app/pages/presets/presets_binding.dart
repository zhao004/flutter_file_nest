import 'package:get/get.dart';

import '../../services/vault_store.dart';
import '../camera/app_camera_controller.dart';
import 'presets_controller.dart';

class PresetsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PresetsController>(
      () => PresetsController(
        camera: Get.find<AppCameraController>(),
        store: Get.find<VaultStore>(),
      ),
    );
  }
}
