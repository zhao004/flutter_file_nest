import 'dart:async';

import 'package:flutter/material.dart';

import '../../di/injector.dart';

import 'package:media_kit/media_kit.dart';

import '../../i18n/app_l10n.dart';
import '../../localization.dart';
import '../../models/storage_entry.dart';
import '../../services/saf_storage.dart';
import '../../services/vault_store.dart';
import 'preview_widgets.dart';

/// 音频播放器：唱片式界面，支持播放、进度、快进快退、倍速与续播。
///
/// 使用 media_kit 直接读取 SAF `content://`；离开页面或暂停时记录播放
/// 位置，下次打开自动续播。播放结束时清除续播位置。
class AudioPreviewView extends StatefulWidget {
  const AudioPreviewView({required this.entry, super.key});

  final StorageEntry entry;

  @override
  State<AudioPreviewView> createState() => _AudioPreviewViewState();
}

class _AudioPreviewViewState extends State<AudioPreviewView>
    with WidgetsBindingObserver {
  /// 可选倍速档位。
  static const _speeds = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  /// 快进快退步长。
  static const _step = Duration(seconds: 10);

  late final VaultStore _store = getIt<VaultStore>();
  Player? _player;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _ready = false;
  bool _playing = false;
  bool _muted = false;
  bool _scrubbing = false;
  bool _completed = false;
  double _speed = 1.0;
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
      _player = player;
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
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = AppL10n.current.audioCannotPlay);
    }
  }

  void _onError(String message) {
    if (!mounted || _error != null || message.trim().isEmpty) return;
    setState(() => _error = AppL10n.current.audioPlayFailed);
  }

  void _onPlaying(bool playing) {
    if (!mounted) return;
    setState(() => _playing = playing);
    // 暂停即记录进度，避免进程被回收时丢失。
    if (!playing) unawaited(_persistPosition());
  }

  void _onCompleted(bool completed) {
    if (!mounted || !completed) return;
    _completed = true;
    setState(() {
      _playing = false;
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

  /// 保存当前位置；播放结束或位置无效时跳过。
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

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    try {
      if (player.state.completed) {
        _completed = false;
        await player.seek(Duration.zero);
        await player.play();
      } else {
        await player.playOrPause();
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppL10n.current.audioPlayFailed);
    }
  }

  Future<void> _seekBy(Duration delta) async {
    final player = _player;
    if (player == null) return;
    final target = player.state.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    await player.seek(clamped);
    if (mounted) setState(() => _position = clamped);
  }

  Future<void> _setSpeed(double speed) async {
    _speed = speed;
    await _player?.setRate(speed);
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _player?.setVolume(next ? 0 : 100);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _retry() async {
    await _teardown();
    if (!mounted) return;
    setState(() {
      _error = null;
      _ready = false;
      _completed = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    await _initialize();
  }

  Future<void> _teardown() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    await player?.dispose().catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _player?.pause();
    unawaited(_persistPosition());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_persistPosition());
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _player?.dispose().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.entry.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        PopupMenuButton<double>(
          tooltip: context.l10n.audioSpeed,
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
          tooltip: context.l10n.commonOpenExternal,
          onPressed: () => getIt<StorageGateway>().openFile(widget.entry),
          icon: const Icon(Icons.open_in_new),
        ),
      ],
    ),
    body: SafeArea(child: _body()),
  );

  Widget _body() {
    if (_error != null) {
      return PreviewErrorView(
        entry: widget.entry,
        message: _error!,
        icon: Icons.music_off_outlined,
        onRetry: _retry,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            Icons.music_note,
            size: 96,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            widget.entry.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (!_ready) const CircularProgressIndicator(),
          const Spacer(),
          _seekBar(),
          Row(
            children: [
              Text(_format(_position)),
              const Text(' / '),
              Text(_format(_duration)),
              const Spacer(),
              IconButton(
                tooltip: _muted
                    ? context.l10n.audioUnmute
                    : context.l10n.audioMute,
                onPressed: _toggleMute,
                icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: context.l10n.audioBack10,
                iconSize: 32,
                onPressed: _ready ? () => _seekBy(-_step) : null,
                icon: const Icon(Icons.replay_10),
              ),
              const SizedBox(width: 16),
              IconButton.filled(
                tooltip: _playing
                    ? context.l10n.audioPause
                    : context.l10n.audioPlay,
                iconSize: 40,
                onPressed: _ready ? _togglePlay : null,
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: context.l10n.audioForward10,
                iconSize: 32,
                onPressed: _ready ? () => _seekBy(_step) : null,
                icon: const Icon(Icons.forward_10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seekBar() {
    final totalMs = _duration.inMilliseconds;
    final maxMs = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final valueMs = _position.inMilliseconds.clamp(0, totalMs).toDouble();
    return Slider(
      min: 0,
      max: maxMs,
      value: valueMs,
      onChanged: totalMs > 0
          ? (value) => setState(
              () => _position = Duration(milliseconds: value.toInt()),
            )
          : null,
      onChangeStart: (_) => _scrubbing = true,
      onChangeEnd: (value) {
        _scrubbing = false;
        _player?.seek(Duration(milliseconds: value.toInt()));
      },
    );
  }
}

/// 播放时间的 MM:SS / H:MM:SS 展示。
String _format(Duration value) {
  final total = value.inSeconds < 0 ? 0 : value.inSeconds;
  String two(int part) => part.toString().padLeft(2, '0');
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}

/// 倍速文案：整数不带小数，其余保留两位有效位。
String _formatSpeed(double speed) =>
    speed == speed.roundToDouble() ? speed.toStringAsFixed(0) : '$speed';
