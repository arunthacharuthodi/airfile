import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import '../models/file_payload.dart';
import 'clipboard_sync_service.dart';
import 'storage_service.dart';

typedef OnIncomingTransferRequest = Future<bool> Function(FilePayload payload);
typedef OnTransferProgress = void Function(FilePayload payload);
typedef OnTransferCompleted = void Function(FilePayload payload);

class StagedFile {
  final String id;
  final String path;
  final String name;
  final int size;
  final String mimeType;
  final String? folderSource;
  final String? folderPrefix;

  StagedFile({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.mimeType,
    this.folderSource,
    this.folderPrefix,
  });
}

class TransferServer extends ChangeNotifier {
  static const int defaultPort = 53317;

  final StorageService storageService;
  final String deviceId;
  String deviceName;
  ClipboardSyncService? clipboardSyncService;

  HttpServer? _serverIpv4;
  HttpServer? _serverIpv6;
  int _port = defaultPort;
  bool _isRunning = false;

  final List<StagedFile> _stagedFiles = [];
  final List<FilePayload> _activeTransfers = [];
  final List<FilePayload> _transferHistory = [];
  final List<String> _watchedFolders = [];
  final Map<String, StreamSubscription<FileSystemEvent>> _folderWatchers = {};
  final Map<String, Timer> _syncDebounceTimers = {};

  OnIncomingTransferRequest? onTransferRequested;
  OnTransferProgress? onTransferProgress;
  OnTransferCompleted? onTransferCompleted;

  bool get isRunning => _isRunning;
  int get port => _port;
  List<StagedFile> get stagedFiles => List.unmodifiable(_stagedFiles);
  List<FilePayload> get activeTransfers => List.unmodifiable(_activeTransfers);
  List<FilePayload> get transferHistory => List.unmodifiable(_transferHistory);
  List<String> get watchedFolders => List.unmodifiable(_watchedFolders);

  TransferServer({
    required this.storageService,
    required this.deviceId,
    required this.deviceName,
  });

  Future<bool> start([int port = defaultPort]) async {
    if (_isRunning) return true;
    _port = port;

    bool boundAny = false;

    try {
      _serverIpv4 = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
      _serverIpv4!.listen(
        _handleRequest,
        onError: (err) => debugPrint('IPv4 server error: $err'),
      );
      boundAny = true;
      debugPrint('AirFile Server listening on IPv4 port $_port');
    } catch (e) {
      debugPrint('IPv4 bind error on port $_port: $e');
    }

    try {
      _serverIpv6 = await HttpServer.bind(InternetAddress.anyIPv6, _port, v6Only: true, shared: true);
      _serverIpv6!.listen(
        _handleRequest,
        onError: (err) => debugPrint('IPv6 server error: $err'),
      );
      boundAny = true;
      debugPrint('AirFile Server listening on IPv6 port $_port');
    } catch (e) {
      debugPrint('IPv6 bind error on port $_port: $e');
    }

    _isRunning = boundAny;
    notifyListeners();
    return boundAny;
  }

  Future<void> stop() async {
    for (final sub in _folderWatchers.values) {
      await sub.cancel();
    }
    _folderWatchers.clear();
    for (final timer in _syncDebounceTimers.values) {
      timer.cancel();
    }
    _syncDebounceTimers.clear();

    await _serverIpv4?.close(force: true);
    await _serverIpv6?.close(force: true);
    _serverIpv4 = null;
    _serverIpv6 = null;
    _isRunning = false;
    notifyListeners();
  }

  static String generateFolderPrefix(String folderPath) {
    final folderName = p.basename(folderPath);
    final genericNames = {
      'flutter-apk',
      'flutter-apks',
      'apk',
      'apks',
      'outputs',
      'build',
      'release',
      'debug',
      'dist',
      'bin',
      'app',
    };

    if (genericNames.contains(folderName.toLowerCase())) {
      Directory current = Directory(folderPath);
      String? projectName;
      for (int i = 0; i < 5; i++) {
        final parent = current.parent;
        if (parent.path == current.path) break;
        current = parent;
        final parentName = p.basename(current.path);
        if (!genericNames.contains(parentName.toLowerCase()) &&
            parentName.isNotEmpty &&
            parentName != '/' &&
            parentName != '\\') {
          projectName = parentName;
          break;
        }
      }
      if (projectName != null && projectName.isNotEmpty) {
        return '$projectName • $folderName';
      }
    }
    return folderName;
  }

