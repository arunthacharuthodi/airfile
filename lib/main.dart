import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/dev_debug_service.dart';
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
  try {
    await storageService.init();
  } catch (e) {
    debugPrint('StorageService init error: $e');
  }

  // 2. Initialize Network Profiler
  final networkInfoService = NetworkInfoService();
  try {
    await networkInfoService.refreshNetwork();
  } catch (e) {
    debugPrint('NetworkInfoService init error: $e');
  }

  final platformPrefix = Platform.operatingSystem;
  final deviceId = '${platformPrefix}_${Platform.localHostname}_${DateTime.now().millisecondsSinceEpoch % 10000}';

  // 3. Initialize Transfer Server
  final transferServer = TransferServer(
    storageService: storageService,
    deviceId: deviceId,
    deviceName: networkInfoService.deviceName,
  );
  try {
    await transferServer.start();
  } catch (e) {
    debugPrint('TransferServer start error: $e');
  }

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

  // 6. Initialize Dev Debug Service
  final devDebugService = DevDebugService();

  runApp(
    AirFileApp(
      storageService: storageService,
      networkInfoService: networkInfoService,
      transferServer: transferServer,
      transferClient: transferClient,
      discoveryService: discoveryService,
      devDebugService: devDebugService,
    ),
  );
}

class AirFileApp extends StatelessWidget {
  final StorageService storageService;
  final NetworkInfoService networkInfoService;
  final TransferServer transferServer;
  final TransferClient transferClient;
  final DiscoveryService discoveryService;
  final DevDebugService devDebugService;

  const AirFileApp({
    super.key,
    required this.storageService,
    required this.networkInfoService,
    required this.transferServer,
    required this.transferClient,
    required this.discoveryService,
    required this.devDebugService,
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
        devDebugService: devDebugService,
      ),
    );
  }
}
