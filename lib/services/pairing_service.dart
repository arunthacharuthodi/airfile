import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/peer_device.dart';
import 'storage_service.dart';

class PairedDevice {
  final String id;
  final String name;
  final String token;
  final DateTime pairedAt;

  const PairedDevice({
    required this.id,
    required this.name,
    required this.token,
    required this.pairedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'token': token,
    'pairedAt': pairedAt.toIso8601String(),
  };

  factory PairedDevice.fromJson(Map<String, dynamic> json) => PairedDevice(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Device',
    token: json['token'] as String,
    pairedAt: DateTime.tryParse(json['pairedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class IncomingPairRequest {
  final String initiatorId;
  final String initiatorName;
  final String initiatorIp;
  final int initiatorPort;
  final String code;
  final String secret;
  final Completer<bool> _completer = Completer<bool>();

  IncomingPairRequest({
    required this.initiatorId,
    required this.initiatorName,
    required this.initiatorIp,
    required this.initiatorPort,
    required this.code,
    required this.secret,
  });

  Future<bool> get response => _completer.future;

  void respond(bool accepted) {
    if (!_completer.isCompleted) {
      _completer.complete(accepted);
    }
  }
}

class PairingService extends ChangeNotifier {
  final StorageService storageService;
  final String localDeviceId;
  final String localDeviceName;

  final Map<String, PairedDevice> _pairedDevices = {};
  IncomingPairRequest? _currentIncomingRequest;

  Map<String, PairedDevice> get pairedDevices => Map.unmodifiable(_pairedDevices);
  IncomingPairRequest? get currentIncomingRequest => _currentIncomingRequest;
  bool get hasIncomingRequest => _currentIncomingRequest != null;

  PairingService({
    required this.storageService,
    required this.localDeviceId,
    required this.localDeviceName,
  }) {
    init();
  }

  Future<void> init() async {
    await _loadPersistedPairings();
  }

  File _getConfigFile() {
    return File(p.join(storageService.downloadPath, '.paired_devices.json'));
  }

  Future<void> _loadPersistedPairings() async {
    try {
      final file = _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        _pairedDevices.clear();
        for (final item in list) {
          final device = PairedDevice.fromJson(item as Map<String, dynamic>);
          _pairedDevices[device.id] = device;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading paired devices: $e');
    }
  }

  Future<void> _savePersistedPairings() async {
    try {
      final file = _getConfigFile();
      final list = _pairedDevices.values.map((d) => d.toJson()).toList();
      await file.writeAsString(jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving paired devices: $e');
    }
  }

  bool isPaired(String deviceId) => _pairedDevices.containsKey(deviceId);

  PairedDevice? getPairedDevice(String deviceId) => _pairedDevices[deviceId];

  String? getAuthToken(String deviceId) => _pairedDevices[deviceId]?.token;

  bool verifyToken(String deviceId, String? token) {
    if (token == null || token.isEmpty) return false;
    final device = _pairedDevices[deviceId];
    if (device == null) return false;
    return device.token == token;
  }

  /// Initiates pairing with a remote peer using a 6-digit verification code.
  Future<({bool success, String code, String? error})> initiatePairing(
    PeerDevice peer, {
    void Function(String code)? onCodeGenerated,
  }) async {
    if (!peer.hasDirectIp) {
      return (success: false, code: '', error: 'Peer does not have a direct IP connection.');
    }

    // Generate 6-digit numeric verification code (e.g. "849 201")
    final random = Random.secure();
    final code = (100000 + random.nextInt(900000)).toString();
    onCodeGenerated?.call(code);

    // Generate random secret token
    final secretBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = sha256.convert(secretBytes).toString();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 3);

    try {
      final uri = Uri.parse('http://${peer.ip}:${peer.port}/api/pair/request');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;

      final body = jsonEncode({
        'initiatorId': localDeviceId,
        'initiatorName': localDeviceName,
        'code': code,
        'token': token,
      });

      request.write(body);
      // Give the user up to 45 seconds to review and accept on the target screen
      final response = await request.close().timeout(const Duration(seconds: 45));

      if (response.statusCode == HttpStatus.ok) {
        final resBody = await utf8.decoder.bind(response).join();
        final json = jsonDecode(resBody) as Map<String, dynamic>;

        if (json['accepted'] == true) {
          final pairedToken = (json['token'] as String?) ?? token;
          _pairedDevices[peer.id] = PairedDevice(
            id: peer.id,
            name: peer.name,
            token: pairedToken,
            pairedAt: DateTime.now(),
          );
          await _savePersistedPairings();
          notifyListeners();
          return (success: true, code: code, error: null);
        } else {
          return (success: false, code: code, error: 'Pairing request was declined.');
        }
      } else {
        return (success: false, code: code, error: 'Peer responded with code ${response.statusCode}');
      }
    } on TimeoutException {
      return (success: false, code: code, error: 'Pairing timed out. Code was not accepted in time.');
    } catch (e) {
      return (success: false, code: code, error: 'Connection error: $e');
    } finally {
      client.close();
    }
  }

  /// Handles incoming pairing request from a remote peer.
  Future<({bool accepted, String token})> handleIncomingRequest({
    required String initiatorId,
    required String initiatorName,
    required String initiatorIp,
    required int initiatorPort,
    required String code,
    required String token,
  }) async {
    final pairRequest = IncomingPairRequest(
      initiatorId: initiatorId,
      initiatorName: initiatorName,
      initiatorIp: initiatorIp,
      initiatorPort: initiatorPort,
      code: code,
      secret: token,
    );

    _currentIncomingRequest = pairRequest;
    notifyListeners();

    final accepted = await pairRequest.response;
    _currentIncomingRequest = null;
    notifyListeners();

    if (accepted) {
      _pairedDevices[initiatorId] = PairedDevice(
        id: initiatorId,
        name: initiatorName,
        token: token,
        pairedAt: DateTime.now(),
      );
      await _savePersistedPairings();
      notifyListeners();
    }

    return (accepted: accepted, token: token);
  }

  void respondToCurrentRequest(bool accept) {
    if (_currentIncomingRequest != null) {
      _currentIncomingRequest!.respond(accept);
    }
  }

  Future<void> unpairDevice(String deviceId, [PeerDevice? onlinePeer]) async {
    _pairedDevices.remove(deviceId);
    await _savePersistedPairings();
    notifyListeners();

    if (onlinePeer != null && onlinePeer.hasDirectIp) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 2);
        final uri = Uri.parse('http://${onlinePeer.ip}:${onlinePeer.port}/api/pair/unpair');
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'deviceId': localDeviceId}));
        final response = await request.close().timeout(const Duration(seconds: 2));
        await response.drain();
        client.close();
      } catch (_) {}
    }
  }

  void handlePeerUnpairNotification(String peerId) {
    if (_pairedDevices.containsKey(peerId)) {
      _pairedDevices.remove(peerId);
      _savePersistedPairings();
      notifyListeners();
    }
  }
}
