import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import '../models/video_export_request.dart';

/// 视频编辑器宿主配置：只暴露页面逻辑所需的输入与回调，
/// 便于测试注入假实现而不依赖第三方重型组件。
class VideoEditorHostConfig {
  const VideoEditorHostConfig({
    required this.filePath,
    required this.pickClip,
    required this.onExport,
    required this.onClose,
    required this.onError,
    this.audioTracks = const [],
  });

  /// 待编辑视频的本地文件路径（已从 SAF 导出到缓存）。
  final String filePath;

  /// 选取一个视频片段并复制到缓存；取消返回 null。
  final Future<String?> Function() pickClip;

  /// 可叠加的背景音轨（设备选取的本地文件）。
  final List<VideoAudioTrackSpec> audioTracks;

  /// 导出回调：编辑器完成时回传渲染请求，页面据此渲染并保存。
  final Future<void> Function(VideoExportRequest request) onExport;

  /// 用户关闭编辑器。
  final VoidCallback onClose;

  /// 初始化失败（不支持的文件、解码失败等）。
  final ValueChanged<String> onError;
}

/// 视频编辑器构建器；测试可替换为假实现。
typedef VideoEditorBuilder = Widget Function(VideoEditorHostConfig config);

/// 默认宿主：pro_image_editor 的视频编辑器 + pro_video_editor 引擎。
Widget buildProVideoEditor(VideoEditorHostConfig config) =>
    _ProVideoEditorHost(config: config);

class _ProVideoEditorHost extends StatefulWidget {
  const _ProVideoEditorHost({required this.config});

  final VideoEditorHostConfig config;

  @override
  State<_ProVideoEditorHost> createState() => _ProVideoEditorHostState();
}

class _ProVideoEditorHostState extends State<_ProVideoEditorHost> {
  static const int _thumbnailCount = 10;
  static const Duration _minTrimDuration = Duration(seconds: 1);

  final _editorKey = GlobalKey<ProImageEditorState>();
  final _audioPlayer = audio.AudioPlayer();

  late EditorVideo _video = EditorVideo.file(widget.config.filePath);
  VideoPlayerController? _videoController;
  ProVideoController? _proVideoController;
  List<ImageProvider>? _thumbnails;
  late VideoMetadata _metadata;

  List<AudioTrack> _audioTracks = const [];
  List<VideoClip> _clips = const [];

  TrimDurationSpan? _durationSpan;
  TrimDurationSpan? _tempDurationSpan;
  bool _isSeeking = false;
  bool _failed = false;

  final Map<String, Uint8List> _cachedKeyFrames = {};
  final Map<String, List<Uint8List>> _cachedKeyFrameList = {};

  static const VideoEditorConfigs _videoEditorConfigs = VideoEditorConfigs(
    initialMuted: false,
    initialPlay: false,
    isAudioSupported: true,
    minTrimDuration: _minTrimDuration,
    playTimeSmoothingDuration: Duration(milliseconds: 600),
  );

  /// 编辑器配置：在音轨与片段解析完成后构建，合并片段后重建。
  late ProImageEditorConfigs _configs;

  ProImageEditorConfigs _buildConfigs() => ProImageEditorConfigs(
    mainEditor: MainEditorConfigs(
      tools: const [
        SubEditorMode.videoClips,
        SubEditorMode.audio,
        SubEditorMode.paint,
        SubEditorMode.text,
        SubEditorMode.cropRotate,
        SubEditorMode.tune,
        SubEditorMode.filter,
        SubEditorMode.blur,
        SubEditorMode.emoji,
      ],
      widgets: MainEditorWidgets(
        removeLayerArea:
            (removeAreaKey, editor, rebuildStream, isLayerBeingTransformed) =>
                VideoEditorRemoveArea(
                  removeAreaKey: removeAreaKey,
                  editor: editor,
                  rebuildStream: rebuildStream,
                  isLayerBeingTransformed: isLayerBeingTransformed,
                ),
      ),
    ),
    paintEditor: const PaintEditorConfigs(
      tools: [
        PaintMode.freeStyle,
        PaintMode.arrow,
        PaintMode.line,
        PaintMode.rect,
        PaintMode.circle,
        PaintMode.dashLine,
        PaintMode.polygon,
        PaintMode.eraser,
      ],
    ),
    audioEditor: AudioEditorConfigs(audioTracks: _audioTracks),
    clipsEditor: ClipsEditorConfigs(clips: _clips),
    videoEditor: _videoEditorConfigs,
    imageGeneration: const ImageGenerationConfigs(
      captureImageByteFormat: ImageByteFormat.rawStraightRgba,
    ),
  );

