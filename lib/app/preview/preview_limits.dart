/// 应用内预览一次性读取的字节上限；超限时截断并提示，避免大文件占满内存。
///
/// 文本类内容通常远小于上限；归档与电子书需要容纳整个容器，取中等上限。
/// 图片预览沿用原有 [readDocument]（不设上限）以保证高分辨率照片完整。
const int textReadLimit = 4 * 1024 * 1024;

/// 压缩包与电子书容器的读取上限。
const int archiveReadLimit = 96 * 1024 * 1024;

/// 归档允许的最大条目数；超过时拒绝解析，避免恶意归档耗尽内存。
const int maxArchiveEntries = 5000;

/// 归档展开后的累计大小上限；超过时拒绝解析。
const int maxArchiveUncompressedBytes = 256 * 1024 * 1024;

/// CSV 预览最多渲染的行数；超出部分提示截断。
const int maxCsvRows = 1000;
