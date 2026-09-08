import 'package:flutter/material.dart';

enum DeviceType {
  macos,
  ios,
  android,
  windows,
  linux,
  web,
  unknown;

  static DeviceType fromString(String? type) {
    if (type == null) return DeviceType.unknown;
    switch (type.toLowerCase()) {
      case 'macos':
      case 'mac':
      case 'darwin':
        return DeviceType.macos;
      case 'ios':
      case 'iphone':
      case 'ipad':
        return DeviceType.ios;
      case 'android':
        return DeviceType.android;
      case 'windows':
        return DeviceType.windows;
      case 'linux':
        return DeviceType.linux;
      case 'web':
      case 'browser':
        return DeviceType.web;
      default:
        return DeviceType.unknown;
    }
  }

  IconData get icon {
    switch (this) {
      case DeviceType.macos:
        return Icons.laptop_mac_rounded;
      case DeviceType.ios:
        return Icons.phone_iphone_rounded;
      case DeviceType.android:
        return Icons.phone_android_rounded;
      case DeviceType.windows:
        return Icons.desktop_windows_rounded;
      case DeviceType.linux:
        return Icons.terminal_rounded;
      case DeviceType.web:
        return Icons.language_rounded;
      case DeviceType.unknown:
        return Icons.devices_other_rounded;
    }
  }
}

enum ConnectionMedium {
  wifi,
  hotspot,
  bluetooth,
  direct;

  String get label {
    switch (this) {
      case ConnectionMedium.wifi:
        return 'Wi-Fi LAN';
      case ConnectionMedium.hotspot:
        return 'iPhone Hotspot';
      case ConnectionMedium.bluetooth:
        return 'Bluetooth LE';
      case ConnectionMedium.direct:
        return 'Direct Link';
    }
  }

  IconData get icon {
    switch (this) {
      case ConnectionMedium.wifi:
        return Icons.wifi_rounded;
      case ConnectionMedium.hotspot:
        return Icons.wifi_tethering_rounded;
      case ConnectionMedium.bluetooth:
        return Icons.bluetooth_searching_rounded;
      case ConnectionMedium.direct:
        return Icons.link_rounded;
    }
  }
}

class PeerDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final DeviceType deviceType;
  final ConnectionMedium medium;
  final DateTime lastSeen;
  final bool isOnline;
  final int colorSeed;

  const PeerDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.deviceType,
    required this.medium,
    required this.lastSeen,
    this.isOnline = true,
    this.colorSeed = 0,
  });

  bool get hasDirectIp {
    if (ip == 'BLE Nearby' || ip.isEmpty || ip.contains(' ')) return false;
    return true;
  }

  String get address => hasDirectIp ? 'http://$ip:$port' : 'BLE Nearby';

  PeerDevice copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    DeviceType? deviceType,
    ConnectionMedium? medium,
    DateTime? lastSeen,
    bool? isOnline,
    int? colorSeed,
  }) {
    return PeerDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      deviceType: deviceType ?? this.deviceType,
      medium: medium ?? this.medium,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      colorSeed: colorSeed ?? this.colorSeed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'type': deviceType.name,
      'medium': medium.name,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  factory PeerDevice.fromJson(Map<String, dynamic> json, {String? fallbackIp}) {
    return PeerDevice(
      id: json['id'] as String? ?? 'peer_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Unknown Device',
      ip: json['ip'] as String? ?? fallbackIp ?? '127.0.0.1',
      port: (json['port'] as num?)?.toInt() ?? 53317,
      deviceType: DeviceType.fromString(json['type'] as String?),
      medium: ConnectionMedium.values.firstWhere(
        (m) => m.name == json['medium'],
        orElse: () => ConnectionMedium.wifi,
      ),
      lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now(),
      colorSeed: ((json['id'] ?? json['name'] ?? 'seed').hashCode).abs() % 6,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerDevice &&
          runtimeType == other.runtimeType &&
          (id == other.id || (ip == other.ip && port == other.port));

  @override
  int get hashCode => id.hashCode ^ ip.hashCode ^ port.hashCode;
}
