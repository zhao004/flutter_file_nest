/// 单个镜头经探测得到的参数能力快照。
///
/// “未探测/探测失败”由控制器持有 null 能力表示；本对象内为 false 的字段
/// 表示“已探测但设备不支持”，两者语义不同，不得混用。
class LensCapabilities {
  const LensCapabilities({
    required this.zoomMin,
    required this.zoomMax,
    required this.exposureOffsetMin,
    required this.exposureOffsetMax,
    required this.exposureOffsetStep,
    required this.exposurePointSupported,
    required this.focusPointSupported,
    required this.torchSupported,
  });

  /// 连续变焦范围（倍率），探测失败时为 1..1。
  final double zoomMin;
  final double zoomMax;

  /// 曝光补偿范围与步长（EV 单位）；不支持时范围为 0..0。
  final double exposureOffsetMin;
  final double exposureOffsetMax;

  /// 曝光补偿步长；0 表示设备接受任意连续值。
  final double exposureOffsetStep;

  /// 是否支持点按测光（自动曝光区域）。
  final bool exposurePointSupported;

  /// 是否支持点按对焦（自动对焦区域）。
  final bool focusPointSupported;

  /// 是否支持持续补光；前摄通常为 false。
  final bool torchSupported;

  /// 设备是否提供可用的曝光补偿范围。
  bool get hasExposureOffset => exposureOffsetMax > exposureOffsetMin;
}

/// 参数应用失败的结构化原因，用于区分设备能力与运行状态问题。
enum ParameterApplyFailure {
  /// 当前镜头未提供该能力。
  unsupported,

  /// 请求值超出设备允许范围。
  outOfRange,

  /// 相机会话已关闭或尚未初始化。
  sessionClosed,

  /// 设备拒绝了本次设置。
  deviceRejected,
}

/// 单次参数应用结果：成功时携带后端已接受的实际值，失败时携带结构化原因。
///
/// “请求值”与“实际生效值”必须区分展示，不得把请求值冒充生效值。
class ParameterApplyResult {
  const ParameterApplyResult.accepted(this.acceptedValue) : failure = null;
  const ParameterApplyResult.failed(this.failure) : acceptedValue = null;

  /// 后端实际接受的值；曝光补偿为取整后的 EV，补光灯为 1/0 表示开/关。
  final double? acceptedValue;
  final ParameterApplyFailure? failure;

  bool get ok => failure == null;
}