  late final ProImageEditorCallbacks _callbacks = ProImageEditorCallbacks(
    onCompleteWithParameters: _onComplete,
    onCloseEditor: (mode) => widget.config.onClose(),
    videoEditorCallbacks: VideoEditorCallbacks(
      onPause: _pause,
      onPlay: _play,
      onMuteToggle: (isMuted) => _videoController?.setVolume(isMuted ? 0 : 100),
      onTrimSpanUpdate: (span) {
        if (_videoController?.value.isPlaying ?? false) {
          _proVideoController?.pause();
        }
      },
      onTrimSpanEnd: _seekToPosition,
    ),
    audioEditorCallbacks: AudioEditorCallbacks(
      onPlay: _playAudio,
      onStop: (track) => _audioPlayer.pause(),
      onMuteToggle: (isMuted) => _audioPlayer.setVolume(isMuted ? 0 : 1),
      onStartTimeChange: (startTime) async {
        if (_audioPlayer.state == audio.PlayerState.playing) {
          await _audioPlayer.seek(startTime);
        }
      },
    ),
    clipsEditorCallbacks: ClipsEditorCallbacks(
      onReadKeyFrame: _readKeyFrame,
      onReadKeyFrames: _readKeyFrames,
      onAddClip: _addClip,
      onMergeClips: _mergeClips,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onDurationChange);
    _videoController?.dispose();
    _proVideoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _audioTracks = await _buildAudioTracks();
      _metadata = await ProVideoEditor.instance.getMetadata(_video);
      _clips = [
        VideoClip(
          id: 'initial',
          title: _basename(widget.config.filePath),
          clip: EditorVideoClip.file(widget.config.filePath),
          duration: _metadata.duration,
        ),
      ];
      _configs = _buildConfigs();

      _videoController = VideoPlayerController.file(
        File(widget.config.filePath),
      );
      await Future.wait([
        _videoController!.initialize(),
        _videoController!.setLooping(false),
        _videoController!.setVolume(_videoEditorConfigs.initialMuted ? 0 : 100),
      ]);
      if (!mounted) return;

      _proVideoController = ProVideoController(
        videoPlayer: _buildVideoPlayer(),
        initialResolution: _metadata.resolution,
        videoDuration: _metadata.duration,
        fileSize: _metadata.fileSize,
        bitrate: _metadata.bitrate,
        thumbnails: _thumbnails,
      );
      _videoController!.addListener(_onDurationChange);
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _generateThumbnails(),
      );
    } catch (error) {
      if (!mounted) return;
      _failed = true;
      setState(() {});
      widget.config.onError('无法在此视频上启动编辑，可能是格式不受支持');
    }
  }

  Future<List<AudioTrack>> _buildAudioTracks() async {
    final tracks = <AudioTrack>[];
    for (final spec in widget.config.audioTracks) {
      var duration = Duration.zero;
      try {
        final meta = await ProVideoEditor.instance.getMetadata(
          EditorVideo.file(spec.path),
        );
        duration = meta.duration;
      } catch (_) {
        // 无法读取时长时仍保留音轨，后续由编辑器按整段处理。
      }
      tracks.add(
        AudioTrack(
          id: spec.path,
          title: _basename(spec.path),
          subtitle: '',
          duration: duration,
          audio: EditorAudio.file(spec.path),
          volume: spec.volume,
          loop: spec.loop,
        ),
      );
    }
    return tracks;
  }

  Future<void> _generateThumbnails({bool updateClip = true}) async {
    try {
      final width =
          MediaQuery.sizeOf(context).width /
          _thumbnailCount *
          MediaQuery.devicePixelRatioOf(context);
      final list = await ProVideoEditor.instance.getKeyFrames(
        KeyFramesConfigs(
          video: _video,
          outputSize: Size.square(width),
          boxFit: ThumbnailBoxFit.cover,
          maxOutputFrames: _thumbnailCount,
          outputFormat: ThumbnailFormat.jpeg,
        ),
      );
      if (!mounted || list.isEmpty) return;
      final providers = list.map<ImageProvider>(MemoryImage.new).toList();
      await Future.wait(providers.map((item) => precacheImage(item, context)));
      if (!mounted) return;
      _thumbnails = providers;
      _proVideoController?.thumbnails = providers;
      if (updateClip && _clips.isNotEmpty) {
        _clips[0] = _clips.first.copyWith(
          image: EditorImage.memory(list.first),
          thumbnails: providers,
          duration: _metadata.duration,
        );
        setState(() {});
      }
    } catch (_) {
      // 缩略图失败不影响编辑主流程。
    }
  }

  void _onDurationChange() {
    final controller = _videoController;
    final proController = _proVideoController;
    if (controller == null || proController == null) return;
    final total = _metadata.duration;
    final position = controller.value.position;
    proController.setPlayTime(position);

    if (_durationSpan != null && position >= _durationSpan!.end) {
      _seekToPosition(_durationSpan!);
    } else if (position >= total) {
      _seekToPosition(TrimDurationSpan(start: Duration.zero, end: total));
    }
  }

  Future<void> _seekToPosition(TrimDurationSpan span) async {
    _durationSpan = span;
    if (_isSeeking) {
      _tempDurationSpan = span;
      return;
    }
    _isSeeking = true;
    _proVideoController?.pause();
    _proVideoController?.setPlayTime(span.start);
    await _videoController?.pause();
    await _videoController?.seekTo(span.start);
    _isSeeking = false;
    final pending = _tempDurationSpan;
    if (pending != null) {
      _tempDurationSpan = null;
      await _seekToPosition(pending);
    }
  }

  Future<void> _play() async {
    await _videoController?.play();
  }

  Future<void> _pause() async {
    await _videoController?.pause();
  }

  Future<void> _playAudio(AudioTrack track) async {
    final path = track.audio.file?.path;
    if (path == null) return;
    await _audioPlayer.setReleaseMode(audio.ReleaseMode.loop);
    await _audioPlayer.play(
      audio.DeviceFileSource(path),
      position: track.startTime ?? Duration.zero,
    );
    await _audioPlayer.setVolume(track.volume);
  }

  Future<Uint8List> _readKeyFrame(VideoClip source) async {
    final cached = _cachedKeyFrames[source.id];
    if (cached != null) return cached;
    final frames = await _keyFrames(source, 1);
    _cachedKeyFrames[source.id] = frames.first;
    return frames.first;
  }

  Future<List<Uint8List>> _readKeyFrames(VideoClip source) async {
    final cached = _cachedKeyFrameList[source.id];
    if (cached != null) return cached;
    final frames = await _keyFrames(source, _thumbnailCount);
    _cachedKeyFrameList[source.id] = frames;
    return frames;
  }

  Future<List<Uint8List>> _keyFrames(VideoClip source, int count) =>
      ProVideoEditor.instance.getKeyFrames(
        KeyFramesConfigs(
          video: EditorVideo.autoSource(
            assetPath: source.clip.assetPath,
            byteArray: source.clip.bytes,
            file: source.clip.file,
            networkUrl: source.clip.networkUrl,
          ),
          outputSize: const Size.square(200),
          boxFit: ThumbnailBoxFit.cover,
          maxOutputFrames: count,
          outputFormat: ThumbnailFormat.jpeg,
        ),
      );

  Future<VideoClip?> _addClip() async {
    try {
      final path = await widget.config.pickClip();
      if (path == null) return null;
      final meta = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(path),
      );
      return VideoClip(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _basename(path),
        clip: EditorVideoClip.file(path),
        duration: meta.duration,
      );
    } catch (_) {
      return null;
    }
  }

  /// 合并片段为单个文件后重载播放器，使预览与后续导出基于合并结果。
  Future<void> _mergeClips(
    List<VideoClip> clips,
    void Function(double progress) onProgress,
  ) async {
    final paths = clips
        .map((clip) => clip.clip.file?.path)
        .whereType<String>()
        .toList();
    if (paths.isEmpty) return;
    final directory = await getTemporaryDirectory();
    final output =
        '${directory.path}/filenest_merge_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await ProVideoEditor.instance.renderVideoToFile(
      output,
      VideoRenderData(
        videoSegments: [
          for (final clip in clips)
            if (clip.clip.file?.path != null)
              VideoSegment(
                video: EditorVideo.file(clip.clip.file!.path),
                startTime: clip.trimSpan?.start,
                endTime: clip.trimSpan?.end,
              ),
        ],
        outputFormat: VideoOutputFormat.mp4,
        enableAudio: true,
      ),
    );
    if (!mounted) return;

    _video = EditorVideo.file(output);
    _metadata = await ProVideoEditor.instance.getMetadata(_video);
    _clips
      ..clear()
      ..add(
        VideoClip(
          id: 'merged',
          title: _basename(output),
          clip: EditorVideoClip.file(output),
          duration: _metadata.duration,
        ),
      );

    _videoController?.removeListener(_onDurationChange);
    await _videoController?.dispose();
    final controller = VideoPlayerController.file(File(output));
    await controller.initialize();
    await controller.setLooping(false);
    _videoController = controller;
    controller.addListener(_onDurationChange);

    _proVideoController?.dispose();
    _proVideoController = ProVideoController(
      videoPlayer: _buildVideoPlayer(),
      initialResolution: _metadata.resolution,
      videoDuration: _metadata.duration,
      fileSize: _metadata.fileSize,
      bitrate: _metadata.bitrate,
      thumbnails: _thumbnails,
    );
    if (!mounted) return;
    _editorKey.currentState?.initializeVideoEditor();
    await _generateThumbnails(updateClip: false);
    if (!mounted) return;
    setState(() {});
  }

  /// 把编辑器回传的完整参数转换为渲染请求并交给页面。
  Future<void> _onComplete(CompleteParameters parameters) async {
    final clips = parameters.videoClips;
    final specs = <VideoClipSpec>[];
    for (final clip in clips) {
      final path = clip.clip.file?.path;
      if (path == null) continue;
      specs.add(
        VideoClipSpec(
          path: path,
          startTime: clip.trimSpan?.start,
          endTime: clip.trimSpan?.end,
        ),
      );
    }
    if (specs.isEmpty) {
      specs.add(VideoClipSpec(path: widget.config.filePath));
    }

    final audioTracks = <VideoAudioTrackSpec>[];
    for (final track in parameters.audioTracks) {
      final path = track.audio.file?.path;
      if (path == null) continue;
      audioTracks.add(
        VideoAudioTrackSpec(
          path: path,
          volume: track.volume,
          loop: track.loop,
          audioStartTime: track.audioStartTime,
          audioEndTime: track.audioEndTime,
          startTime: track.startTime,
          endTime: track.endTime,
        ),
      );
    }

    await widget.config.onExport(
      VideoExportRequest(
        clips: specs,
        useSegments: specs.length > 1,
        startTime: parameters.startTime,
        endTime: parameters.endTime,
        blur: parameters.blur,
        colorMatrix: parameters.colorFiltersCombined,
        layersImage: parameters.image,
        hasLayers: parameters.layers.isNotEmpty,
        transform: parameters.isTransformed
            ? VideoExportTransform(
                width: parameters.cropWidth,
                height: parameters.cropHeight,
                rotateTurns: 4 - parameters.rotateTurns,
                x: parameters.cropX,
                y: parameters.cropY,
                flipX: parameters.flipX,
                flipY: parameters.flipY,
              )
            : null,
        enableAudio: _proVideoController?.isAudioEnabled ?? true,
        bitrate: _metadata.bitrate,
        audioTracks: audioTracks,
      ),
    );
  }

  Widget _buildVideoPlayer() => Center(
    child: AspectRatio(
      aspectRatio: _videoController?.value.size.aspectRatio ?? 16 / 9,
      child: _videoController == null
          ? const SizedBox.shrink()
          : VideoPlayer(_videoController!),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(child: CircularProgressIndicator());
    }
    final controller = _proVideoController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ProImageEditor.video(
      controller,
      key: _editorKey,
      callbacks: _callbacks,
      configs: _configs,
    );
  }
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final name = normalized.substring(normalized.lastIndexOf('/') + 1);
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}
