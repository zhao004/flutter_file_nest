import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';
import '../../services/vault_store.dart';

/// 沉浸式视频预览：全屏播放，控件以渐变浮层叠加，播放时自动隐藏。
///
/// 底层使用 media_kit（libmpv），支持 SAF `content://` 内容；退出或进入后台时
/// 暂停并记录续播位置。手势：双击播放/暂停、左右滑快进快退、右侧上下滑音量、
/// 左侧上下滑亮度。错误态提供重试与“用其他应用打开”。
class VideoView extends StatefulWidget {
  const VideoView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> with WidgetsBindingObserver {
  /// 播放中控件自动隐藏前的等待时间。
  static const _autoHideDuration = Duration(seconds: 3);

  /// 可选倍速档位。
  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  /// 横向滑动跨越整屏宽度对应的快进/快退时长。
  static const _seekSpanSeconds = 120.0;

  /// 应用内亮度的下限，避免完全黑屏难以恢复。
  static const _minBrightness = 0.05;

  late final VaultStore _store = Get.find<VaultStore>();
  Player? _player;
  VideoController? _videoController;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Timer? _hideTimer;
  bool _ready = false;
  bool _controlsVisible = true;
  bool _scrubbing = false;
  bool _muted = false;
  bool _wasPlaying = false;
  bool _completed = false;
  double _speed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;

  // 手势状态：同一时刻只处理一种拖动模式。
  _DragMode _dragMode = _DragMode.none;
  double _brightness = 1.0;
  double _dragVolume = 1.0;
  Duration _dragStartPosition = Duration.zero;
  Duration? _dragSeekTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final player = Player();
      final controller = VideoController(player);
      _player = player;
      _videoController = controller;
      _subscriptions.addAll([
        player.stream.error.listen(_onError),
        player.stream.playing.listen(_onPlaying),
        player.stream.completed.listen(_onCompleted),
        player.stream.position.listen((value) {
          if (mounted && !_scrubbing) setState(() => _position = value);
        }),
        player.stream.duration.listen((value) {
          if (mounted && value != _duration) setState(() => _duration = value);
        }),
      ]);
      final resume = await _store.playbackPosition(widget.entry.uri);
      await player.open(Media(widget.entry.uri), play: true);
      if (resume != null && resume > Duration.zero) await player.seek(resume);
      _brightness = await _currentBrightness();
      if (!mounted) return;
      setState(() => _ready = true);
      _scheduleHide();
    } catch (_) {
      if (mounted) {
        setState(() => _error = '无法播放此视频，文件可能已移动或格式不受支持');
      }
    }
  }

  /// 读取当前应用亮度；平台不支持时返回 1.0（不改变系统亮度）。
  Future<double> _currentBrightness() async {
    try {
      return await ScreenBrightness.instance.application;
    } catch (_) {
      return 1.0;
    }
  }

  /// 播放器错误：忽略空消息，仅首次进入错误态。
  void _onError(String message) {
    if (!mounted || _error != null || message.trim().isEmpty) return;
    setState(() => _error = '视频播放失败');
    _cancelHide();
  }

  /// 只处理播放状态切换与自动隐藏，避免逐帧重建页面。
  void _onPlaying(bool playing) {
    if (!mounted || playing == _wasPlaying) return;
    _wasPlaying = playing;
    if (playing) {
      _scheduleHide();
    } else {
      _cancelHide();
      unawaited(_persistPosition());
    }
    // 暂停或播放结束时保持控件可见，并刷新播放/暂停图标。
    setState(() {
      if (!playing) _controlsVisible = true;
    });
  }

  void _onCompleted(bool completed) {
    if (!mounted || !completed) return;
    _completed = true;
    _cancelHide();
    setState(() {
      _controlsVisible = true;
      _position = _duration;
    });
    unawaited(
      _store.savePlaybackPosition(
        widget.entry.uri,
        Duration.zero,
        duration: _duration,
      ),
    );
  }

  /// 记录当前位置；播放结束或位置无效时跳过。
  Future<void> _persistPosition() async {
    if (_completed) return;
    final player = _player;
    if (player == null) return;
    final position = player.state.position;
    if (position <= Duration.zero) return;
    try {
      await _store.savePlaybackPosition(
        widget.entry.uri,
        position,
        duration: player.state.duration,
      );
    } catch (_) {
      /* 记录失败不影响播放。 */
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_ready || _error != null || _scrubbing) return;
    _hideTimer = Timer(_autoHideDuration, () {
      if (mounted && _player?.state.playing == true && !_scrubbing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _cancelHide() => _hideTimer?.cancel();

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    try {
      // 播放结束后再次点击从头重播。
      if (player.state.completed) {
        _completed = false;
        await player.seek(Duration.zero);
        await player.play();
      } else {
        await player.playOrPause();
      }
      _scheduleHide();
    } catch (_) {
      if (mounted) setState(() => _error = '视频播放失败');
    }
  }

  Future<void> _toggleMute() async {
    final player = _player;
    final next = !_muted;
    try {
      await player?.setVolume(next ? 0 : 100);
      if (mounted) setState(() => _muted = next);
    } catch (_) {
      // 静音失败不影响正常播放。
    }
  }

  Future<void> _setSpeed(double speed) async {
    _speed = speed;
    await _player?.setRate(speed);
    if (mounted) setState(() {});
  }

  /// 重新创建播放器再试一次；失败时保持错误态。
  Future<void> _retry() async {
    _cancelHide();
    await _teardownPlayer();
    if (!mounted) return;
    setState(() {
      _error = null;
      _ready = false;
      _wasPlaying = false;
      _completed = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    await _initialize();
  }

  /// 取消订阅并释放播放器；忽略平台未就绪时的清理异常。
  Future<void> _teardownPlayer() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    _videoController = null;
    await player?.dispose().catchError((_) {});
  }

  void _openExternally() => Get.find<StorageGateway>().openFile(widget.entry);

  // ---- 手势 ----

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!_ready || _error != null) return;
    _dragMode = _DragMode.seek;
    _dragStartPosition = _position;
    _dragSeekTarget = _position;
    _cancelHide();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_dragMode != _DragMode.seek) return;
    final width = context.size?.width ?? 1;
    final seconds = details.delta.dx / width * _seekSpanSeconds;
    final total = _duration.inMilliseconds;
    final next =
        _dragStartPosition + Duration(milliseconds: (seconds * 1000).round());
    _dragStartPosition = Duration(
      milliseconds: next.inMilliseconds.clamp(0, total > 0 ? total : 0),
    );
    setState(() => _dragSeekTarget = _dragStartPosition);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragMode != _DragMode.seek) return;
    final target = _dragSeekTarget;
    _dragMode = _DragMode.none;
    _dragSeekTarget = null;
    if (target != null) _player?.seek(target);
    setState(() => _position = target ?? _position);
    _scheduleHide();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (!_ready || _error != null) return;
    final width = context.size?.width ?? 1;
    final onRight = details.localPosition.dx >= width / 2;
    _dragMode = onRight ? _DragMode.volume : _DragMode.brightness;
    _dragVolume = (_player?.state.volume ?? 100) / 100;
    _cancelHide();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final height = context.size?.height ?? 1;
    final delta = -details.delta.dy / height;
    if (_dragMode == _DragMode.volume) {
      _dragVolume = (_dragVolume + delta).clamp(0.0, 1.0);
      _player?.setVolume(_dragVolume * 100);
      _muted = _dragVolume == 0;
    } else if (_dragMode == _DragMode.brightness) {
      _brightness = (_brightness + delta).clamp(_minBrightness, 1.0);
      unawaited(_applyBrightness(_brightness));
    } else {
      return;
    }
    setState(() {});
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _dragMode = _DragMode.none;
    setState(() {});
    _scheduleHide();
  }

  Future<void> _applyBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
    } catch (_) {
      /* 平台不支持时忽略。 */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _player?.pause();
    unawaited(_persistPosition());
    _cancelHide();
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    unawaited(_persistPosition());
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _player?.dispose().catchError((_) {});
    unawaited(_resetBrightness());
    super.dispose();
  }

  Future<void> _resetBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {
      /* 平台不支持时忽略。 */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _ready && _error == null ? _toggleControls : null,
      onDoubleTap: _ready && _error == null ? _togglePlay : null,
      onHorizontalDragStart: _ready && _error == null
          ? _onHorizontalDragStart
          : null,
      onHorizontalDragUpdate: _ready && _error == null
          ? _onHorizontalDragUpdate
          : null,
      onHorizontalDragEnd: _ready && _error == null
          ? _onHorizontalDragEnd
          : null,
      onVerticalDragStart: _ready && _error == null
          ? _onVerticalDragStart
          : null,
      onVerticalDragUpdate: _ready && _error == null
          ? _onVerticalDragUpdate
          : null,
      onVerticalDragEnd: _ready && _error == null ? _onVerticalDragEnd : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _videoLayer(),
          if (_ready && _error == null) _controls(),
          if (_ready && _error == null && _dragMode != _DragMode.none)
            _gestureHud(),
        ],
      ),
    ),
  );

  Widget _videoLayer() {
    if (_error != null) return _errorBody();
    final controller = _videoController;
    if (!_ready || controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.entry.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
    return Video(controller: controller, controls: NoVideoControls);
  }

  Widget _errorBody() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _openExternally,
                icon: const Icon(Icons.open_in_new),
                label: const Text('用其他应用打开'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _controls() => AnimatedOpacity(
    opacity: _controlsVisible ? 1 : 0,
    duration: const Duration(milliseconds: 200),
    child: IgnorePointer(
      ignoring: !_controlsVisible,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(alignment: Alignment.topCenter, child: _topBar()),
          Center(child: _playButton()),
          Align(alignment: Alignment.bottomCenter, child: _bottomBar()),
        ],
      ),
    ),
  );

  /// 拖动反馈浮层：快进时间或音量/亮度百分比。
  Widget _gestureHud() {
    final text = switch (_dragMode) {
      _DragMode.seek =>
        '${formatPlaybackTime(_dragSeekTarget ?? _position)}'
            ' / ${formatPlaybackTime(_duration)}',
      _DragMode.volume => '音量 ${(_dragVolume * 100).round()}%',
      _DragMode.brightness => '亮度 ${(_brightness * 100).round()}%',
      _DragMode.none => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();
    final icon = switch (_dragMode) {
      _DragMode.seek =>
        _dragSeekTarget != null && _dragSeekTarget! > _position
            ? Icons.fast_forward
            : Icons.fast_rewind,
      _DragMode.volume => _dragVolume == 0 ? Icons.volume_off : Icons.volume_up,
      _DragMode.brightness => Icons.brightness_6,
      _DragMode.none => Icons.circle,
    };
    return Center(
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部渐变栏：返回、文件名、播放速度与外部打开。
  Widget _topBar() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black87, Colors.transparent],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            color: Colors.white,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              widget.entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          PopupMenuButton<double>(
            tooltip: '播放速度',
            iconColor: Colors.white,
            onSelected: _setSpeed,
            itemBuilder: (context) => [
              for (final speed in _speeds)
                PopupMenuItem(
                  value: speed,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: speed == _speed
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      Text('${_formatSpeed(speed)}x'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: '用其他应用打开',
            color: Colors.white,
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
    ),
  );

  Widget _playButton() {
    final player = _player;
    final completed = player?.state.completed ?? false;
    final playing = player?.state.playing ?? false;
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _togglePlay,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            completed
                ? Icons.replay
                : playing
                ? Icons.pause
                : Icons.play_arrow,
            size: 44,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// 底部渐变栏：进度条、时间、静音与媒体信息。
  Widget _bottomBar() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Colors.black87, Colors.transparent],
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 32, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _seekBar(),
            Row(
              children: [
                Text(
                  formatPlaybackTime(_position),
                  style: const TextStyle(color: Colors.white),
                ),
                const Text(' / ', style: TextStyle(color: Colors.white54)),
                Text(
                  formatPlaybackTime(_duration),
                  style: const TextStyle(color: Colors.white54),
                ),
                const Spacer(),
                IconButton(
                  tooltip: _muted ? '取消静音' : '静音',
                  color: Colors.white,
                  onPressed: _toggleMute,
                  icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  /// 可拖动进度条：拖动时暂停位置回写，松手后一次性 seek。
  Widget _seekBar() {
    final totalMs = _duration.inMilliseconds;
    final maxMs = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final valueMs = _position.inMilliseconds.clamp(0, totalMs).toDouble();
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: Theme.of(context).colorScheme.primary,
        inactiveTrackColor: Colors.white24,
        thumbColor: Theme.of(context).colorScheme.primary,
        overlayColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.2),
      ),
      child: Slider(
        min: 0,
        max: maxMs,
        value: valueMs,
        onChanged: totalMs > 0
            ? (value) => setState(
                () => _position = Duration(milliseconds: value.toInt()),
              )
            : null,
        onChangeStart: (_) {
          _scrubbing = true;
          _cancelHide();
          if (!_controlsVisible) setState(() => _controlsVisible = true);
        },
        onChangeEnd: (value) {
          _scrubbing = false;
          _player?.seek(Duration(milliseconds: value.toInt()));
          _scheduleHide();
        },
      ),
    );
  }
}

/// 手势拖动模式；同一时刻只生效一种。
enum _DragMode { none, seek, volume, brightness }

/// 倍速文案：整数不带小数，其余保留原始写法。
String _formatSpeed(double speed) =>
    speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : '$speed';
