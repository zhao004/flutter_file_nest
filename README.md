# LensVault

面向 Android 的本地文件保险库应用：通过系统文件框架（SAF）管理用户授权目录中的文件，
在应用内完成浏览、搜索、整理、压缩分享与媒体预览。拍摄与录制交由系统相机完成，应用只负责
把结果导入所选目录。当前仅支持 Android（最低 API 24），不包含 iOS、Web 或桌面端。

## 功能

**目录与文件管理**
- 选择并持久化 SAF 根目录授权；多级导航与可点击路径面包屑。
- 新建文件夹、重命名、删除（删除前展示文件/子文件夹数量），外部改动可下拉刷新。
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
- 图片预览（`InteractiveViewer` 缩放拖动，不支持的格式可外部打开）、PDF 预览（`PdfRenderer` 分页）、视频预览（沉浸式播放器，播放/暂停、拖拽进度、静音、重播、外部打开）。
- ZIP 压缩/解压（Android `java.util.zip` 流式处理，含条目数、深度、体积与压缩比安全上限）与系统分享。

## 技术栈

- Flutter + Dart 3（`useMaterial3`），GetX 负责路由与状态。
- Drift（SQLite）保存设置与本应用登记的文件创建时间。
- Kotlin 平台通道封装 SAF、缩略图、ZIP 归档与分享。
- `video_player` 播放视频。

## 目录结构

```
lib/
  main.dart                     应用入口与依赖注册
  app/
    routes/                     GetX 路由表
    pages/
      home/                     文件列表：控制器、视图、列表/对话框组件
      preview/                  图片与 PDF 预览
      video/                    视频播放
      settings/                 设置
    database/                   Drift 数据库、表定义与迁移（schema v6）
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

- **数据**：Drift schema v6，包含 `app_settings`（根目录授权与排序偏好）与 `entry_metadata`
  （本应用创建文件的登记时间）。视频等文件内容存于 SAF 目录，不写入数据库。
- **权限**：应用不声明 `CAMERA` / `RECORD_AUDIO`，相机权限由系统相机应用处理；文件访问依赖
  用户对 SAF 根目录的授权；分享缓存通过范围受限的 `FileProvider` 暴露。
- **标识**：`content://` URI 与 `documentId` 均视为不透明标识，不解析为文件路径，也不通过字符串
  前缀判断目录祖先关系。

## 说明与限制

- 仅支持 Android；不支持跨根目录移动、非 ZIP 归档、加密/分卷归档、回收站或删除撤销。
- 仅按 ZIP 打包与整理文件，不承诺压缩率；损坏或含恶意路径的归档会被拒绝。
- 「创建时间」仅对本应用登记的文件可靠，外部来源文件显示为未知，不用修改时间冒充。
