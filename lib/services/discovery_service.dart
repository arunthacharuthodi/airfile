import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/peer_device.dart';
import 'network_info_service.dart';

class DiscoveryService extends ChangeNotifier {
  static const int broadcastPort = 53318;
  static const String multicastGroup = '224.0.0.167';

  final NetworkInfoService networkInfoService;
  final String localDeviceId;
  final int localPort;

  final Map<String, PeerDevice> _peerMap = {};
  bool _isScanning = false;
  bool _isManualScanning = false;
  Timer? _sweepTimer;
  Timer? _udpBeaconTimer;
  RawDatagramSocket? _udpSocket;
  StreamSubscription? _bleScanSubscription;
  bool _isBluetoothAvailable = false;

  List<PeerDevice> get peers => _peerMap.values.toList()
    ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

  bool get isScanning => _isScanning;
  bool get isManualScanning => _isManualScanning;
  bool get isBluetoothAvailable => _isBluetoothAvailable;

  DiscoveryService({
    required this.networkInfoService,
    required this.localDeviceId,
    required this.localPort,
  }) {
    _init();
  }

  Future<void> _init() async {
    await _startUdpListener();
    _initBluetooth();
    startContinuousDiscovery();
  }

  void startContinuousDiscovery() {
    _sweepTimer?.cancel();
    _udpBeaconTimer?.cancel();

    // Trigger initial scan silently in background
    triggerFastScan(isManual: false);

    // Periodic sweep every 5 seconds (silent in background)
    _sweepTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      triggerFastScan(isManual: false);
      _pruneStalePeers();
    });

    // Send UDP beacons every 3 seconds
    _udpBeaconTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendUdpBeacon();
    });
  }

  void stopContinuousDiscovery() {
    _sweepTimer?.cancel();
    _udpBeaconTimer?.cancel();
    _stopBluetoothScan();
  }

  Future<void> triggerFastScan({bool isManual = false}) async {
    if (_isScanning) return;
    _isScanning = true;
    if (isManual) {
      _isManualScanning = true;
      notifyListeners();
    }

    try {
      final candidates = networkInfoService.currentProfile.subnetCandidates;
      final isHotspot = networkInfoService.isHotspot;

      if (candidates.isNotEmpty) {
        // Run parallel HTTP ping sweep across candidate IPs in batches of 35
        const batchSize = 35;
        for (int i = 0; i < candidates.length; i += batchSize) {
          final chunk = candidates.skip(i).take(batchSize);
          await Future.wait(chunk.map((targetIp) => _pingTarget(targetIp, isHotspot)));
        }
      }

      // Also trigger a quick BLE scan burst if Bluetooth is on
      _scanBluetoothBurst();
    } catch (e) {
      debugPrint('Discovery sweep error: $e');
    } finally {
      _isScanning = false;
      if (isManual) {
        _isManualScanning = false;
        notifyListeners();
      }
    }
  }

  Future<void> _pingTarget(String targetIp, bool isHotspot) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(milliseconds: 400);

    try {
      final uri = Uri.parse('http://$targetIp:$localPort/api/ping');
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(milliseconds: 500));

      if (response.statusCode == HttpStatus.ok) {
        final body = await utf8.decoder.bind(response).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        final peer = PeerDevice.fromJson(
          json,
          fallbackIp: targetIp,
        ).copyWith(
          medium: isHotspot ? ConnectionMedium.hotspot : ConnectionMedium.wifi,
          lastSeen: DateTime.now(),
          isOnline: true,
        );

        if (peer.id != localDeviceId) {
          _peerMap[peer.id] = peer;
          notifyListeners();
        }
      }
    } catch (_) {
      // Expected for inactive IPs
    } finally {
      client.close();
    }
  }

  Future<bool> probeDirectIp(String ip, [int? port]) async {
    final targetPort = port ?? localPort;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);

    try {
      final uri = Uri.parse('http://$ip:$targetPort/api/ping');
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 2));

      if (response.statusCode == HttpStatus.ok) {
        final body = await utf8.decoder.bind(response).join();
        final json = jsonDecode(body) as Map<String, dynamic>;

        final peer = PeerDevice.fromJson(
          json,
          fallbackIp: ip,
        ).copyWith(
          medium: ConnectionMedium.direct,
          lastSeen: DateTime.now(),
          isOnline: true,
        );

        _peerMap[peer.id] = peer;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Direct probe failed for $ip:$targetPort - $e');
    } finally {
      client.close();
    }
    return false;
  }

  Future<void> _startUdpListener() async {
    try {
      try {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          broadcastPort,
          reuseAddress: true,
          reusePort: !Platform.isAndroid,
        );
      } catch (_) {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          broadcastPort,
          reuseAddress: true,
          reusePort: false,
        );
      }
      _udpSocket!.broadcastEnabled = true;

      try {
        _udpSocket!.joinMulticast(InternetAddress(multicastGroup));
      } catch (_) {}

      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            _handleUdpDatagram(datagram);
          }
        }
      });
    } catch (e) {
      debugPrint('UDP listener bind error: $e');
    }
  }

  void _handleUdpDatagram(Datagram datagram) {
    try {
      final senderIp = datagram.address.address;
      if (senderIp == networkInfoService.activeIp) return; // Ignore own beacon

      final message = utf8.decode(datagram.data);
      final json = jsonDecode(message) as Map<String, dynamic>;

      if (json['tag'] == 'AIRFILE_BEACON') {
        final peer = PeerDevice.fromJson(
          json,
          fallbackIp: senderIp,
        ).copyWith(
          medium: networkInfoService.isHotspot ? ConnectionMedium.hotspot : ConnectionMedium.wifi,
          lastSeen: DateTime.now(),
          isOnline: true,
        );

        if (peer.id != localDeviceId) {
          _peerMap[peer.id] = peer;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void _sendUdpBeacon() {
    if (_udpSocket == null || networkInfoService.activeIp == '127.0.0.1') return;

    try {
      final payload = jsonEncode({
        'tag': 'AIRFILE_BEACON',
        'id': localDeviceId,
        'name': networkInfoService.deviceName,
        'ip': networkInfoService.activeIp,
        'port': localPort,
        'type': Platform.isMacOS
            ? 'macos'
            : (Platform.isWindows
                ? 'windows'
                : (Platform.isAndroid ? 'android' : 'ios')),
        'medium': networkInfoService.isHotspot ? 'hotspot' : 'wifi',
        'timestamp': DateTime.now().toIso8601String(),
      });

      final data = utf8.encode(payload);

      // 1. Send to multicast group
      _udpSocket?.send(data, InternetAddress(multicastGroup), broadcastPort);

      // 2. Send to global broadcast address 255.255.255.255
      _udpSocket?.send(data, InternetAddress('255.255.255.255'), broadcastPort);

      // 3. Send to directed subnet broadcast if available
      final subnetBroadcast = networkInfoService.currentProfile.subnetBroadcast;
      if (subnetBroadcast != null) {
        try {
          _udpSocket?.send(data, InternetAddress(subnetBroadcast), broadcastPort);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _initBluetooth() async {
    try {
      final supported = await FlutterBluePlus.isSupported;
      _isBluetoothAvailable = supported;

      if (supported) {
        FlutterBluePlus.adapterState.listen((state) {
          _isBluetoothAvailable = (state == BluetoothAdapterState.on);
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('Bluetooth initialization notice (macOS): $e');
      _isBluetoothAvailable = false;
    }
  }

  Future<void> _scanBluetoothBurst() async {
    if (!_isBluetoothAvailable) return;

    try {
      if (FlutterBluePlus.isScanningNow) return;

      _bleScanSubscription?.cancel();
      _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final advName = r.advertisementData.advName;
          final platformName = r.device.platformName;
          final name = advName.isNotEmpty ? advName : platformName;

          if (name.isNotEmpty) {
            final id = 'ble_${r.device.remoteId.str}';
            if (!_peerMap.containsKey(id)) {
              _peerMap[id] = PeerDevice(
                id: id,
                name: name,
                ip: 'BLE Nearby',
                port: localPort,
                deviceType: _guessDeviceTypeFromBle(name),
                medium: ConnectionMedium.bluetooth,
                lastSeen: DateTime.now(),
                isOnline: true,
              );
              notifyListeners();
            }
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      debugPrint('Bluetooth scan notice: $e');
    }
  }

  DeviceType _guessDeviceTypeFromBle(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('iphone')) return DeviceType.ios;
    if (lower.contains('ipad')) return DeviceType.ios;
    if (lower.contains('macbook') || lower.contains('mac')) return DeviceType.macos;
    if (lower.contains('pixel') || lower.contains('samsung') || lower.contains('galaxy') || lower.contains('android')) {
      return DeviceType.android;
    }
    if (lower.contains('pc') || lower.contains('windows')) return DeviceType.windows;
    return DeviceType.unknown;
  }

  void _stopBluetoothScan() {
    _bleScanSubscription?.cancel();
    try {
      FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  void _pruneStalePeers() {
    final now = DateTime.now();
    bool changed = false;

    _peerMap.removeWhere((id, peer) {
      // Mark as offline or remove if not seen in 20 seconds
      if (now.difference(peer.lastSeen).inSeconds > 20) {
        changed = true;
        return true;
      }
      return false;
    });

    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopContinuousDiscovery();
    _udpSocket?.close();
    super.dispose();
  }
}
