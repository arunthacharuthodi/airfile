import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StorageService {
  Directory? _downloadDir;

  Directory? get downloadDir => _downloadDir;
  String get downloadPath => _downloadDir?.path ?? '';

  Future<void> init() async {
    try {
      final base = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final airFileDir = Directory(p.join(base.path, 'AirFile'));
      if (!await airFileDir.exists()) {
        await airFileDir.create(recursive: true);
      }
      _downloadDir = airFileDir;
    } catch (e) {
      debugPrint('Error initializing storage directory: $e');
      final fallback = Directory(p.join(Platform.environment['HOME'] ?? '/tmp', 'Downloads', 'AirFile'));
      if (!await fallback.exists()) {
        await fallback.create(recursive: true);
      }
      _downloadDir = fallback;
    }
  }

  Future<File> getUniqueDestinationFile(String fileName) async {
    if (_downloadDir == null) {
      await init();
    }
    final dir = _downloadDir!;
    var file = File(p.join(dir.path, fileName));
    if (!await file.exists()) {
      return file;
    }

    final ext = p.extension(fileName);
    final base = p.basenameWithoutExtension(fileName);
    int counter = 1;

    while (await file.exists()) {
      file = File(p.join(dir.path, '$base ($counter)$ext'));
      counter++;
    }

    return file;
  }

  Future<bool> revealInFinder(String filePath) async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('open', ['-R', filePath]);
        return result.exitCode == 0;
      } else if (Platform.isWindows) {
        final result = await Process.run('explorer.exe', ['/select,', filePath]);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      debugPrint('Error opening in File Manager: $e');
      return false;
    }
  }

  Future<bool> openDownloadsFolder() async {
    try {
      if (Platform.isMacOS && _downloadDir != null) {
        final result = await Process.run('open', [_downloadDir!.path]);
        return result.exitCode == 0;
      } else if (Platform.isWindows && _downloadDir != null) {
        final result = await Process.run('explorer.exe', [_downloadDir!.path]);
        return result.exitCode == 0;
      }
      return false;
    } catch (e) {
      debugPrint('Error opening downloads folder: $e');
      return false;
    }
  }
}
