/// 扩展名到 `highlight` 语言键的映射。
///
/// `highlight` 内置 190 余种语言；未登记的扩展名返回 null，按纯文本显示，
/// 避免依赖自动探测造成的误判与性能开销。
const Map<String, String> _extensionLanguages = {
  'dart': 'dart',
  'java': 'java',
  'kt': 'kotlin',
  'kts': 'kotlin',
  'js': 'javascript',
  'mjs': 'javascript',
  'cjs': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'py': 'python',
  'pyw': 'python',
  'rs': 'rust',
  'go': 'go',
  'swift': 'swift',
  'json': 'json',
  'yaml': 'yaml',
  'yml': 'yaml',
  'html': 'xml',
  'htm': 'xml',
  'xml': 'xml',
  'css': 'css',
  'sql': 'sql',
  'c': 'c',
  'h': 'c',
  'cpp': 'cpp',
  'hpp': 'cpp',
  'cc': 'cpp',
  'cxx': 'cpp',
  'cs': 'csharp',
  'php': 'php',
  'sh': 'bash',
  'bash': 'bash',
  'zsh': 'bash',
  'toml': 'ini',
  'ini': 'ini',
  'cfg': 'ini',
  'conf': 'ini',
  'properties': 'properties',
};

/// 扩展名对应的语法语言键；不支持时返回 null（按纯文本渲染）。
String? highlightLanguageFor(String extension) =>
    _extensionLanguages[extension];
