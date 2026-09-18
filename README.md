# LensVault

面向 Android 的本地文件保险库应用：通过系统文件框架（SAF）管理用户授权目录中的文件，
在应用内完成浏览、搜索、整理、压缩分享与媒体预览。拍摄与录制交由系统相机完成，应用只负责
把结果导入所选目录。当前仅支持 Android（最低 API 24），不包含 iOS、Web 或桌面端。

## 功能

**目录与文件管理**
- 选择并持久化 SAF 根目录授权；多级导航与可点击路径面包屑。
- 新建文件夹与空文件（按扩展名推断 MIME 类型）、重命名、删除（删除前展示文件/子文件夹数量），外部改动可下拉刷新。
- 长按文件/文件夹弹出单项菜单：重命名、详情、解压、删除。

**批量操作（工具栏「多选」）**
- 批量删除：汇总影响数量后确认，逐项报告结果，失败项保留以便重试。
- 批量移动到目标文件夹：应用内目录选择器实时校验，禁止移入来源自身、所选文件夹内部或当前目录。
- 批量重命名：前缀、后缀、文本替换、序号，执行前逐项预览与校验。
- 批量压缩与通过系统 Sharesheet 分享。

**搜索与排序**
- 当前目录即时过滤 + 显式递归搜索（可取消、分批显示、失败目录标注为结果不完整）。
- 「更多 → 排序方式」弹窗：按名称 / 修改时间 / 创建时间 / 文件大小，支持升序与降序。

**内容导入**
- 「选择文件」通过系统文件选择器导入任意类型文件（`OpenDocument`，不限定 MIME）。
- 「拍照」「录制」调用系统相机（`ACTION_IMAGE_CAPTURE` / `ACTION_VIDEO_CAPTURE`），结果复制到当前目录。

**媒体与归档**
- 图片/视频列表缩略图：原生 `loadThumbnail`（API 29+），低版本回退 `MediaMetadataRetriever`；带缓存、并发上限与取消，目录切换时不阻塞列表。
- 图片预览（缩放、双击放大、缩放级别、信息与分享，SVG 由 `flutter_svg` 渲染）、PDF 预览（原生 `PdfRenderer` 分页与缩放）、视频预览（media_kit，播放/暂停、拖拽进度、倍速、静音、双击与滑动手势、续播、外部打开）、音频预览（media_kit，唱片式界面、快进快退、倍速、静音、续播）。
- 文档预览：文本（编码识别、搜索高亮、换行与字号）、代码（语法高亮、行号、搜索）、Markdown（阅读/源码切换）、CSV 表格、字幕（SRT/VTT/ASS 时间轴）、字体（TTF/OTF 样文）、压缩包内容浏览（ZIP/TAR/GZ/BZ2/XZ 虚拟文件系统）、EPUB 阅读器（目录、分页、字号）。
- 文本与代码编辑：txt/log/ini 与 html/php/java/js/css/json/xml/yaml 等，以及 Markdown 源码，可进入编辑页修改；保存按原编码/BOM/换行回写，未保存返回二次确认；超过读取上限或只读目录不开放编辑。
- 应用内无法预览的类型展示信息页并提供“用其他应用打开”；Office 文档、RAR/7Z、MOBI/AZW3、字体集合（TTC）等交由系统应用。
- ZIP 压缩/解压（Android `java.util.zip` 流式处理，含条目数、深度、体积与压缩比安全上限）与系统分享。

## 技术栈

- Flutter + Dart 3（`useMaterial3`），GetX 负责路由与状态。
- Drift（SQLite）保存设置、本应用登记的文件创建时间与媒体续播位置。
- Kotlin 平台通道封装 SAF、缩略图、ZIP 归档与分享。
- `media_kit` 播放视频与音频；`flutter_svg`、`flutter_markdown_plus`、`flutter_highlight`、`archive`、`charset_converter`、`xml` 与 `flutter_widget_from_html_core` 支撑各类型预览。

## 文件预览架构

预览分为四层，新增格式只需扩展解析层与查看器：

1. **识别层** `lib/app/file_type/`：`FileCategory` 综合 MIME 与扩展名判定分类。
2. **解析层** `lib/app/preview/`：`PreviewResolver` 将条目解析为唯一 `PreviewKind`；`PreviewLauncher` 决定进入应用内预览还是系统打开；文本解码、CSV/字幕/EPUB/归档解析与大小上限均在此层。
3. **UI 层** `lib/app/pages/preview/`：`FilePreviewPage` 按 `PreviewKind` 选择具体查看器。
4. **外部层** `StorageGateway.openFile` 调用 Android `ACTION_VIEW`。

各查看器共用 `PreviewSettingsController` 持久化字号、换行与 Markdown 模式。

## 目录结构

```
lib/
  main.dart                     应用入口与依赖注册
  app/
    routes/                     GetX 路由表
    pages/
      home/                     文件列表：控制器、视图、列表/对话框组件
      preview/                  各类型预览页与预览偏好控制器
      video/                    视频播放
      settings/                 设置
    preview/                    预览解析层：类型解析、启动器、文本/CSV/字幕/EPUB/归档解析
    database/                   Drift 数据库、表定义与迁移（schema v8）
    models/                     存储条目、归档与批量操作模型
    services/                   SAF、缩略图、归档、数据库存储封装
android/app/src/main/kotlin/...  MainActivity 与 storage/（SAF、归档、分享）
test/                            单元测试与 Widget 测试
```

## 环境要求

- Flutter 3.44+（stable）与 Dart 3.12+。
- Java 17。
- Android SDK；`minSdk = 24`。

## 构建与运行

```powershell
flutter pub get
flutter run
flutter build apk --debug
```

修改 Drift 表或 `json_annotation` 模型后重新生成代码：

```powershell
dart run build_runner build --delete-conflicting-outputs
```

> `*.g.dart` 由构建工具生成，请勿手工编辑。

## 测试与静态检查

```powershell
dart format lib test
flutter analyze
flutter test
```

## 数据与权限

- **数据**：Drift schema v8，包含 `app_settings`（根目录授权、排序偏好与预览显示偏好）、
  `entry_metadata`（本应用创建文件的登记时间）与 `playback_progress`（媒体续播位置）。
  视频等文件内容存于 SAF 目录，不写入数据库。
- **权限**：应用不声明 `CAMERA` / `RECORD_AUDIO`，相机权限由系统相机应用处理；文件访问依赖
  用户对 SAF 根目录的授权；分享缓存通过范围受限的 `FileProvider` 暴露。
- **标识**：`content://` URI 与 `documentId` 均视为不透明标识，不解析为文件路径，也不通过字符串
  前缀判断目录祖先关系。

## 说明与限制

- 仅支持 Android；不支持跨根目录移动、非 ZIP 归档、加密/分卷归档、回收站或删除撤销。
- 仅按 ZIP 打包与整理文件，不承诺压缩率；损坏或含恶意路径的归档会被拒绝。
- 应用内压缩包浏览仅支持 ZIP/TAR/GZ/BZ2/XZ 系列（受读取与展开上限约束），RAR/7Z/ZSTD 走系统打开；
  解压仍仅支持 ZIP。
- Office 文档、MOBI/AZW3、字体集合（TTC）与 Web 字体不做内嵌解析，交由系统应用。
- 「创建时间」仅对本应用登记的文件可靠，外部来源文件显示为未知，不用修改时间冒充。
