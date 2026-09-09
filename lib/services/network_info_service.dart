import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class NetworkProfile {
  final String ip;
  final String? ipv6;
  final String interfaceName;
  final bool isHotspot;
  final String networkTypeLabel;
  final List<String> subnetCandidates;
  final bool isClatIpv6Only;
  final String? subnetBroadcast;

  const NetworkProfile({
    required this.ip,
    this.ipv6,
    required this.interfaceName,
    required this.isHotspot,
    required this.networkTypeLabel,
    required this.subnetCandidates,
    this.isClatIpv6Only = false,
    this.subnetBroadcast,
  });

  String get effectiveIp {
    if (isClatIpv6Only && ipv6 != null && ipv6!.isNotEmpty) {
      return '[$ipv6]';
    }
    return ip;
  }

  static NetworkProfile loopback = const NetworkProfile(
    ip: '127.0.0.1',
    interfaceName: 'lo0',
    isHotspot: false,
    networkTypeLabel: 'Loopback (No Network)',
    subnetCandidates: [],
  );
}

class NetworkInfoService extends ChangeNotifier {
  NetworkProfile _currentProfile = NetworkProfile.loopback;
  String _deviceName = Platform.localHostname;
  Timer? _monitorTimer;

  NetworkProfile get currentProfile => _currentProfile;
  String get deviceName => _deviceName;
  String get activeIp => _currentProfile.effectiveIp;
  String get ipv4 => _currentProfile.ip;
  bool get isHotspot => _currentProfile.isHotspot;

  NetworkInfoService() {
    _init();
  }

