import 'package:get/get.dart';

import 'home_controller.dart';
import '../../services/archive_service.dart';
import '../../services/incoming_share_service.dart';
import '../../services/saf_storage.dart';
import '../../services/thumbnail_service.dart';
import '../../services/vault_store.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(
      () => HomeController(
        storage: Get.find<StorageGateway>(),
        store: Get.find<VaultStore>(),
        archive: Get.find<ArchiveGateway>(),
        thumbnails: Get.find<ThumbnailGateway>(),
        incoming: Get.find<IncomingShareGateway>(),
      ),
    );
  }
}
