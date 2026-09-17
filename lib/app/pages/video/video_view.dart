import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/storage_entry.dart';

/// 直接播放 SAF 内容 URI，退出或进入后台时释放/暂停播放器。
class VideoView extends StatefulWidget {
  const VideoView({required this.entry, super.key});
  final StorageEntry entry;
  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> with WidgetsBindingObserver {
  late final VideoPlayerController _player;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = VideoPlayerController.contentUri(Uri.parse(widget.entry.uri));
    _player.addListener(_updated);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _player.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _error = '无法播放此视频，文件可能已移动或格式不受支持');
    }
  }

  void _updated() {
    if (mounted) {
      setState(() {
        if (_player.value.hasError) _error = '视频播放失败';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _player.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.removeListener(_updated);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _player.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _error != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : !_ready
                    ? const CircularProgressIndicator()
                    : AspectRatio(
                        aspectRatio: value.aspectRatio,
                        child: VideoPlayer(_player),
                      ),
              ),
            ),
            if (_ready && _error == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      _player,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: value.isPlaying ? '暂停' : '播放',
                          color: Colors.white,
                          icon: Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          onPressed: () async {
                            try {
                              if (value.isPlaying) {
                                await _player.pause();
                              } else {
                                if (value.isCompleted) {
                                  await _player.seekTo(Duration.zero);
                                }
                                await _player.play();
                              }
                            } catch (_) {
                              if (mounted) setState(() => _error = '视频播放失败');
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            '${formatDuration(value.position)} / ${formatDuration(value.duration)}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${value.size.width.toInt()} × ${value.size.height.toInt()}  ·  ${formatBytes(widget.entry.size)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
