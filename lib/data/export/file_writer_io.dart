import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 把备份写到应用文档目录，返回完整路径；失败返回 null。
Future<String?> writeTextFile(String fileName, String content) async {
  try {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(content, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

/// 应用文档目录（用于告诉用户备份文件在哪）。
Future<String> documentsDirectory() async {
  try {
    return (await getApplicationDocumentsDirectory()).path;
  } catch (_) {
    return '';
  }
}
