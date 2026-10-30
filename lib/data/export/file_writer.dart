/// 备份文件落盘。
///
/// Web 没有 dart:io，所以用条件导出切换实现；
/// 非 Web 平台返回文件路径，Web 返回 null（界面只展示可复制的文本）。
export 'file_writer_stub.dart' if (dart.library.io) 'file_writer_io.dart';
