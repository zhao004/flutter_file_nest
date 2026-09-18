import 'package:flutter/services.dart';

import '../models/incoming_share.dart';

/// 外部应用“打开方式/分享”事件来源；测试通过替代实现注入。
abstract interface class IncomingShareGateway {
  /// 每次事件为一批待保存文件，按到达顺序推送。
  Stream<List<IncomingShare>> get shares;
}

/// `filenest/incoming` 事件通道封装。
class IncomingShareService implements IncomingShareGateway {
  const IncomingShareService();

  static const channel = EventChannel('filenest/incoming');

  @override
  Stream<List<IncomingShare>> get shares =>
      channel.receiveBroadcastStream().map(_parse);

  List<IncomingShare> _parse(Object? event) {
    if (event is! List) return const [];
    return [
      for (final item in event)
        if (item is Map) IncomingShare.fromMap(item.cast<Object?, Object?>()),
    ];
  }
}