  Future<void> initWatchedFolders() async {
    try {
      final saved = await storageService.getWatchedFolders();
      _watchedFolders.clear();
      for (final folder in saved) {
        if (await Directory(folder).exists() && !_watchedFolders.contains(folder)) {
          _watchedFolders.add(folder);
          _startWatchingFolder(folder);
        }
      }
      await refreshWatchedFolders();
    } catch (e) {
      debugPrint('Error initializing watched folders: $e');
    }
  }

  Future<void> addWatchedFolder(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return;
    if (!_watchedFolders.contains(folderPath)) {
      _watchedFolders.add(folderPath);
      await storageService.saveWatchedFolders(_watchedFolders);
      _startWatchingFolder(folderPath);
    }
    await _syncFolderFiles(folderPath);
    notifyListeners();
  }

  Future<void> removeWatchedFolder(String folderPath) async {
    _watchedFolders.remove(folderPath);
    _stopWatchingFolder(folderPath);
    await storageService.saveWatchedFolders(_watchedFolders);
    _stagedFiles.removeWhere((f) => f.folderSource == folderPath);
    notifyListeners();
  }

  Future<void> refreshWatchedFolders() async {
    for (final folder in List<String>.from(_watchedFolders)) {
      await _syncFolderFiles(folder);
    }
    notifyListeners();
  }

  void _startWatchingFolder(String folderPath) {
    _stopWatchingFolder(folderPath);
    try {
      final dir = Directory(folderPath);
      _folderWatchers[folderPath] = dir.watch().listen((event) {
        _debounceFolderSync(folderPath);
      }, onError: (err) {
        debugPrint('Watcher error for $folderPath: $err');
      });
    } catch (e) {
      debugPrint('Error starting watcher on $folderPath: $e');
    }
  }

  void _stopWatchingFolder(String folderPath) {
    _folderWatchers[folderPath]?.cancel();
    _folderWatchers.remove(folderPath);
    _syncDebounceTimers[folderPath]?.cancel();
    _syncDebounceTimers.remove(folderPath);
  }

  void _debounceFolderSync(String folderPath) {
    _syncDebounceTimers[folderPath]?.cancel();
    _syncDebounceTimers[folderPath] = Timer(const Duration(milliseconds: 700), () {
      _syncFolderFiles(folderPath);
    });
  }

  Future<void> _syncFolderFiles(String folderPath) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return;

    final prefix = generateFolderPrefix(folderPath);

    // Keep individual files and other folders intact, only refresh this folder's items
    _stagedFiles.removeWhere((f) => f.folderSource == folderPath);

