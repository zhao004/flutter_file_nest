import 'dart:ui' show Locale;

import 'package:pro_image_editor/pro_image_editor.dart';

import '../i18n/app_l10n.dart';

/// 编辑器打开时的界面语言。
///
/// pro_image_editor 不随 `Localizations` 自动翻译，需显式传入 [I18n]；语言在
/// 打开编辑器时解析一次，打开期间切换应用语言不会实时刷新。
Locale editorLocale() => Locale(AppL10n.current.localeName);

/// 按语言返回编辑器文案；仅中文提供翻译，其余回落包内英文默认值。
I18n editorI18nFor(Locale locale) =>
    locale.languageCode == 'zh' ? kEditorI18nZh : const I18n();

/// Emoji 搜索数据按语言选择；不启用包内全量自动本地化（约增加 2MB 体积）。
List<CategoryEmoji> editorEmojiSet(Locale locale) =>
    locale.languageCode == 'zh' ? emojiSetChinese : emojiSetEnglish;

/// 简体中文编辑器文案。
///
/// 覆盖图片与视频编辑器暴露的全部子编辑器；音频编辑器随背景音乐功能移除，
/// 保持英文默认值不影响界面。滤镜预设名属品牌命名，保留英文。
const I18n kEditorI18nZh = I18n(
  cancel: '取消',
  undo: '撤销',
  redo: '重做',
  done: '完成',
  remove: '移除',
  doneLoadingMsg: '正在应用更改',
  importStateHistoryMsg: '正在初始化编辑器',
  various: I18nVarious(
    loadingDialogMsg: '请稍候…',
    closeEditorWarningTitle: '退出编辑器？',
    closeEditorWarningMessage: '退出后未保存的修改将丢失，确定退出吗？',
    closeEditorWarningConfirmBtn: '确定',
    closeEditorWarningCancelBtn: '取消',
  ),
  layerInteraction: I18nLayerInteraction(
    remove: '移除',
    edit: '编辑',
    rotateScale: '旋转缩放',
  ),
  paintEditor: I18nPaintEditor(
    bottomNavigationBarText: '画笔',
    moveAndZoom: '缩放',
    freestyle: '自由绘制',
    freestyleArrowStart: '自由箭头（起点）',
    freestyleArrowEnd: '自由箭头（终点）',
    freestyleArrowStartEnd: '自由箭头（双向）',
    arrow: '箭头',
    line: '直线',
    rectangle: '矩形',
    circle: '圆形',
    dashLine: '虚线',
    dashDotLine: '点划线',
    hexagon: '六边形',
    polygon: '多边形',
    blur: '模糊',
    pixelate: '马赛克',
    custom1: '自定义 1',
    custom2: '自定义 2',
    custom3: '自定义 3',
    lineWidth: '线宽',
    eraser: '橡皮擦',
    toggleFill: '切换填充',
    changeOpacity: '调整不透明度',
    undo: '撤销',
    redo: '重做',
    done: '完成',
    back: '返回',
    smallScreenMoreTooltip: '更多',
    opacity: '不透明度',
    color: '颜色',
    strokeWidth: '笔画粗细',
    fill: '填充',
    cancel: '取消',
  ),
  textEditor: I18nTextEditor(
    inputHintText: '输入文字',
    bottomNavigationBarText: '文字',
    back: '返回',
    done: '完成',
    textAlign: '对齐方式',
    fontScale: '字号',
    backgroundMode: '背景模式',
    smallScreenMoreTooltip: '更多',
  ),
  cropRotateEditor: I18nCropRotateEditor(
    bottomNavigationBarText: '裁剪旋转',
    rotate: '旋转',
    flip: '翻转',
    tilt: '倾斜',
    tiltRotate: '旋转',
    tiltHorizontal: '水平',
    tiltVertical: '垂直',
    ratio: '比例',
    back: '返回',
    done: '完成',
    cancel: '取消',
    undo: '撤销',
    redo: '重做',
    smallScreenMoreTooltip: '更多',
    reset: '重置',
  ),
  tuneEditor: I18nTuneEditor(
    bottomNavigationBarText: '调节',
    back: '返回',
    done: '完成',
    brightness: '亮度',
    contrast: '对比度',
    saturation: '饱和度',
    exposure: '曝光',
    hue: '色相',
    temperature: '色温',
    fade: '褪色',
    tint: '色调',
    undo: '撤销',
    redo: '重做',
  ),
  filterEditor: I18nFilterEditor(
    bottomNavigationBarText: '滤镜',
    back: '返回',
    done: '完成',
  ),
  blurEditor: I18nBlurEditor(
    bottomNavigationBarText: '模糊',
    back: '返回',
    done: '完成',
  ),
  emojiEditor: I18nEmojiEditor(
    bottomNavigationBarText: '表情',
    search: '搜索',
    categoryRecent: '最近使用',
    categorySmileys: '表情与人物',
    categoryAnimals: '动物与自然',
    categoryFood: '食物与饮品',
    categoryActivities: '活动',
    categoryTravel: '旅行与地点',
    categoryObjects: '物品',
    categorySymbols: '符号',
    categoryFlags: '旗帜',
  ),
  stickerEditor: I18nStickerEditor(bottomNavigationBarText: '贴纸'),
  clipsEditor: I18nClipsEditor(
    bottomNavigationBarText: '片段',
    done: '完成',
    back: '返回',
    remove: '移除',
    addVideoClip: '添加视频片段',
    processingClips: '正在处理片段…',
  ),
);
