import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';

/// 沉浸式视频预览：全屏播放，控件以渐变浮层叠加，播放时自动隐藏。
///
/// 底层使用 media_kit（libmpv），支持 SAF `content://` 内容；退出或进入后台时
/// 暂停；错误态提供重试与“用其他应用打开”。控件显隐由点击切换，拖动进度条期间
/// 保持可见。
class VideoView extends StatefulWidget {
  const VideoView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> with WidgetsBindingObserver {
  /// 播放中控件自动隐藏前的等待时间。
  static const _autoHideDuration = Duration(seconds: 3);

  Player? _player;
  VideoController? _videoController;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Timer? _hideTimer;
  bool _ready = false;
  bool _controlsVisible = true;
  bool _scrubbing = false;
  bool _muted = false;
  bool _wasPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;

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
      await player.open(Media(widget.entry.uri), play: true);
      if (!mounted) return;
      setState(() => _ready = true);
      _scheduleHide();
    } catch (_) {
      if (mounted) {
        setState(() => _error = '无法播放此视频，文件可能已移动或格式不受支持');
      }
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
    }
    // 暂停或播放结束时保持控件可见，并刷新播放/暂停图标。
    setState(() {
      if (!playing) _controlsVisible = true;
    });
  }

  void _onCompleted(bool completed) {
    if (!mounted || !completed) return;
    _cancelHide();
    setState(() => _controlsVisible = true);
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

  /// 重新创建播放器再试一次；失败时保持错误态。
  Future<void> _retry() async {
    _cancelHide();
    await _teardownPlayer();
    if (!mounted) return;
    setState(() {
      _error = null;
      _ready = false;
      _wasPlaying = false;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _player?.pause();
    _cancelHide();
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _player?.dispose().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _ready && _error == null ? _toggleControls : null,
      child: Stack(
        fit: StackFit.expand,
        children: [_videoLayer(), if (_ready && _error == null) _controls()],
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

  /// 顶部渐变栏：返回、文件名与外部打开。
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
