# sora-editor（文本/代码编辑器平台视图）未附带 consumer 规则，
# 且内部存在经反射访问的实现；保守保留，避免 R8 误删导致编辑器崩溃。
-keep class io.github.rosemoe.sora.** { *; }

# sora-editor 的 Kotlin 接口继承 kotlin.Cloneable：低版本 Kotlin 元数据
# 生成的 DefaultImpls 引用在运行时不会被解析，忽略缺失类告警。
-dontwarn kotlin.Cloneable$DefaultImpls
