import 'dart:convert';
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
      Directory base;
      if (Platform.isAndroid) {
        base = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
      } else if (Platform.isIOS) {
        base = await getApplicationDocumentsDirectory();
      } else {
        base = (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
      }

      final airFileDir = Directory(p.join(base.path, 'AirFile'));
      if (!await airFileDir.exists()) {
        await airFileDir.create(recursive: true);
      }
      _downloadDir = airFileDir;
    } catch (e) {
      debugPrint('Error initializing storage directory: $e');
      try {
        final fallbackBase = await getApplicationDocumentsDirectory();
        final fallbackDir = Directory(p.join(fallbackBase.path, 'AirFile'));
        if (!await fallbackDir.exists()) {
          await fallbackDir.create(recursive: true);
        }
        _downloadDir = fallbackDir;
      } catch (e2) {
        debugPrint('Fallback storage initialization failed: $e2');
      }
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

  Future<File> _getWatchedFoldersConfigFile() async {
    Directory base;
    try {
      base = await getApplicationSupportDirectory();
    } catch (_) {
      base = await getApplicationDocumentsDirectory();
    }
    final configDir = Directory(p.join(base.path, 'AirFile'));
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return File(p.join(configDir.path, 'airfile_watched_folders.json'));
  }

  Future<List<String>> getWatchedFolders() async {
    try {
      final file = await _getWatchedFoldersConfigFile();
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      final data = jsonDecode(content);
      if (data is Map && data['watchedFolders'] is List) {
        return (data['watchedFolders'] as List)
            .map((e) => e.toString())
            .where((path) => path.trim().isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading watched folders: $e');
    }
    return [];
  }

  Future<void> saveWatchedFolders(List<String> folders) async {
    try {
      final file = await _getWatchedFoldersConfigFile();
      final data = {
        'watchedFolders': folders,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving watched folders: $e');
    }
  }
}
