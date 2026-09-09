import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'discovery_service.dart';
import 'pairing_service.dart';

class ClipboardSyncService extends ChangeNotifier {
  final DiscoveryService discoveryService;
  final String localDeviceId;
  final String localDeviceName;
  final int localPort;
  PairingService? pairingService;

  bool _autoSyncEnabled = true;
  String? _currentText;
  String? _lastSyncedHash;
  String? _lastSenderDeviceName;
  DateTime? _lastSyncTime;
  bool _isBroadcasting = false;
  Timer? _pollingTimer;

  bool get autoSyncEnabled => _autoSyncEnabled;
  String? get currentText => _currentText;
  String? get lastSenderDeviceName => _lastSenderDeviceName;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isBroadcasting => _isBroadcasting;
  bool get hasContent => _currentText != null && _currentText!.isNotEmpty;

  ClipboardSyncService({
    required this.discoveryService,
    required this.localDeviceId,
    required this.localDeviceName,
    required this.localPort,
    this.pairingService,
  }) {
    _startMonitoring();
  }

  void _startMonitoring() {
    _pollingTimer?.cancel();

    // macOS & Windows: gentle 1.5s background polling
    // Android & iOS: 2.5s polling while app is running
    final interval = (Platform.isMacOS || Platform.isWindows)
        ? const Duration(milliseconds: 1500)
        : const Duration(milliseconds: 2500);

    _pollingTimer = Timer.periodic(interval, (_) {
      checkLocalClipboard();
    });

    // Check initial clipboard
    checkLocalClipboard();
  }

  void setAutoSync(bool enabled) {
    if (_autoSyncEnabled != enabled) {
      _autoSyncEnabled = enabled;
      notifyListeners();
    }
  }

  String _hashText(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  /// Inspects local OS clipboard. If changed, updates internal state and optionally broadcasts.
  Future<void> checkLocalClipboard({bool forceBroadcast = false}) async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.trim().isEmpty) return;

      final hash = _hashText(text);

      // If text hasn't changed, skip
      if (hash == _lastSyncedHash && !forceBroadcast) return;

      _lastSyncedHash = hash;
      _currentText = text;
      _lastSenderDeviceName = localDeviceName;
      _lastSyncTime = DateTime.now();
      notifyListeners();

      if (_autoSyncEnabled || forceBroadcast) {
        await broadcastToPeers(text, hash);
      }
    } catch (e) {
      debugPrint('ClipboardSyncService check error: $e');
    }
  }

  /// Broadcasts clipboard text to all active paired peers.
  Future<void> broadcastToPeers(String text, [String? textHash]) async {
    final hash = textHash ?? _hashText(text);
    // Broadcast to all active online peers
    final peers = discoveryService.peers.where((p) => p.isOnline).toList();
    if (peers.isEmpty) return;

    _isBroadcasting = true;
    notifyListeners();

    final payload = jsonEncode({
      'tag': 'AIRFILE_CLIPBOARD',
      'senderId': localDeviceId,
      'senderName': localDeviceName,
      'timestamp': DateTime.now().toIso8601String(),
      'hash': hash,
      'text': text,
    });

    final futures = peers.map((peer) async {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 1500);
      try {
        final uri = Uri.parse('http://${peer.ip}:${peer.port}/api/clipboard');
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.headers.set('X-Device-Id', localDeviceId);
        final token = pairingService?.getAuthToken(peer.id);
        if (token != null && token.isNotEmpty) {
          request.headers.set('X-Auth-Token', token);
        }
        request.write(payload);
        final response = await request.close().timeout(const Duration(milliseconds: 2000));
        await response.drain();
      } catch (_) {
        // Peer may be busy or unreachable
      } finally {
        client.close();
      }
    });

    await Future.wait(futures);
    _isBroadcasting = false;
    notifyListeners();
  }

  /// Handles incoming clipboard update received via HTTP POST /api/clipboard.
  Future<bool> handleIncomingClipboard(Map<String, dynamic> data) async {
    try {
      final senderId = data['senderId'] as String?;
      final senderName = (data['senderName'] as String?) ?? 'Nearby Device';
      final hash = data['hash'] as String?;
      final text = data['text'] as String?;

      // Echo & loop prevention: ignore if sent by self
      if (senderId == localDeviceId) return false;

      // Ignore if text is empty or identical to our current hash
      if (text == null || text.isEmpty || hash == null) return false;
      if (hash == _lastSyncedHash) return false;

      // Update state
      _lastSyncedHash = hash;
      _currentText = text;
      _lastSenderDeviceName = senderName;
      _lastSyncTime = DateTime.now();

      // Write to local OS clipboard
      await Clipboard.setData(ClipboardData(text: text));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error handling incoming clipboard: $e');
      return false;
    }
  }

  /// Manually copies the current synced text to OS clipboard.
  Future<void> copyCurrentToClipboard() async {
    if (_currentText != null && _currentText!.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _currentText!));
    }
  }

  /// Manually pushes current local clipboard to all peers immediately.
  Future<void> pushLocalClipboardNow() async {
    await checkLocalClipboard(forceBroadcast: true);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
