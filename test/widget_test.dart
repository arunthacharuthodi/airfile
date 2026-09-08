import 'package:flutter_test/flutter_test.dart';
import 'package:airfile_mac/models/file_payload.dart';
import 'package:airfile_mac/models/peer_device.dart';
import 'package:airfile_mac/services/network_info_service.dart';
import 'package:airfile_mac/services/pairing_service.dart';

void main() {
  test('PeerDevice model serialization', () {
    final peer = PeerDevice(
      id: 'test_peer',
      name: 'iPhone 15',
      ip: '172.20.10.3',
      port: 53317,
      deviceType: DeviceType.ios,
      medium: ConnectionMedium.hotspot,
      lastSeen: DateTime.now(),
    );

    final json = peer.toJson();
    final restored = PeerDevice.fromJson(json);

    expect(restored.id, 'test_peer');
    expect(restored.name, 'iPhone 15');
    expect(restored.ip, '172.20.10.3');
    expect(restored.deviceType, DeviceType.ios);
    expect(restored.medium, ConnectionMedium.hotspot);
  });

  test('FilePayload model formatting', () {
    final payload = FilePayload(
      id: 'test_file',
      name: 'document.pdf',
      size: 15 * 1024 * 1024, // 15MB
      mimeType: 'application/pdf',
      isOutgoing: true,
      peerName: 'Receiver Mac',
      peerAddress: 'http://172.20.10.4:53317',
    );

    expect(payload.formattedSize, '15.0 MB');
    expect(payload.status, TransferStatus.queued);
  });

  test('NetworkProfile default loopback', () {
    final profile = NetworkProfile.loopback;
    expect(profile.ip, '127.0.0.1');
    expect(profile.isHotspot, false);
  });

  test('PairedDevice serialization and deserialization', () {
    final now = DateTime.now();
    final paired = PairedDevice(
      id: 'mac_001',
      name: 'MacBook Pro',
      token: 'secret_token_123',
      pairedAt: now,
    );

    final json = paired.toJson();
    final restored = PairedDevice.fromJson(json);

    expect(restored.id, 'mac_001');
    expect(restored.name, 'MacBook Pro');
    expect(restored.token, 'secret_token_123');
  });

  test('IncomingPairRequest accept and decline flow', () async {
    final request = IncomingPairRequest(
      initiatorId: 'dev_123',
      initiatorName: 'iPad Pro',
      initiatorIp: '192.168.1.20',
      initiatorPort: 53317,
      code: '849201',
      secret: 'token_abc',
    );

    expect(request.code, '849201');
    expect(request.secret, 'token_abc');

    request.respond(true);
    final accepted = await request.response;
    expect(accepted, isTrue);
  });
}
