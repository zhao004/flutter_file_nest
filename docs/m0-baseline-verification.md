# M0 基线加固验证记录

- 更新日期：2026-09-18。
- 依据：`remaining-phases-plan.md` 1.2 节列出的验证缺口与 8.1 节 M0 放行条件。
- 性质：可重现构建记录与关键未验证项登记。真机相关条目在具备设备前保持
  “待执行”，不标为通过，也不阻塞独立可用的后续里程碑推进。
- 范围变更（2026-09-18）：应用内相机、拍摄预设与待保存录像已移除，拍照与录像统一由系统相机
  完成（见 `remaining-phases-plan.md` 第 0 节）。本文件中相机后端、手动参数、录制规格与待保存
  任务相关条目为历史记录，不再作为待验证项。

## 1. 可重现构建记录（2026-09-18）

环境：

- Flutter 3.44.9 stable（framework revision 6b182d2c75，engine b9499e4c252）。
- Java 17.0.12 LTS；Windows（pwsh）。
- 本机全局 Gradle 缓存异常时使用项目隔离缓存：`GRADLE_USER_HOME=<项目>/.cache/gradle`。

命令与结果：

```powershell
$env:GRADLE_USER_HOME = Join-Path (Get-Location) '.cache/gradle'
dart format --output=none --set-exit-if-changed lib test   # 通过（52 个文件无变更）
flutter test --no-pub                                      # 通过：136 项测试
flutter analyze --no-pub                                   # 通过：No issues found
./android/gradlew.bat -p android :app:testDebugUnitTest    # 通过：BUILD SUCCESSFUL
flutter build apk --debug --no-pub                         # 通过：app-debug.apk
```

依赖解析前提：按当前 `pubspec.yaml` 已完成 `flutter pub get`；依赖变更后先重新解析再执行 `--no-pub` 命令。

> 上表为 2026-09-18 当时的结果快照。当日随后移除了应用内相机相关功能，测试数量、Kotlin 单元测试范围与
> 依赖声明已相应变化，本节数字不描述移除后的版本。移除后的相关变更见 `remaining-phases-plan.md` 第 0 节。

## 2. 未验证项登记（真机与外部环境）

以下条目来自规划 1.2 节，当前状态为“未执行”，交付对应里程碑时补验收记录：

| 范围 | 未验证项 | 归属 |
| --- | --- | --- |
| 存储 | SD 卡读写、拔出与重插、只读提供方、目录授权撤销、外部改名 | M0/M6 真机 |
| 导入提交 | 存储不足、复制中断、只读目录下的系统相机结果导入与部分产物清理 | M0 真机 |
| 归档 | 独立解压工具核对产物、中文名/超大文件(ZIP64)/深目录、接收端可读性、体积膨胀与空间不足 | M6 真机 |
| 批量操作 | moveDocument 在真实提供方的支持范围、批量复制的逐项失败、只读提供方与空间不足 | M7 真机 |
| 缩略图 | 真实 MediaProvider 各格式覆盖、滚动性能、千级条目与递归搜索响应 | M7 真机 |
| 内容导入 | Android 13+ 照片选择器与低版本 OpenDocument、选中复制的大文件与中断 | 3B 扩展 真机 |
| 拍照 | 各厂商相机应用对 ACTION_IMAGE_CAPTURE / ACTION_VIDEO_CAPTURE 的取消/无相机行为、SD 卡只读目录失败提示、录制画质与时长限制 | 3B 扩展 真机 |
| PDF 预览 | 渲染质量、超大 PDF 内存表现、加密/损坏文件提示 | 3B 扩展 真机 |

已知的结构性限制（非缺陷，需后续里程碑决策）：

- 批量操作逐项状态未持久化（FileOperationJobs 表未创建）；进程终止后
  界面内逐项报告丢失（原录像待保存任务已随应用内相机移除，不再有该恢复路径）。
- 批量重命名的互换名称（如 a→b 且 b→a）被预览校验拒绝，需分两次执行。
- 递归搜索无条目总量上限，依赖取消按钮与分批渲染保证响应。

## 3. 故障恢复检查（自动化部分）

Phase 1 遗留的自动化覆盖继续通过，且本轮新增：

- 批量删除部分失败可识别并重试（`批量删除逐项执行，失败项保留选中以便重试`）。
- 移动回退复制时源删除失败不产生静默丢失（`移动回退复制完成但源未删除时逐项报告`）。
- 递归搜索失败目录标记未完成且不阻塞其余结果。

> 原“待保存录像期间批量删除被阻止”覆盖已随待保存录像功能移除，对应测试同步删除。

## 4. 下一步

1. 补齐第一台真机的存储、系统相机导入与 SD 卡验证，回填本文件第 2 节状态。
2. 批量操作日志持久化（FileOperationJobs/Items）在出现真实中断恢复需求时按 7.4 演进。
