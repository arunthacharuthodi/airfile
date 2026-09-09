import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AdbDevice {
  final String id;
  final String ipPort;
  final String name;
  final String model;
  final String state; // 'device', 'unauthorized', 'offline'
  final bool isWireless;

  const AdbDevice({
    required this.id,
    required this.ipPort,
    required this.name,
    required this.model,
    required this.state,
    required this.isWireless,
  });

  bool get isOnline => state == 'device';
}

class SavedAdbDevice {
  final String id;
  final String ip;
  final int connectionPort;
  final int? pairingPort;
  final String name;
  final DateTime lastConnected;

  SavedAdbDevice({
    required this.id,
    required this.ip,
    required this.connectionPort,
    this.pairingPort,
    required this.name,
    required this.lastConnected,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ip': ip,
        'connectionPort': connectionPort,
        'pairingPort': pairingPort,
        'name': name,
        'lastConnected': lastConnected.toIso8601String(),
      };

  factory SavedAdbDevice.fromJson(Map<String, dynamic> json) => SavedAdbDevice(
        id: json['id'] ?? '',
        ip: json['ip'] ?? '',
        connectionPort: json['connectionPort'] ?? 5555,
        pairingPort: json['pairingPort'],
        name: json['name'] ?? 'Android Device',
        lastConnected: DateTime.tryParse(json['lastConnected'] ?? '') ?? DateTime.now(),
      );
}

class ReversedPortRule {
  final String targetDevice;
  final int hostPort;
  final int devicePort;

  const ReversedPortRule({
    required this.targetDevice,
    required this.hostPort,
    required this.devicePort,
  });
}

class DevDebugService extends ChangeNotifier {
  String? _customAdbPath;
  String? _resolvedAdbPath;
  bool _isAdbAvailable = false;
  String _adbVersion = 'Unknown';
  bool _isDownloadingAdb = false;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';

  List<AdbDevice> _connectedDevices = [];
  List<SavedAdbDevice> _savedDevices = [];
  List<ReversedPortRule> _reversedPorts = [];
  final List<String> _consoleLogs = [];

  Timer? _refreshTimer;

  String? get adbExecutablePath => _resolvedAdbPath ?? _customAdbPath;
  bool get isAdbAvailable => _isAdbAvailable;
  String get adbVersion => _adbVersion;
  bool get isDownloadingAdb => _isDownloadingAdb;
  double get downloadProgress => _downloadProgress;
  String get downloadStatusText => _downloadStatusText;

  List<AdbDevice> get connectedDevices => List.unmodifiable(_connectedDevices);
  List<SavedAdbDevice> get savedDevices => List.unmodifiable(_savedDevices);
  List<ReversedPortRule> get reversedPorts => List.unmodifiable(_reversedPorts);
  List<String> get consoleLogs => List.unmodifiable(_consoleLogs);

  DevDebugService() {
    _init();
  }

  Future<void> _init() async {
    await _loadConfig();
    await checkAdbStatus();
    await loadSavedDevices();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => refreshStatus());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _log(String text) {
    final timestamp = DateTime.now().toString().split('.').first.split(' ').last;
    _consoleLogs.add('[$timestamp] $text');
    if (_consoleLogs.length > 150) {
      _consoleLogs.removeAt(0);
    }
    notifyListeners();
  }

  void clearLogs() {
    _consoleLogs.clear();
    notifyListeners();
  }