  Future<void> _init() async {
    _cleanDeviceName();
    await refreshNetwork();
    // Periodically re-check network in case user toggles hotspot or Wi-Fi
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (_) => refreshNetwork());
  }

  void _cleanDeviceName() {
    String host = Platform.localHostname;
    if (host.endsWith('.local')) {
      host = host.replaceAll('.local', '');
    }
    if (host.isEmpty) {
      host = 'MacBook';
    }
    _deviceName = host;
  }

  void updateDeviceName(String newName) {
    if (newName.trim().isNotEmpty) {
      _deviceName = newName.trim();
      notifyListeners();
    }
  }

  Future<void> refreshNetwork() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );

      NetworkProfile? selected;

      // Priority 1: Check for iPhone Hotspot (172.20.10.x or en0 with hotspot characteristics / 192.0.0.x)
      for (final interface in interfaces) {
        String? ipv4;
        String? ipv6;

        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4) {
            ipv4 ??= address.address;
          } else if (address.type == InternetAddressType.IPv6 &&
              !address.isLinkLocal &&
              !address.address.startsWith('fe80:')) {
            ipv6 ??= address.address;
          }
        }

        if (ipv4 != null && _isHotspot(ipv4, interface.name)) {
          selected = _buildHotspotProfile(ipv4, ipv6, interface.name);
          break;
        }
      }

      // Priority 2: Standard Wi-Fi / Ethernet LAN (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
      if (selected == null) {
        for (final interface in interfaces) {
          String? ipv4;
          String? ipv6;

          for (final address in interface.addresses) {
            if (address.type == InternetAddressType.IPv4) {
              ipv4 ??= address.address;
            } else if (address.type == InternetAddressType.IPv6 &&
                !address.isLinkLocal &&
                !address.address.startsWith('fe80:')) {
              ipv6 ??= address.address;
            }
          }

          if (ipv4 != null && _isPrivateLan(ipv4)) {
            selected = _buildLanProfile(ipv4, ipv6, interface.name);
            break;
          }
        }
      }

      // Priority 3: Any interface with IPv4 or IPv6
      if (selected == null && interfaces.isNotEmpty) {
        for (final interface in interfaces) {
          String? ipv4;
          String? ipv6;

          for (final address in interface.addresses) {
            if (address.type == InternetAddressType.IPv4) {
              ipv4 ??= address.address;
            } else if (address.type == InternetAddressType.IPv6 &&
                !address.isLinkLocal &&
                !address.address.startsWith('fe80:')) {
              ipv6 ??= address.address;
            }
          }

          if (ipv4 != null || ipv6 != null) {
            selected = _buildGenericProfile(ipv4 ?? ipv6!, ipv6, interface.name);
            break;
          }
        }
      }

      final newProfile = selected ?? NetworkProfile.loopback;

      if (_currentProfile.ip != newProfile.ip ||
          _currentProfile.ipv6 != newProfile.ipv6 ||
          _currentProfile.interfaceName != newProfile.interfaceName ||
          _currentProfile.isHotspot != newProfile.isHotspot ||
          _currentProfile.isClatIpv6Only != newProfile.isClatIpv6Only) {
        _currentProfile = newProfile;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error inspecting network interfaces: $e');
    }
  }

  bool _isHotspot(String ip, String interfaceName) {
    if (ip.startsWith('172.20.10.')) return true; // iPhone Hotspot
    if (ip.startsWith('192.168.43.')) return true; // Android Hotspot default
    if (ip.startsWith('192.168.49.')) return true; // Wi-Fi Direct
    if (ip.startsWith('192.0.0.')) return true; // CLAT 464 Hotspot
    return false;
  }

  bool _isPrivateLan(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]) ?? 0;
        if (second >= 16 && second <= 31) return true;
      }
    }
    return false;
  }

  NetworkProfile _buildHotspotProfile(String ip, String? ipv6, String interfaceName) {
    final candidates = <String>[];
    final isClat = ip.startsWith('192.0.0.');
    String? broadcast;

    if (ip.startsWith('172.20.10.')) {
      broadcast = '172.20.10.15';
      for (int i = 1; i <= 14; i++) {
        final hostIp = '172.20.10.$i';
        if (hostIp != ip) candidates.add(hostIp);
      }
    } else if (ip.startsWith('192.168.43.')) {
      broadcast = '192.168.43.255';
      candidates.add('192.168.43.1'); // Android phone hotspot gateway
      for (int i = 2; i <= 60; i++) {
        final hostIp = '192.168.43.$i';
        if (hostIp != ip) candidates.add(hostIp);
      }
    } else if (isClat) {
      for (int i = 1; i <= 20; i++) {
        final hostIp = '192.0.0.$i';
        if (hostIp != ip) candidates.add(hostIp);
      }
    }

    String label = 'Personal Hotspot ($interfaceName)';
    if (ip.startsWith('172.20.10.')) label = 'iPhone Hotspot ($interfaceName)';
    if (ip.startsWith('192.168.43.')) label = 'Android Hotspot ($interfaceName)';
    if (isClat) label = 'Hotspot (IPv6 / CLAT)';

    return NetworkProfile(
      ip: ip,
      ipv6: ipv6,
      interfaceName: interfaceName,
      isHotspot: true,
      networkTypeLabel: label,
      subnetCandidates: candidates,
      isClatIpv6Only: isClat,
      subnetBroadcast: broadcast,
    );
  }

  NetworkProfile _buildLanProfile(String ip, String? ipv6, String interfaceName) {
    final candidates = <String>[];
    String? broadcast;
    final parts = ip.split('.');
    if (parts.length == 4) {
      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      final currentHost = int.tryParse(parts[3]) ?? 1;
      broadcast = '$prefix.255';

      // 1. Gateway
      candidates.add('$prefix.1');

      // 2. Immediate neighbors window (±30)
      for (int offset = 1; offset <= 30; offset++) {
        final up = currentHost + offset;
        final down = currentHost - offset;
        if (up > 1 && up < 255 && '$prefix.$up' != ip) candidates.add('$prefix.$up');
        if (down > 1 && down < 255 && '$prefix.$down' != ip) candidates.add('$prefix.$down');
      }

      // 3. Full subnet hosts (2..254) so no device is ever missed
      for (int i = 2; i < 255; i++) {
        final candidate = '$prefix.$i';
        if (!candidates.contains(candidate) && candidate != ip) {
          candidates.add(candidate);
        }
      }
    }

    return NetworkProfile(
      ip: ip,
      ipv6: ipv6,
      interfaceName: interfaceName,
      isHotspot: false,
      networkTypeLabel: 'Local Wi-Fi / LAN ($interfaceName)',
      subnetCandidates: candidates,
      subnetBroadcast: broadcast,
    );
  }

  NetworkProfile _buildGenericProfile(String ip, String? ipv6, String interfaceName) {
    return NetworkProfile(
      ip: ip,
      ipv6: ipv6,
      interfaceName: interfaceName,
      isHotspot: false,
      networkTypeLabel: 'Network Interface ($interfaceName)',
      subnetCandidates: [],
    );
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }
}
