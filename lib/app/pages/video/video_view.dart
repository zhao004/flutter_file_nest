import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';

/// 沉浸式视频预览：全屏播放，控件以渐变浮层叠加，播放时自动隐藏。
///
/// 退出或进入后台时暂停；错误态提供重试与“用其他应用打开”。控件显隐由点击
/// 切换，拖动进度条期间保持可见。
class VideoView extends StatefulWidget {
  const VideoView({required this.entry, super.key});
  final StorageEntry entry;
  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> with WidgetsBindingObserver {
  /// 播放中控件自动隐藏前的等待时间。
  static const _autoHideDuration = Duration(seconds: 3);

  late VideoPlayerController _player;
  Timer? _hideTimer;
  bool _ready = false;
  bool _controlsVisible = true;
  bool _scrubbing = false;
  bool _muted = false;
  bool _wasPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = _createPlayer();
    _initialize();
  }

  VideoPlayerController _createPlayer() {
    final player = VideoPlayerController.contentUri(
      Uri.parse(widget.entry.uri),
    );
    player.addListener(_updated);
    return player;
  }

  Future<void> _initialize() async {
    try {
      await _player.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      _scheduleHide();
    } catch (_) {
      if (mounted) {
        setState(() => _error = '无法播放此视频，文件可能已移动或格式不受支持');
      }
    }
  }

  /// 播放器值变化：只处理错误、播放状态切换与自动隐藏，避免逐帧重建页面。
  void _updated() {
    if (!mounted) return;
    final value = _player.value;
    if (value.hasError && _error == null) {
      setState(() => _error = '视频播放失败');
      _cancelHide();
      return;
    }
    final playing = value.isPlaying;
    if (playing == _wasPlaying) return;
    _wasPlaying = playing;
    if (playing) {
      _scheduleHide();
    } else {
      // 暂停或播放结束时保持控件可见。
      _cancelHide();
      if (!_controlsVisible) setState(() => _controlsVisible = true);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_ready || _error != null || _scrubbing) return;
    _hideTimer = Timer(_autoHideDuration, () {
      if (mounted && _player.value.isPlaying && !_scrubbing) {
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
    final value = _player.value;
    try {
      if (value.isPlaying) {
        await _player.pause();
      } else {
        if (value.isCompleted) await _player.seekTo(Duration.zero);
        await _player.play();
      }
      _scheduleHide();
    } catch (_) {
      if (mounted) setState(() => _error = '视频播放失败');
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    try {
      await _player.setVolume(next ? 0 : 1);
      if (mounted) setState(() => _muted = next);
    } catch (_) {
      // 静音失败不影响正常播放。
    }
  }

  /// 重新创建播放器再试一次；失败时保持错误态。
  Future<void> _retry() async {
    _cancelHide();
    _player.removeListener(_updated);
    _player.dispose().catchError((_) {});
    if (!mounted) return;
    setState(() {
      _error = null;
      _ready = false;
      _wasPlaying = false;
    });
    _player = _createPlayer();
    await _initialize();
  }

  void _openExternally() => Get.find<StorageGateway>().openFile(widget.entry);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _player.pause();
    _cancelHide();
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _player.removeListener(_updated);
    // 平台未就绪时清理可能抛错，忽略。
    _player.dispose().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _player,
      builder: (context, value, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _ready && _error == null ? _toggleControls : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _videoLayer(value),
            if (_ready && _error == null) _controls(value),
          ],
        ),
      ),
    ),
  );

  Widget _videoLayer(VideoPlayerValue value) {
    if (_error != null) return _errorBody();
    if (!_ready) {
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
    return Center(
      child: AspectRatio(
        aspectRatio: value.aspectRatio,
        child: VideoPlayer(_player),
      ),
    );
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

  Widget _controls(VideoPlayerValue value) => AnimatedOpacity(
    opacity: _controlsVisible ? 1 : 0,
    duration: const Duration(milliseconds: 200),
    child: IgnorePointer(
      ignoring: !_controlsVisible,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(alignment: Alignment.topCenter, child: _topBar()),
          Center(child: _playButton(value)),
          Align(alignment: Alignment.bottomCenter, child: _bottomBar(value)),
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

  Widget _playButton(VideoPlayerValue value) => Material(
    color: Colors.black45,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: _togglePlay,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          value.isCompleted
              ? Icons.replay
              : value.isPlaying
              ? Icons.pause
              : Icons.play_arrow,
          size: 44,
          color: Colors.white,
        ),
      ),
    ),
  );

  /// 底部渐变栏：进度条、时间、静音与媒体信息。
  Widget _bottomBar(VideoPlayerValue value) => DecoratedBox(
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
            Listener(
              onPointerDown: (_) {
                _scrubbing = true;
                _cancelHide();
                if (!_controlsVisible) setState(() => _controlsVisible = true);
              },
              onPointerUp: (_) {
                _scrubbing = false;
                _scheduleHide();
              },
              onPointerCancel: (_) {
                _scrubbing = false;
                _scheduleHide();
              },
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Theme.of(context).colorScheme.primary,
                  overlayColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                ),
                child: VideoProgressIndicator(
                  _player,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  colors: VideoProgressColors(
                    playedColor: Theme.of(context).colorScheme.primary,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  formatPlaybackTime(value.position),
                  style: const TextStyle(color: Colors.white),
                ),
                const Text(' / ', style: TextStyle(color: Colors.white54)),
                Text(
                  formatPlaybackTime(value.duration),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '${value.size.width.toInt()} × ${value.size.height.toInt()}'
                  '  ·  ${formatBytes(widget.entry.size)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