  Future<File> _getConfigFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'AirFile'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'adb_config.json'));
  }

  Future<void> _loadConfig() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data['customAdbPath'] != null && (data['customAdbPath'] as String).isNotEmpty) {
          _customAdbPath = data['customAdbPath'];
        }
      }
    } catch (e) {
      debugPrint('Error loading adb_config.json: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final file = await _getConfigFile();
      await file.writeAsString(jsonEncode({
        'customAdbPath': _customAdbPath ?? '',
      }));
    } catch (e) {
      debugPrint('Error saving adb_config.json: $e');
    }
  }

  Future<void> setCustomAdbPath(String? path) async {
    _customAdbPath = path;
    await _saveConfig();
    await checkAdbStatus();
  }

  Future<void> checkAdbStatus() async {
    _resolvedAdbPath = null;
    _isAdbAvailable = false;
    _adbVersion = 'Not Installed';

    // 1. Check custom path if set
    if (_customAdbPath != null && _customAdbPath!.isNotEmpty) {
      final file = File(_customAdbPath!);
      if (await file.exists()) {
        _resolvedAdbPath = _customAdbPath;
      }
    }

    // 2. Check auto-downloaded app path
    if (_resolvedAdbPath == null) {
      final docs = await getApplicationDocumentsDirectory();
      final downloadedAdb = File(p.join(
        docs.path,
        'AirFile',
        'adb',
        'platform-tools',
        Platform.isWindows ? 'adb.exe' : 'adb',
      ));
      if (await downloadedAdb.exists()) {
        _resolvedAdbPath = downloadedAdb.path;
      }
    }

    // 3. Check environment PATH and default locations
    if (_resolvedAdbPath == null) {
      final candidates = <String>[];
      if (Platform.isWindows) {
        candidates.add('adb.exe');
        final localAppData = Platform.environment['LOCALAPPDATA'];
        if (localAppData != null) {
          candidates.add(p.join(localAppData, 'Android', 'Sdk', 'platform-tools', 'adb.exe'));
        }
      } else {
        candidates.add('adb');
        final home = Platform.environment['HOME'];
        if (home != null) {
          candidates.add(p.join(home, 'Library', 'Android', 'sdk', 'platform-tools', 'adb'));
          candidates.add(p.join(home, 'Android', 'Sdk', 'platform-tools', 'adb'));
          candidates.add('/opt/homebrew/bin/adb');
          candidates.add('/usr/local/bin/adb');
        }
      }

      for (final candidate in candidates) {
        try {
          final res = await Process.run(candidate, ['version']);
          if (res.exitCode == 0) {
            _resolvedAdbPath = candidate;
            break;
          }
        } catch (_) {}
      }
    }

    // Verify resolving ADB version
    if (_resolvedAdbPath != null) {
      try {
        final res = await Process.run(_resolvedAdbPath!, ['version']);
        if (res.exitCode == 0) {
          _isAdbAvailable = true;
          final firstLine = (res.stdout as String).split('\n').first;
          _adbVersion = firstLine.replaceAll('Android Debug Bridge version ', '').trim();
          _log('ADB operational using binary at: $_resolvedAdbPath ($_adbVersion)');
        }
      } catch (e) {
        _isAdbAvailable = false;
        _adbVersion = 'Error verifying ADB binary';
      }
    } else {
      _log('ADB executable not found. Use custom path or auto-download ADB Platform-Tools.');
    }

    notifyListeners();
  }

  Future<void> downloadAndInstallAdb() async {
    if (_isDownloadingAdb) return;

    _isDownloadingAdb = true;
    _downloadProgress = 0.0;
    _downloadStatusText = 'Starting download from Google SDK repository...';
    notifyListeners();
    _log('Downloading Google Android SDK Platform-Tools...');

    try {
      final docs = await getApplicationDocumentsDirectory();
      final adbDir = Directory(p.join(docs.path, 'AirFile', 'adb'));
      if (!await adbDir.exists()) {
        await adbDir.create(recursive: true);
      }

      String url;
      if (Platform.isMacOS) {
        url = 'https://dl.google.com/android/repository/platform-tools-latest-darwin.zip';
      } else if (Platform.isWindows) {
        url = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip';
      } else {
        url = 'https://dl.google.com/android/repository/platform-tools-latest-linux.zip';
      }

      final zipPath = p.join(adbDir.path, 'platform-tools.zip');
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      final totalBytes = response.contentLength;
      int receivedBytes = 0;

      final file = File(zipPath);
      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress = receivedBytes / totalBytes;
          _downloadStatusText = 'Downloading: ${(_downloadProgress * 100).toStringAsFixed(0)}%';
          notifyListeners();
        }
      }
      await sink.close();

      _downloadStatusText = 'Extracting platform-tools archive...';
      _log('Download completed. Extracting archive...');
      notifyListeners();

      // Extract ZIP natively
      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-Command',
          'Expand-Archive -Path "$zipPath" -DestinationPath "${adbDir.path}" -Force'
        ]);
        if (result.exitCode != 0) {
          throw Exception('Failed to extract ZIP: ${result.stderr}');
        }
      } else {
        final result = await Process.run('unzip', ['-o', zipPath, '-d', adbDir.path]);
        if (result.exitCode != 0) {
          throw Exception('Failed to extract ZIP: ${result.stderr}');
        }
        // Set permissions on macOS/Linux
        final binaryPath = p.join(adbDir.path, 'platform-tools', 'adb');
        await Process.run('chmod', ['+x', binaryPath]);
      }

      // Cleanup zip
      if (await file.exists()) {
        await file.delete();
      }

      _downloadStatusText = 'ADB Installed successfully!';
      _log('Platform-Tools installed successfully!');
      await checkAdbStatus();
    } catch (e) {
      _downloadStatusText = 'Download failed: $e';
      _log('ADB download error: $e');
    } finally {
      _isDownloadingAdb = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    if (!_isAdbAvailable || _resolvedAdbPath == null) return;
    await fetchConnectedDevices();
    await refreshReversedPorts();
  }

  Future<void> fetchConnectedDevices() async {
    if (!_isAdbAvailable || _resolvedAdbPath == null) return;
    try {
      final res = await Process.run(_resolvedAdbPath!, ['devices', '-l']);
      if (res.exitCode == 0) {
        final output = res.stdout as String;
        final lines = output.split('\n');
        final list = <AdbDevice>[];

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('List of devices attached')) continue;

          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final id = parts[0];
            final state = parts[1];

            String model = 'Android Device';
            String name = id;

            for (final part in parts.skip(2)) {
              if (part.startsWith('model:')) {
                model = part.replaceAll('model:', '').replaceAll('_', ' ');
              } else if (part.startsWith('device:')) {
                name = part.replaceAll('device:', '');
              }
            }

            final isWireless = id.contains(':') || id.contains('.');
            list.add(AdbDevice(
              id: id,
              ipPort: id,
              name: name,
              model: model,
              state: state,
              isWireless: isWireless,
            ));
          }
        }
        _connectedDevices = list;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching ADB devices: $e');
    }
  }

  Future<bool> pairAdbDevice(String ip, int port, String pairingCode) async {
    if (!_isAdbAvailable || _resolvedAdbPath == null) {
      _log('Cannot pair: ADB not found.');
      return false;
    }

    final cleanIp = ip.trim().replaceAll('[', '').replaceAll(']', '');
    if (cleanIp.startsWith('192.0.0.')) {
      _log('❌ Error: $cleanIp is a Mac internal CLAT translation interface, not your phone\'s IP. Please check phone Wi-Fi settings for its actual IP (e.g. 192.168.x.x or 172.20.10.x).');
      return false;
    }

    if (cleanIp.contains(':')) {
      _log('⚠️ Warning: ADB requires an IPv4 address (e.g. 192.168.1.50). IPv6 ($cleanIp) causes protocol errors in ADB.');
    }

    final target = '$cleanIp:$port';
    _log('Executing: adb pair $target $pairingCode');

    try {
      final res = await Process.run(_resolvedAdbPath!, ['pair', target, pairingCode]);
      final stdoutText = (res.stdout as String).trim();
      final stderrText = (res.stderr as String).trim();

      if (stdoutText.isNotEmpty) _log('ADB stdout: $stdoutText');
      if (stderrText.isNotEmpty) _log('ADB stderr: $stderrText');

      if (res.exitCode == 0 || stdoutText.contains('Successfully paired')) {
        _log('Successfully paired to $target!');
        await saveDevice(SavedAdbDevice(
          id: cleanIp,
          ip: cleanIp,
          connectionPort: 5555,
          pairingPort: port,
          name: 'Android Device ($cleanIp)',
          lastConnected: DateTime.now(),
        ));
        return true;
      } else {
        _log('Pairing failed for $target. Tip: Use Phone\'s IPv4 address from Wi-Fi settings.');
        return false;
      }
    } catch (e) {
      _log('Pairing process exception: $e');
      return false;
    }
  }

  Future<bool> connectAdbDevice(String ip, int port) async {
    if (!_isAdbAvailable || _resolvedAdbPath == null) {
      _log('Cannot connect: ADB not found.');
      return false;
    }

    final cleanIp = ip.trim().replaceAll('[', '').replaceAll(']', '');
    if (cleanIp.startsWith('192.0.0.')) {
      _log('❌ Error: $cleanIp is a Mac internal CLAT translation interface, not your phone\'s IP. Please check phone Wi-Fi settings for its actual IP (e.g. 192.168.x.x or 172.20.10.x).');
      return false;
    }

    if (cleanIp.contains(':')) {
      _log('⚠️ Warning: ADB requires an IPv4 address (e.g. 192.168.1.50). IPv6 ($cleanIp) causes connection errors in ADB.');
    }

    final target = '$cleanIp:$port';
    _log('Executing: adb connect $target');

    try {
      final res = await Process.run(_resolvedAdbPath!, ['connect', target]);
      final stdoutText = (res.stdout as String).trim();
      final stderrText = (res.stderr as String).trim();

      if (stdoutText.isNotEmpty) _log('ADB stdout: $stdoutText');
      if (stderrText.isNotEmpty) _log('ADB stderr: $stderrText');

      final success = res.exitCode == 0 &&
          (stdoutText.contains('connected to') || stdoutText.contains('already connected'));

      if (success) {
        _log('Device $target connected & active in VS Code / IDEs!');
        await saveDevice(SavedAdbDevice(
          id: cleanIp,
          ip: cleanIp,
          connectionPort: port,
          name: 'Android Device ($cleanIp)',
          lastConnected: DateTime.now(),
        ));
        await refreshStatus();
        return true;
      } else {
        _log('Connect failed for $target. Tip: Verify using Phone\'s IPv4 address & Wireless Connect Port.');
        return false;
      }
    } catch (e) {
      _log('Connect process exception: $e');
      return false;
    }
  }

  Future<bool> disconnectAdbDevice(String target) async {
    if (!_isAdbAvailable || _resolvedAdbPath == null) return false;
    _log('Executing: adb disconnect $target');
    try {
      final res = await Process.run(_resolvedAdbPath!, ['disconnect', target]);
      _log((res.stdout as String).trim());
      await refreshStatus();
      return res.exitCode == 0;
    } catch (e) {
      _log('Disconnect error: $e');
      return false;
    }
  }

  Future<bool> reversePortForward(String target, int hostPort, int devicePort) async {
    if (!_isAdbAvailable || _resolvedAdbPath == null) return false;
    _log('Executing: adb -s $target reverse tcp:$hostPort tcp:$devicePort');
    try {
      final res = await Process.run(
          _resolvedAdbPath!, ['-s', target, 'reverse', 'tcp:$hostPort', 'tcp:$devicePort']);
      final out = (res.stdout as String).trim();
      _log('Reverse mapping created: Host $hostPort -> Mobile $devicePort ($out)');
      await refreshReversedPorts();
      return res.exitCode == 0;
    } catch (e) {
      _log('Reverse port forward error: $e');
      return false;
    }
  }

  Future<void> refreshReversedPorts() async {
    if (!_isAdbAvailable || _resolvedAdbPath == null || _connectedDevices.isEmpty) {
      _reversedPorts = [];
      notifyListeners();
      return;
    }

    final rules = <ReversedPortRule>[];
    for (final dev in _connectedDevices) {
      if (!dev.isOnline) continue;
      try {
        final res = await Process.run(_resolvedAdbPath!, ['-s', dev.id, 'reverse', '--list']);
        if (res.exitCode == 0) {
          final lines = (res.stdout as String).split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;
            final parts = trimmed.split(RegExp(r'\s+'));
            if (parts.length >= 3) {
              final hPortStr = parts[1].replaceAll('tcp:', '');
              final dPortStr = parts[2].replaceAll('tcp:', '');
              final hPort = int.tryParse(hPortStr);
              final dPort = int.tryParse(dPortStr);
              if (hPort != null && dPort != null) {
                rules.add(ReversedPortRule(
                  targetDevice: dev.id,
                  hostPort: hPort,
                  devicePort: dPort,
                ));
              }
            }
          }
        }
      } catch (_) {}
    }
    _reversedPorts = rules;
    notifyListeners();
  }

  Future<bool> removeReversedPort(String target, int hostPort) async {
    if (!_isAdbAvailable || _resolvedAdbPath == null) return false;
    _log('Executing: adb -s $target reverse --remove tcp:$hostPort');
    try {
      final res = await Process.run(
          _resolvedAdbPath!, ['-s', target, 'reverse', '--remove', 'tcp:$hostPort']);
      await refreshReversedPorts();
      return res.exitCode == 0;
    } catch (e) {
      _log('Error removing reversed port: $e');
      return false;
    }
  }

  // Persistent Device Memory
  Future<File> _getSavedDevicesFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'AirFile'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'adb_saved_devices.json'));
  }

  Future<void> loadSavedDevices() async {
    try {
      final file = await _getSavedDevicesFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final List list = jsonDecode(raw);
        _savedDevices = list.map((e) => SavedAdbDevice.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading saved ADB devices: $e');
    }
  }

  Future<void> saveDevice(SavedAdbDevice device) async {
    try {
      _savedDevices.removeWhere((d) => d.ip == device.ip);
      _savedDevices.insert(0, device);
      final file = await _getSavedDevicesFile();
      await file.writeAsString(jsonEncode(_savedDevices.map((e) => e.toJson()).toList()));
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving ADB device: $e');
    }
  }

  Future<void> deleteSavedDevice(String ip) async {
    try {
      _savedDevices.removeWhere((d) => d.ip == ip);
      final file = await _getSavedDevicesFile();
      await file.writeAsString(jsonEncode(_savedDevices.map((e) => e.toJson()).toList()));
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting saved ADB device: $e');
    }
  }

  // iOS Tooling
  Future<bool> checkXcodeAvailable() async {
    if (!Platform.isMacOS) return false;
    try {
      final res = await Process.run('xcrun', ['devicectl', 'list', 'devices']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // Local Server Port Tester
  Future<bool> isPortOpen(int port) async {
    try {
      final socket = await Socket.connect('127.0.0.1', port, timeout: const Duration(seconds: 1));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
