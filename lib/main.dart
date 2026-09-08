import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/discovery_service.dart';
import 'services/network_info_service.dart';
import 'services/storage_service.dart';
import 'services/transfer_client.dart';
import 'services/transfer_server.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Storage
  final storageService = StorageService();
  await storageService.init();

  // 2. Initialize Network Profiler
  final networkInfoService = NetworkInfoService();
  await networkInfoService.refreshNetwork();

  final deviceId = 'mac_${Platform.localHostname}_${DateTime.now().millisecondsSinceEpoch % 10000}';

  // 3. Initialize Transfer Server
  final transferServer = TransferServer(
    storageService: storageService,
    deviceId: deviceId,
    deviceName: networkInfoService.deviceName,
  );
  await transferServer.start();

  // 4. Initialize Transfer Client
  final transferClient = TransferClient(
    senderDeviceId: deviceId,
    senderDeviceName: networkInfoService.deviceName,
  );

  // 5. Initialize Discovery Service (Ping sweep + UDP multicast + BLE)
  final discoveryService = DiscoveryService(
    networkInfoService: networkInfoService,
    localDeviceId: deviceId,
    localPort: transferServer.port,
  );

  runApp(
    AirFileApp(
      storageService: storageService,
      networkInfoService: networkInfoService,
      transferServer: transferServer,
      transferClient: transferClient,
      discoveryService: discoveryService,
    ),
  );
}

class AirFileApp extends StatelessWidget {
  final StorageService storageService;
  final NetworkInfoService networkInfoService;
  final TransferServer transferServer;
  final TransferClient transferClient;
  final DiscoveryService discoveryService;

  const AirFileApp({
    super.key,
    required this.storageService,
    required this.networkInfoService,
    required this.transferServer,
    required this.transferClient,
    required this.discoveryService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirFile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeScreen(
        storageService: storageService,
        networkInfoService: networkInfoService,
        transferServer: transferServer,
        transferClient: transferClient,
        discoveryService: discoveryService,
      ),
    );
  }
}
