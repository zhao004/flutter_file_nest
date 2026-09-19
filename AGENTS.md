# Repository Guidelines

## 项目结构与模块组织

Flutter 入口位于 `lib/main.dart`。页面按功能模块放在 `lib/app/pages/<feature>/`，同一功能的
View 与 Controller 保持相邻；路由使用 go_router，集中在 `lib/app/routes/`；依赖注入使用
get_it，注册入口在 `lib/app/di/injector.dart`；响应式状态使用 signals，View 通过
`SignalBuilder` 订阅。国际化文案源为 `lib/l10n/*.arb`，控件使用 `context.l10n`，非控件层使用
`AppL10n.current`；不要手动修改 `lib/l10n/generated/` 生成文件。Drift 表、数据库访问和类型转换
位于 `lib/app/database/`，只编辑源文件，不要手动修改 `*.g.dart` 生成文件。Widget 测试放在
`test/`，Android 宿主工程位于 `android/`。新增静态资源时放入 `assets/` 并在 `pubspec.yaml` 中声明。

## 构建、测试与本地开发

- `flutter pub get`：安装 `pubspec.yaml` 声明的依赖。
- `flutter run`：在已连接的模拟器或设备上启动应用。
- `flutter analyze`：执行 `flutter_lints` 静态检查。
- `flutter test`：运行 `test/` 下的 Flutter 测试。
- `dart run build_runner build --delete-conflicting-outputs`：修改 Drift 表或
  `json_annotation` 模型后重新生成代码。
- `flutter gen-l10n`：修改 `lib/l10n/*.arb` 后重新生成本地化代码（`flutter pub get`
  也会自动触发）。
- `flutter build apk --debug`：生成本地 Android 调试 APK。

## 编码风格与命名

提交前运行 `dart format lib test`，使用 Dart 默认的两空格缩进。文件名使用
`lower_snake_case.dart`，类型和 Widget 使用 `UpperCamelCase`，成员与局部变量使用
`lowerCamelCase`。优先使用 `const` Widget，并保持 View 与 Controller 的职责分离。
公共 Widget 使用中文 `///` 文档注释说明用途和必要的生命周期约束。

## 测试指南

使用 `flutter_test` 编写测试，文件以 `_test.dart` 结尾，测试名称描述可观察行为，例如
`'todo list shows saved entries'`。新增页面或控制器逻辑时覆盖主要状态、用户操作和失败边界。
仓库当前未配置覆盖率阈值；合并前至少运行与改动直接相关的测试及 `flutter analyze`。

## 提交与拉取请求

当前工作目录未提供可归纳格式的 Git 历史。新提交使用 Conventional Commits，例如
`feat(home): 新增待办筛选` 或 `fix(database): 修复删除条件`。PR 应说明目的、列出验证命令
及结果、关联 Issue；涉及界面变更时附截图。不要提交密钥、本地设备路径或生成目录中的临时文件。