    try {
      final List<File> filesToStage = [];
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final base = p.basename(entity.path);
          if (base.startsWith('.')) continue;

          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.tmp' || ext == '.bak' || ext == '.lock' || ext == '.d') continue;

          final rel = p.relative(entity.path, from: folderPath);
          final parts = p.split(rel);
          if (parts.length > 3) continue;

          filesToStage.add(entity);
        }
      }

      filesToStage.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

      for (final file in filesToStage) {
        final stat = await file.stat();
        final fileName = p.basename(file.path);
        final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
        final id = 'folder_stage_${folderPath.hashCode}_${file.path.hashCode}';

        _stagedFiles.add(
          StagedFile(
            id: id,
            path: file.path,
            name: '[$prefix] $fileName',
            size: stat.size,
            mimeType: mime,
            folderSource: folderPath,
            folderPrefix: prefix,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error scanning folder $folderPath: $e');
    }
    notifyListeners();
  }

  void stageFile(String filePath, {String? customName, String? folderSource, String? folderPrefix}) {
    final file = File(filePath);
    if (!file.existsSync()) return;
    final stat = file.statSync();
    final fileName = customName ?? p.basename(filePath);
    final mime = lookupMimeType(filePath) ?? 'application/octet-stream';
    final id = 'stage_${DateTime.now().millisecondsSinceEpoch}_${_stagedFiles.length}';

    // Don't add duplicate paths
    _stagedFiles.removeWhere((f) => f.path == filePath);
    _stagedFiles.add(
      StagedFile(
        id: id,
        path: filePath,
        name: fileName,
        size: stat.size,
        mimeType: mime,
        folderSource: folderSource,
        folderPrefix: folderPrefix,
      ),
    );
    notifyListeners();
  }

  void removeStagedFile(String id) {
    _stagedFiles.removeWhere((f) => f.id == id);
    notifyListeners();
  }

  void clearStagedFiles({bool keepWatchedFolders = true}) {
    if (keepWatchedFolders && _stagedFiles.any((f) => f.folderSource != null)) {
      _stagedFiles.removeWhere((f) => f.folderSource == null);
    } else {
      _stagedFiles.clear();
    }
    notifyListeners();
  }

  void clearHistory() {
    _transferHistory.clear();
    notifyListeners();
  }

  void dismissTransfer(String id) {
    _transferHistory.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers for web requests
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Content-Length, X-Device-Id, X-Device-Name, X-File-Name, X-File-Size, X-Auth-Token');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      if (path == '/api/ping') {
        _handlePing(request);
      } else if (path == '/api/pair/request' && request.method == 'POST') {
        await _handlePairRequest(request);
      } else if (path == '/api/pair/unpair' && request.method == 'POST') {
        await _handlePairUnpair(request);
      } else if (path == '/api/staged') {
        _handleGetStagedFiles(request);
      } else if (path == '/api/transfer/request' && request.method == 'POST') {
        await _handleTransferRequest(request);
      } else if (path == '/api/transfer/upload' && request.method == 'POST') {
        await _handleBinaryUpload(request);
      } else if (path == '/api/clipboard' && request.method == 'POST') {
        await _handleClipboardPost(request);
      } else if (path == '/api/clipboard' && request.method == 'GET') {
        _handleClipboardGet(request);
      } else if (path.startsWith('/api/transfer/download/')) {
        await _handleDownload(request);
      } else if (path == '/web/upload' && request.method == 'POST') {
        await _handleWebMultipartUpload(request);
      } else if (path == '/apk' ||
          path == '/AirFile-Android.apk' ||
          path == '/app-release.apk' ||
          path == '/download/airfile.apk' ||
          path == '/download/AirFile-Android.apk') {
        await _handleApkDownload(request);
      } else if (path == '/' || path == '/index.html') {
        _handleWebPortal(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (e, stack) {
      debugPrint('Error handling request $path: $e\n$stack');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Internal Server Error: $e');
        await request.response.close();
      } catch (_) {}
    }
  }

  void _handlePing(HttpRequest request) {
    final response = {
      'id': deviceId,
      'name': deviceName,
      'type': 'macos',
      'port': _port,
      'version': '1.0.0',
      'timestamp': DateTime.now().toIso8601String(),
    };
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response));
    request.response.close();
  }

  void _handleGetStagedFiles(HttpRequest request) {
    final list = _stagedFiles.map((f) => {
      'id': f.id,
      'name': f.name,
      'path': f.path,
      'size': f.size,
      'mimeType': f.mimeType,
      'folderSource': f.folderSource,
      'folderPrefix': f.folderPrefix,
      'downloadUrl': '/api/transfer/download/${f.id}',
    }).toList();

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'files': list}));
    request.response.close();
  }

  Future<void> _handlePairRequest(HttpRequest request) async {
    try {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'accepted': true, 'token': 'direct'}));
    } catch (_) {
    } finally {
      await request.response.close();
    }
  }

  Future<void> _handlePairUnpair(HttpRequest request) async {
    try {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'ok'}));
    } catch (_) {
    } finally {
      await request.response.close();
    }
  }

  Future<void> _handleClipboardPost(HttpRequest request) async {

    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final success = await clipboardSyncService?.handleIncomingClipboard(json) ?? false;
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': success ? 'ok' : 'ignored'}));
    } catch (e) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': e.toString()}));
    } finally {
      await request.response.close();
    }
  }

  void _handleClipboardGet(HttpRequest request) {
    final response = {
      'text': clipboardSyncService?.currentText ?? '',
      'senderName': clipboardSyncService?.lastSenderDeviceName ?? '',
      'timestamp': clipboardSyncService?.lastSyncTime?.toIso8601String() ?? '',
    };
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response));
    request.response.close();
  }

  Future<void> _handleTransferRequest(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final json = jsonDecode(body) as Map<String, dynamic>;

    final payload = FilePayload.fromJson(
      json,
      isOutgoing: false,
      peerName: request.headers.value('X-Device-Name') ?? 'Remote Device',
      peerAddress: request.connectionInfo?.remoteAddress.address ?? 'Unknown',
    );

    bool accepted = true;
    if (onTransferRequested != null) {
      accepted = await onTransferRequested!(payload);
    }

    if (accepted) {
      _activeTransfers.add(payload);
      notifyListeners();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'accepted': true, 'fileId': payload.id}));
    } else {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'accepted': false, 'reason': 'User rejected'}));
    }
    await request.response.close();
  }

  Future<void> _handleBinaryUpload(HttpRequest request) async {

    final rawFileName = request.headers.value('X-File-Name');
    final fileName = rawFileName != null ? Uri.decodeComponent(rawFileName) : 'received_${DateTime.now().millisecondsSinceEpoch}.bin';
    final totalSize = int.tryParse(request.headers.value('X-File-Size') ?? '') ?? request.contentLength;
    final senderName = request.headers.value('X-Device-Name') ?? 'Peer Device';
    final remoteIp = request.connectionInfo?.remoteAddress.address ?? 'Unknown';

    final payload = FilePayload(
      id: 'rx_${DateTime.now().millisecondsSinceEpoch}',
      name: fileName,
      size: totalSize > 0 ? totalSize : 0,
      mimeType: lookupMimeType(fileName) ?? 'application/octet-stream',
      isOutgoing: false,
      peerName: senderName,
      peerAddress: remoteIp,
      status: TransferStatus.transferring,
    );

    _activeTransfers.add(payload);
    notifyListeners();

    final destFile = await storageService.getUniqueDestinationFile(fileName);
    final sink = destFile.openWrite();

    int receivedBytes = 0;
    final stopwatch = Stopwatch()..start();
    DateTime lastProgressTime = DateTime.now();

    try {
      await for (final chunk in request) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final now = DateTime.now();
        if (now.difference(lastProgressTime).inMilliseconds >= 100 || receivedBytes == totalSize) {
          lastProgressTime = now;
          payload.progress = totalSize > 0 ? (receivedBytes / totalSize).clamp(0.0, 1.0) : 0.5;
          final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
          if (elapsedSec > 0) {
            payload.speedBytesPerSec = receivedBytes / elapsedSec;
          }
          onTransferProgress?.call(payload);
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();

      payload.status = TransferStatus.completed;
      payload.progress = 1.0;
      payload.savedPath = destFile.path;

      _activeTransfers.remove(payload);
      _transferHistory.insert(0, payload);
      onTransferCompleted?.call(payload);
      notifyListeners();

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'success': true, 'path': destFile.path}));
    } catch (e) {
      await sink.close();
      payload.status = TransferStatus.failed;
      payload.errorMessage = e.toString();
      _activeTransfers.remove(payload);
      _transferHistory.insert(0, payload);
      notifyListeners();

      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({'success': false, 'error': e.toString()}));
    } finally {
      await request.response.close();
    }
  }

  Future<void> _handleDownload(HttpRequest request) async {
    final fileId = request.uri.path.replaceFirst('/api/transfer/download/', '');
    final staged = _stagedFiles.firstWhere(
      (f) => f.id == fileId,
      orElse: () => throw Exception('File not found'),
    );

    final file = File(staged.path);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File no longer exists on disk');
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.parse(staged.mimeType);
    final safeFileName = staged.name.replaceAll('"', '');
    request.response.headers.add(
      'Content-Disposition',
      'attachment; filename="$safeFileName"; filename*=UTF-8\'\'${Uri.encodeComponent(safeFileName)}',
    );

    final payload = FilePayload(
      id: 'dl_${DateTime.now().millisecondsSinceEpoch}',
      name: staged.name,
      size: staged.size,
      localPath: staged.path,
      mimeType: staged.mimeType,
      isOutgoing: true,
      peerName: 'Web / Remote Client',
      peerAddress: request.connectionInfo?.remoteAddress.address ?? 'Web',
      status: TransferStatus.transferring,
    );

    _activeTransfers.add(payload);
    notifyListeners();

    int sentBytes = 0;
    final stopwatch = Stopwatch()..start();
    final stream = file.openRead();

    try {
      await for (final chunk in stream) {
        request.response.add(chunk);
        sentBytes += chunk.length;

        final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
        if (elapsedSec > 0) {
          payload.speedBytesPerSec = sentBytes / elapsedSec;
        }
        payload.progress = (sentBytes / staged.size).clamp(0.0, 1.0);
        notifyListeners();
      }

      payload.status = TransferStatus.completed;
      _activeTransfers.remove(payload);
      _transferHistory.insert(0, payload);
      notifyListeners();
    } catch (e) {
      payload.status = TransferStatus.failed;
      payload.errorMessage = e.toString();
      _activeTransfers.remove(payload);
      _transferHistory.insert(0, payload);
      notifyListeners();
    } finally {
      await request.response.close();
    }
  }

  Future<void> _handleWebMultipartUpload(HttpRequest request) async {
    final contentType = request.headers.contentType;
    if (contentType == null || contentType.primaryType != 'multipart') {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Expected multipart/form-data');
      await request.response.close();
      return;
    }

    final boundary = contentType.parameters['boundary'];
    if (boundary == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('No boundary specified');
      await request.response.close();
      return;
    }

    final transformer = MimeMultipartTransformer(boundary);
    final parts = transformer.bind(request);

    int uploadedCount = 0;

    await for (final part in parts) {
      final header = part.headers['content-disposition'];
      if (header == null) continue;

      final match = RegExp(r'filename="([^"]+)"').firstMatch(header);
      if (match == null) continue;

      final originalName = match.group(1) ?? 'uploaded_${DateTime.now().millisecondsSinceEpoch}.bin';
      final cleanName = p.basename(originalName);

      final destFile = await storageService.getUniqueDestinationFile(cleanName);
      final sink = destFile.openWrite();

      final payload = FilePayload(
        id: 'web_up_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanName,
        size: 0,
        mimeType: lookupMimeType(cleanName) ?? 'application/octet-stream',
        isOutgoing: false,
        peerName: 'iPhone Safari (Hotspot)',
        peerAddress: request.connectionInfo?.remoteAddress.address ?? 'Safari',
        status: TransferStatus.transferring,
      );

      _activeTransfers.add(payload);
      notifyListeners();

      int bytes = 0;
      await for (final chunk in part) {
        sink.add(chunk);
        bytes += chunk.length;
      }
      await sink.flush();
      await sink.close();

      payload.size = bytes;
      payload.progress = 1.0;
      payload.status = TransferStatus.completed;
      payload.savedPath = destFile.path;

      _activeTransfers.remove(payload);
      _transferHistory.insert(0, payload);
      notifyListeners();
      uploadedCount++;
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'success': true, 'uploadedFiles': uploadedCount}));
    await request.response.close();
  }

  Future<void> _handleApkDownload(HttpRequest request) async {
    final home = Platform.environment['HOME'] ?? '';
    final candidatePaths = [
      '$home/Downloads/AirFile/AirFile-Android.apk',
      '$home/Downloads/AirFile/AirFile-Android-Release.apk',
      '/Users/arunthacharuthodi/Documents/Freelance/mp/AirFile-Android.apk',
      '/Users/arunthacharuthodi/Documents/Freelance/mp/AirFile-Android-Release.apk',
      '/Users/arunthacharuthodi/Documents/Freelance/mp/build/app/outputs/flutter-apk/app-release.apk',
      '/Users/arunthacharuthodi/Documents/Freelance/mp/build/app/outputs/apk/release/app-release.apk',
      'AirFile-Android.apk',
      'AirFile-Android-Release.apk',
      'build/app/outputs/flutter-apk/app-release.apk',
      'build/app/outputs/flutter-apk/app-debug.apk',
    ];

    File? apkFile;
    for (final path in candidatePaths) {
      if (path.isEmpty) continue;
      try {
        final f = File(path);
        if (await f.exists()) {
          apkFile = f;
          break;
        }
      } catch (_) {}
    }

    if (apkFile == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.text;
      request.response.write('APK file not found on Mac');
      await request.response.close();
      return;
    }

    try {
      final stat = await apkFile.stat();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType('application', 'vnd.android.package-archive');
      request.response.headers.set('Content-Disposition', 'attachment; filename="AirFile-Android.apk"');
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.set(HttpHeaders.contentLengthHeader, stat.size);
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

      await request.response.addStream(apkFile.openRead());
      await request.response.close();
    } catch (e) {
      debugPrint('Error serving APK download: $e');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  void _handleWebPortal(HttpRequest request) {
    final stagedItemsHtml = _stagedFiles.isEmpty
        ? '<div class="empty-state">No files currently staged on Mac. Drop files into the Mac app or add project folders to download them here.</div>'
        : _stagedFiles.map((f) {
            final sizeKb = (f.size / 1024).toStringAsFixed(1);
            final sizeStr = f.size > 1024 * 1024 ? '${(f.size / (1024 * 1024)).toStringAsFixed(1)} MB' : '$sizeKb KB';
            return '''
              <div class="file-card">
                <div class="file-info">
                  <div class="file-name">${_escapeHtml(f.name)}</div>
                  <div class="file-path" title="${_escapeHtml(f.path)}">${_escapeHtml(f.path)}</div>
                  <div class="file-meta">$sizeStr • ${_escapeHtml(f.mimeType)}</div>
                </div>
                <a href="/api/transfer/download/${f.id}" download="${_escapeHtml(f.name)}" class="btn-download">Download</a>
              </div>
            ''';
          }).join('');

    final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>AirFile • ${_escapeHtml(deviceName)}</title>
  <link rel="icon" type="image/png" href="data:image/png;base64,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">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Alumni+Sans:wght@300;400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #000000;
      --card-bg: #111111;
      --card-inner: #161616;
      --card-border: #242424;
      --card-border-light: #333333;
      --text: #FFFFFF;
      --text-secondary: #A3A3A3;
      --text-muted: #6B6B6B;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
    body {
      font-family: 'Alumni Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 20px 16px;
      font-weight: 300;
      letter-spacing: 0.3px;
    }
    .container {
      width: 100%;
      max-width: 480px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .header {
      text-align: center;
      padding: 8px 0 4px 0;
    }
    .logo-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: #161616;
      border: 1px solid var(--card-border-light);
      padding: 3px 10px;
      border-radius: 4px;
      font-size: 12px;
      font-weight: 400;
      color: var(--text-secondary);
      letter-spacing: 0.8px;
      text-transform: uppercase;
      margin-bottom: 6px;
    }
    .pulse-dot {
      width: 5px;
      height: 5px;
      background-color: #FFFFFF;
      border-radius: 50%;
      opacity: 0.8;
    }
    h1 {
      font-size: 20px;
      font-weight: 400;
      letter-spacing: 0.8px;
      color: var(--text);
    }
    .subtitle {
      color: var(--text-muted);
      font-size: 13px;
      font-weight: 300;
      margin-top: 2px;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 8px;
      padding: 14px 16px;
    }
    .card-title {
      font-size: 14px;
      font-weight: 400;
      letter-spacing: 0.4px;
      margin-bottom: 10px;
      display: flex;
      align-items: center;
      gap: 6px;
      color: var(--text);
    }
    .upload-zone {
      border: 1px dashed var(--card-border-light);
      border-radius: 6px;
      padding: 22px 14px;
      text-align: center;
      cursor: pointer;
      transition: border-color 0.2s ease, background-color 0.2s ease;
      background: var(--card-inner);
    }
    .upload-zone.dragover {
      background: #1C1C1C;
      border-color: #666666;
    }
    .upload-icon {
      font-size: 18px;
      margin-bottom: 4px;
      opacity: 0.7;
    }
    .upload-text {
      font-size: 14px;
      font-weight: 400;
      color: var(--text);
    }
    .upload-subtext {
      font-size: 12px;
      font-weight: 300;
      color: var(--text-muted);
      margin-top: 2px;
    }
    .upload-btn {
      display: inline-block;
      margin-top: 10px;
      background: transparent;
      color: var(--text);
      font-family: inherit;
      font-weight: 400;
      padding: 5px 14px;
      border-radius: 4px;
      border: 1px solid var(--card-border-light);
      font-size: 12px;
      letter-spacing: 0.5px;
      cursor: pointer;
    }
    .upload-btn:hover {
      background: #1F1F1F;
      border-color: #555555;
    }
    .file-card {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 10px;
      border-radius: 6px;
      background: var(--card-inner);
      border: 1px solid var(--card-border);
      margin-bottom: 6px;
      gap: 10px;
    }
    .file-card:last-child {
      margin-bottom: 0;
    }
    .file-info {
      flex: 1;
      min-width: 0;
    }
    .file-name {
      font-weight: 400;
      font-size: 13px;
      color: var(--text);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .file-path {
      font-size: 10px;
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      color: var(--text-muted);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      margin-top: 1px;
      margin-bottom: 2px;
      opacity: 0.85;
    }
    .file-meta {
      font-size: 11px;
      font-weight: 300;
      color: var(--text-muted);
      margin-top: 1px;
    }
    .btn-download {
      background: transparent;
      color: var(--text);
      border: 1px solid var(--card-border-light);
      padding: 4px 10px;
      border-radius: 4px;
      text-decoration: none;
      font-size: 12px;
      font-weight: 400;
      white-space: nowrap;
      letter-spacing: 0.3px;
    }
    .btn-download:hover {
      background: #1F1F1F;
      border-color: #555555;
    }
    .empty-state {
      text-align: center;
      padding: 16px 10px;
      color: var(--text-muted);
      font-size: 12px;
      font-weight: 300;
      line-height: 1.4;
    }
    .progress-bar-container {
      display: none;
      margin-top: 10px;
      height: 4px;
      background: #242424;
      border-radius: 2px;
      overflow: hidden;
    }
    .progress-bar-fill {
      height: 100%;
      background: #FFFFFF;
      width: 0%;
      transition: width 0.1s linear;
    }
    .status-text {
      font-size: 12px;
      font-weight: 300;
      margin-top: 6px;
      text-align: center;
      color: var(--text-secondary);
    }
    .clipboard-box {
      background: var(--card-inner);
      border: 1px solid var(--card-border);
      border-radius: 6px;
      padding: 10px 12px;
      margin-bottom: 8px;
    }
    .clip-text {
      font-size: 13px;
      color: var(--text);
      word-break: break-all;
      max-height: 80px;
      overflow-y: auto;
      white-space: pre-wrap;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    .clip-footer {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 8px;
      padding-top: 6px;
      border-top: 1px solid var(--card-border);
    }
    .clip-meta {
      font-size: 11px;
      color: var(--text-muted);
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .btn-sm {
      background: transparent;
      border: 1px solid var(--card-border-light);
      color: var(--text);
      font-size: 12px;
      padding: 3px 10px;
      border-radius: 4px;
      cursor: pointer;
      font-family: inherit;
    }
    .btn-sm:hover {
      background: #242424;
      border-color: #555555;
    }
    .clip-input-row {
      display: flex;
      gap: 6px;
    }
    .clip-input {
      flex: 1;
      background: var(--card-inner);
      border: 1px solid var(--card-border);
      color: var(--text);
      padding: 6px 10px;
      border-radius: 4px;
      font-size: 13px;
      font-family: inherit;
    }
    .clip-input:focus {
      outline: none;
      border-color: #555;
    }
    .btn-push {
      background: #1F1F1F;
      border: 1px solid var(--card-border-light);
      color: var(--text);
      padding: 6px 14px;
      border-radius: 4px;
      font-size: 12px;
      cursor: pointer;
      font-family: inherit;
      letter-spacing: 0.5px;
    }
    .btn-push:hover {
      background: #2D2D2D;
    }
    #fileInput { display: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="logo-badge"><span class="pulse-dot"></span> AirFile Hotspot Link</div>
      <h1>${_escapeHtml(deviceName)}</h1>
      <p class="subtitle">Direct Wi-Fi / Hotspot Peer Sharing</p>
    </div>

    <!-- Android Peer App Download Banner -->
    <div class="card" style="background: #141414; border-color: var(--card-border);">
      <div style="display: flex; align-items: center; justify-content: space-between; gap: 10px; flex-wrap: wrap;">
        <div>
          <div style="font-weight: 400; font-size: 13px; color: var(--text); display: flex; align-items: center; gap: 6px;">
            <span>🤖</span> AirFile Android App
          </div>
          <div style="font-size: 11px; font-weight: 300; color: var(--text-muted); margin-top: 2px;">
            Install on Redmi Pad or Android phone for high-speed P2P sharing
          </div>
        </div>
        <a href="/download/AirFile-Android.apk" download="AirFile-Android.apk" class="btn-download" style="padding: 5px 12px; font-size: 12px;">
          Download APK
        </a>
      </div>
    </div>

    <!-- Send to Mac Section -->
    <div class="card">
      <div class="card-title">📤 Send Files to Mac</div>
      <div class="upload-zone" id="dropZone" onclick="document.getElementById('fileInput').click()">
        <div class="upload-icon">📁</div>
        <div class="upload-text">Tap to select photos, videos, or documents</div>
        <div class="upload-subtext">Supports all file formats & sizes</div>
        <button type="button" class="upload-btn">Choose Files</button>
      </div>
      <input type="file" id="fileInput" multiple onchange="handleFiles(this.files)">
      <div class="progress-bar-container" id="progressContainer">
        <div class="progress-bar-fill" id="progressBar"></div>
      </div>
      <div class="status-text" id="statusText"></div>
    </div>

    <!-- Universal Clipboard Section -->
    <div class="card">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
        <div class="card-title" style="margin-bottom: 0;">📋 Universal Clipboard</div>
        <span id="clipBadge" style="font-size: 10px; padding: 2px 6px; background: #1A1A1A; border: 1px solid #333; border-radius: 3px; color: #A3A3A3; letter-spacing: 0.5px;">LIVE SYNC</span>
      </div>
      <div class="clipboard-box">
        <div id="clipContent" class="clip-text">Listening for clipboard text...</div>
        <div class="clip-footer">
          <span id="clipSender" class="clip-meta">Ready</span>
          <button id="btnCopyClip" class="btn-sm" onclick="copySyncedClip()">Copy to Device</button>
        </div>
      </div>
      <div class="clip-input-row">
        <input type="text" id="clipInput" class="clip-input" placeholder="Type or paste text to push to all devices..." onkeydown="if(event.key==='Enter') pushClipText()" />
        <button class="btn-push" onclick="pushClipText()">Push</button>
      </div>
    </div>

    <!-- Download from Mac Section -->
    <div class="card">
      <div class="card-title">📥 Available Downloads from Mac</div>
      $stagedItemsHtml
    </div>
  </div>

  <script>
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('fileInput');
    const progressContainer = document.getElementById('progressContainer');
    const progressBar = document.getElementById('progressBar');
    const statusText = document.getElementById('statusText');

    let currentClipboardText = '';

    async function fetchClipboard() {
      try {
        const res = await fetch('/api/clipboard');
        if (res.ok) {
          const data = await res.json();
          if (data.text && data.text !== currentClipboardText) {
            currentClipboardText = data.text;
            document.getElementById('clipContent').textContent = data.text;
            const sender = data.senderName ? 'From ' + data.senderName : 'Synced';
            document.getElementById('clipSender').textContent = sender;
          }
        }
      } catch (_) {}
    }

    async function copySyncedClip() {
      if (!currentClipboardText) return;
      try {
        await navigator.clipboard.writeText(currentClipboardText);
        const btn = document.getElementById('btnCopyClip');
        btn.textContent = 'Copied!';
        setTimeout(() => { btn.textContent = 'Copy to Device'; }, 2000);
      } catch (e) {
        alert('Could not copy automatically. Please select text manually.');
      }
    }

    async function pushClipText() {
      const input = document.getElementById('clipInput');
      const val = input.value.trim();
      if (!val) return;
      try {
        await fetch('/api/clipboard', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            senderId: 'web-client-' + Math.random().toString(36).substring(2, 7),
            senderName: 'Web Client',
            timestamp: new Date().toISOString(),
            hash: 'web_' + Date.now(),
            text: val
          })
        });
        input.value = '';
        currentClipboardText = val;
        document.getElementById('clipContent').textContent = val;
        document.getElementById('clipSender').textContent = 'Pushed by You';
      } catch (e) {
        alert('Failed to push text to devices');
      }
    }

    setInterval(fetchClipboard, 2000);
    fetchClipboard();

    ['dragenter', 'dragover'].forEach(name => {
      dropZone.addEventListener(name, (e) => { e.preventDefault(); dropZone.classList.add('dragover'); });
    });
    ['dragleave', 'drop'].forEach(name => {
      dropZone.addEventListener(name, (e) => { e.preventDefault(); dropZone.classList.remove('dragover'); });
    });
    dropZone.addEventListener('drop', (e) => {
      e.preventDefault();
      if (e.dataTransfer.files.length) handleFiles(e.dataTransfer.files);
    });

    async function handleFiles(files) {
      if (!files || files.length === 0) return;
      progressContainer.style.display = 'block';
      progressBar.style.width = '0%';
      statusText.textContent = 'Uploading ' + files.length + ' file(s)...';

      const formData = new FormData();
      for (let i = 0; i < files.length; i++) {
        formData.append('files', files[i], files[i].name);
      }

      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/web/upload', true);

      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          const percent = Math.round((e.loaded / e.total) * 100);
          progressBar.style.width = percent + '%';
          const loadedMb = (e.loaded / (1024 * 1024)).toFixed(1);
          const totalMb = (e.total / (1024 * 1024)).toFixed(1);
          statusText.textContent = `Uploading: \${percent}% (\${loadedMb} / \${totalMb} MB)`;
        }
      };

      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          progressBar.style.width = '100%';
          statusText.textContent = 'Transfer complete. Saved on device.';
          statusText.style.color = 'var(--text)';
          fileInput.value = '';
          setTimeout(() => {
            progressContainer.style.display = 'none';
            statusText.textContent = '';
            statusText.style.color = 'var(--text-secondary)';
          }, 4000);
        } else {
          statusText.textContent = 'Upload failed (' + xhr.status + ')';
          statusText.style.color = 'var(--text-secondary)';
        }
      };

      xhr.onerror = () => {
        statusText.textContent = 'Network error during transfer.';
        statusText.style.color = 'var(--text-secondary)';
      };

      xhr.send(formData);
    }
  </script>
</body>
</html>
''';

    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    request.response.close();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}
