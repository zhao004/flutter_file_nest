import 'camera_driver.dart';
import 'native_camera_driver.dart';

/// 相机后端可用性与选择策略。
///
/// 专业原生后端在应用启动时探测一次；仅当设备可用且用户在设置中显式开启时
/// 才使用，与插件后端互斥，避免两个会话争抢同一摄像头。
class CameraBackendResolver {
  const CameraBackendResolver({required this.proAvailable});

  /// 专业后端通道是否可用；不可用时设置项保持禁用。
  final bool proAvailable;

  /// 按用户偏好选择后端；参数不完整时回退插件后端。
  CameraDriver createDriver({required bool proEnabled}) =>
      proAvailable && proEnabled ? NativeCameraDriver() : PluginCameraDriver();
}
