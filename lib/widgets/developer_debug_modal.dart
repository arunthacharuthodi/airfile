import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/dev_debug_service.dart';
import '../services/discovery_service.dart';
import '../services/network_info_service.dart';
import '../theme/app_theme.dart';

class DeveloperDebugModal extends StatefulWidget {
  final DevDebugService devDebugService;
  final NetworkInfoService networkInfoService;
  final DiscoveryService discoveryService;

  const DeveloperDebugModal({
    super.key,
    required this.devDebugService,
    required this.networkInfoService,
    required this.discoveryService,
  });

  @override
  State<DeveloperDebugModal> createState() => _DeveloperDebugModalState();
}

class _DeveloperDebugModalState extends State<DeveloperDebugModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Form controllers
  final TextEditingController _pairIpController = TextEditingController();
  final TextEditingController _pairPortController = TextEditingController();
  final TextEditingController _pairCodeController = TextEditingController();

  final TextEditingController _connectIpController = TextEditingController();
  final TextEditingController _connectPortController = TextEditingController(text: '5555');

  final TextEditingController _customHostPortController = TextEditingController();
  final TextEditingController _customDevicePortController = TextEditingController();

  final TextEditingController _testPortController = TextEditingController(text: '3000');
  String? _portTestResult;
  bool _isTestingPort = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final ip = widget.networkInfoService.ipv4;
    if (ip.isNotEmpty && ip != '127.0.0.1' && !ip.startsWith('192.0.0.')) {
      _pairIpController.text = ip;
      _connectIpController.text = ip;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pairIpController.dispose();
    _pairPortController.dispose();
    _pairCodeController.dispose();
    _connectIpController.dispose();
    _connectPortController.dispose();
    _customHostPortController.dispose();
    _customDevicePortController.dispose();
    _testPortController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomAdb() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select adb Executable',
      type: FileType.any,
    );
    if (result.isNotEmpty && result.first.path != null) {
      await widget.devDebugService.setCustomAdbPath(result.first.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.bgSecondary,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.cardBorder, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.devDebugService,
            widget.networkInfoService,
            widget.discoveryService,
          ]),
          builder: (context, child) {
            final service = widget.devDebugService;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                _buildHeader(service),

                // Tab Bar
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.bgPrimary,
                    border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.accentWhite,
                    labelColor: AppTheme.textPrimary,
                    unselectedLabelColor: AppTheme.textMuted,
                    labelStyle: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.ptSans(fontSize: 13),
                    tabs: const [
                      Tab(icon: Icon(Icons.adb_rounded, size: 16), text: 'Android ADB Wi-Fi'),
                      Tab(icon: Icon(Icons.apple_rounded, size: 16), text: 'iOS Wireless'),
                      Tab(icon: Icon(Icons.lan_rounded, size: 16), text: 'Localhost Bridge'),
                    ],
                  ),
                ),

                // Tab Body
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAndroidTab(service),
                      _buildIosTab(service),
                      _buildLocalhostTab(service),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(DevDebugService service) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.bgPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: const Icon(Icons.bug_report_rounded, color: AppTheme.accentWhite, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Developer Support & Wireless Debug',
                        style: GoogleFonts.ptSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: service.isAdbAvailable
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: service.isAdbAvailable ? Colors.green : Colors.orange,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          service.isAdbAvailable ? 'ADB READY' : 'ADB MISSING',
                          style: GoogleFonts.ptSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: service.isAdbAvailable ? Colors.greenAccent : Colors.orangeAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pair and connect real mobile devices over Wi-Fi for VS Code, Flutter CLI & Android Studio/Xcode',
                    style: GoogleFonts.ptSans(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 20),
            tooltip: 'Close Modal',
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidTab(DevDebugService service) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ADB Binary Config Bar
          _buildAdbStatusCard(service),
          const SizedBox(height: 14),

          // Auto-Discovered Network Devices & Peers Selector
          _buildAutoDiscoveredIpSection(service),
          const SizedBox(height: 14),

          // IPv4 & ADB Guide Banner
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Tap any auto-discovered device above to select its IP instantly. Do not use 192.0.0.x (Mac internal CLAT). Ensure Pairing Port is from "Pair with pairing code" and Connect Port is from main Wireless Debugging screen.',
                    style: GoogleFonts.ptSans(fontSize: 11, color: Colors.lightBlueAccent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Saved Devices Memory (Quick Reconnect)
          if (service.savedDevices.isNotEmpty) ...[
            _buildSavedDevicesSection(service),
            const SizedBox(height: 16),
          ],

          // Active Connected Debug Devices
          _buildConnectedDevicesSection(service),
          const SizedBox(height: 16),

          // Pairing & Direct Connection Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pair Android 11+
              Expanded(child: _buildPairingCard(service)),
              const SizedBox(width: 14),
              // Direct Connect
              Expanded(child: _buildDirectConnectCard(service)),
            ],
          ),
          const SizedBox(height: 16),

          // Firebase & Localhost Reverse Port Forwarding
          _buildPortForwardingSection(service),
          const SizedBox(height: 16),

          // Console Logs Terminal Box
          _buildConsoleTerminal(service),
        ],
      ),
    );
  }

  Widget _buildAutoDiscoveredIpSection(DevDebugService service) {
    final peers = widget.discoveryService.peers;
    final saved = service.savedDevices;

    final Map<String, String> ipLabels = {};

    // 1. Discovered AirFile Peers (excluding 192.0.0.x CLAT interface)
    for (final peer in peers) {
      if (peer.ip.isNotEmpty && peer.ip != '127.0.0.1' && !peer.ip.startsWith('192.0.0.')) {
        ipLabels[peer.ip] = '📱 ${peer.name} (${peer.ip})';
      }
    }

    // 2. Saved Device History
    for (final dev in saved) {
      if (!ipLabels.containsKey(dev.ip) && !dev.ip.startsWith('192.0.0.')) {
        ipLabels[dev.ip] = '⭐ Saved (${dev.ip})';
      }
    }

    // 3. Current Host LAN IP
    final hostIp = widget.networkInfoService.ipv4;
    if (hostIp.isNotEmpty && hostIp != '127.0.0.1' && !hostIp.startsWith('192.0.0.') && !ipLabels.containsKey(hostIp)) {
      ipLabels[hostIp] = '💻 Host LAN ($hostIp)';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar_rounded, size: 15, color: AppTheme.accentWhite),
                  const SizedBox(width: 6),
                  Text(
                    'Auto-Discovered LAN Device IPs (Tap to Autofill)',
                    style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${ipLabels.length}',
                      style: GoogleFonts.ptSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentWhite),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  widget.discoveryService.triggerFastScan(isManual: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scanning local network for devices...')),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 13),
                label: Text('Scan LAN', style: GoogleFonts.ptSans(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.cardBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ipLabels.isEmpty)
            Text(
              'No active network devices detected. Click "Scan LAN" to discover devices.',
              style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ipLabels.entries.map((entry) {
                final selected = _pairIpController.text == entry.key;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _pairIpController.text = entry.key;
                      _connectIpController.text = entry.key;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Selected IP: ${entry.key}')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? Colors.green.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selected ? Colors.greenAccent : AppTheme.cardBorder),
                    ),
                    child: Text(
                      entry.value,
                      style: GoogleFonts.ptSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.greenAccent : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAdbStatusCard(DevDebugService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    service.isAdbAvailable ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                    size: 16,
                    color: service.isAdbAvailable ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ADB Binary Path:',
                    style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 6),
                  SelectableText(
                    service.adbExecutablePath ?? 'Not Found',
                    style: GoogleFonts.ptMono(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickCustomAdb,
                    icon: const Icon(Icons.folder_open_rounded, size: 13),
                    label: Text('Browse Path', style: GoogleFonts.ptSans(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.cardBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: service.isDownloadingAdb ? null : service.downloadAndInstallAdb,
                    icon: service.isDownloadingAdb
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentWhite),
                          )
                        : const Icon(Icons.download_rounded, size: 13),
                    label: Text(
                      service.isDownloadingAdb ? 'Downloading...' : 'Auto-Download ADB',
                      style: GoogleFonts.ptSans(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentWhite,
                      side: const BorderSide(color: AppTheme.cardBorderHover),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (service.isDownloadingAdb) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: service.downloadProgress > 0 ? service.downloadProgress : null,
              backgroundColor: Colors.white10,
              color: AppTheme.accentWhite,
            ),
            const SizedBox(height: 4),
            Text(
              service.downloadStatusText,
              style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSavedDevicesSection(DevDebugService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Saved Devices (Quick Reconnect Memory)',
              style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: service.savedDevices.map((dev) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_android_rounded, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${dev.ip}:${dev.connectionPort}',
                    style: GoogleFonts.ptMono(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      await service.connectAdbDevice(dev.ip, dev.connectionPort);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Reconnect',
                        style: GoogleFonts.ptSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentWhite),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => service.deleteSavedDevice(dev.ip),
                    icon: const Icon(Icons.close_rounded, size: 12, color: AppTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Remove saved memory',
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildConnectedDevicesSection(DevDebugService service) {
    final devices = service.connectedDevices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.devices_other_rounded, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Connected Debug Targets (Visible in VS Code / IDEs)',
                  style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${devices.length}',
                    style: GoogleFonts.ptSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentWhite),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: service.refreshStatus,
              icon: const Icon(Icons.refresh_rounded, size: 13, color: AppTheme.textSecondary),
              label: Text('Refresh', style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textSecondary)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (devices.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Text(
                  'No ADB devices connected. Pair or connect your mobile device below.',
                  style: GoogleFonts.ptSans(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          )
        else
          Column(
            children: devices.map((dev) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          dev.isWireless ? Icons.wifi_tethering_rounded : Icons.usb_rounded,
                          size: 16,
                          color: dev.isOnline ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${dev.model} (${dev.id})',
                              style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            Text(
                              dev.isWireless ? 'Wireless Network Target' : 'USB Connected',
                              style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: dev.isOnline ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dev.state.toUpperCase(),
                            style: GoogleFonts.ptSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: dev.isOnline ? Colors.greenAccent : Colors.orangeAccent,
                            ),
                          ),
                        ),
                        if (dev.isWireless) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => service.disconnectAdbDevice(dev.id),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              side: const BorderSide(color: AppTheme.cardBorder),
                            ),
                            child: Text('Disconnect', style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textMuted)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildPairingCard(DevDebugService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 15, color: AppTheme.accentWhite),
              const SizedBox(width: 6),
              Text(
                '1. Wireless Pairing (Android 11+)',
                style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'In Android Settings > Developer Options > Wireless Debugging > Pair with pairing code',
            style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pairIpController,
            style: GoogleFonts.ptSans(fontSize: 13),
            decoration: _inputDecoration('Device IP (e.g. 192.168.1.50)'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pairPortController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.ptSans(fontSize: 13),
                  decoration: _inputDecoration('Pairing Port'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _pairCodeController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.ptSans(fontSize: 13),
                  decoration: _inputDecoration('6-Digit Code'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ip = _pairIpController.text.trim();
                final port = int.tryParse(_pairPortController.text.trim());
                final code = _pairCodeController.text.trim();

                if (ip.isEmpty || port == null || code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in IP, Pairing Port, and 6-digit code')),
                  );
                  return;
                }

                await service.pairAdbDevice(ip, port, code);
              },
              icon: const Icon(Icons.link_rounded, size: 14),
              label: Text('Pair Device', style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentWhite,
                side: const BorderSide(color: AppTheme.cardBorderHover),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectConnectCard(DevDebugService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.power_rounded, size: 15, color: AppTheme.accentWhite),
              const SizedBox(width: 6),
              Text(
                '2. Direct Wireless Connect',
                style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Connect already paired device to make it active in VS Code / Flutter CLI target list',
            style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _connectIpController,
            style: GoogleFonts.ptSans(fontSize: 13),
            decoration: _inputDecoration('Device IP Address'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _connectPortController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.ptSans(fontSize: 13),
            decoration: _inputDecoration('ADB Connect Port (Default: 5555)'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final ip = _connectIpController.text.trim();
                final port = int.tryParse(_connectPortController.text.trim()) ?? 5555;

                if (ip.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter target Device IP')),
                  );
                  return;
                }

                await service.connectAdbDevice(ip, port);
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 15),
              label: Text('Connect to VS Code', style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentWhite,
                side: const BorderSide(color: AppTheme.cardBorderHover),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortForwardingSection(DevDebugService service) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, size: 15, color: AppTheme.accentWhite),
              const SizedBox(width: 6),
              Text(
                'Reverse Port Forwarding (Firebase & Localhost Emulator Helper)',
                style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Map desktop localhost servers directly to real physical mobile devices so apps hit desktop backend',
            style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),

          // Preset Quick Forward Buttons
          Text('Quick Forward Presets:', style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _presetChip(service, '8080 Web Server', 8080),
              _presetChip(service, '3000 Node/React', 3000),
              _presetChip(service, '5000 Firebase Hosting', 5000),
              _presetChip(service, '8085 Firestore Emulator', 8085),
              _presetChip(service, '9099 Auth Emulator', 9099),
            ],
          ),
          const SizedBox(height: 10),

          // Custom Reverse Mapping
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customHostPortController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.ptSans(fontSize: 12),
                  decoration: _inputDecoration('Host Port (e.g. 8080)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customDevicePortController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.ptSans(fontSize: 12),
                  decoration: _inputDecoration('Mobile Port (e.g. 8080)'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final hPort = int.tryParse(_customHostPortController.text.trim());
                  final dPort = int.tryParse(_customDevicePortController.text.trim()) ?? hPort;
                  if (hPort != null && dPort != null && service.connectedDevices.isNotEmpty) {
                    final target = service.connectedDevices.first.id;
                    await service.reversePortForward(target, hPort, dPort);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  side: const BorderSide(color: AppTheme.cardBorderHover),
                ),
                child: Text('Map Port', style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accentWhite)),
              ),
            ],
          ),

          // Active Reverse Rules
          if (service.reversedPorts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Active Reverse Rules:', style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            ...service.reversedPorts.map((rule) {
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Desktop tcp:${rule.hostPort}  ➜  Mobile tcp:${rule.devicePort}  (${rule.targetDevice})',
                      style: GoogleFonts.ptMono(fontSize: 11, color: AppTheme.textPrimary),
                    ),
                    IconButton(
                      onPressed: () => service.removeReversedPort(rule.targetDevice, rule.hostPort),
                      icon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _presetChip(DevDebugService service, String label, int port) {
    final active = service.reversedPorts.any((r) => r.hostPort == port);
    return InkWell(
      onTap: () async {
        if (service.connectedDevices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please connect an Android device first')),
          );
          return;
        }
        final target = service.connectedDevices.first.id;
        if (active) {
          await service.removeReversedPort(target, port);
        } else {
          await service.reversePortForward(target, port, port);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.blue.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? Colors.blueAccent : AppTheme.cardBorder),
        ),
        child: Text(
          active ? '✓ $label' : '+ $label',
          style: GoogleFonts.ptSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? Colors.blueAccent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildConsoleTerminal(DevDebugService service) {
    return Container(
      width: double.infinity,
      height: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CLI EXECUTION LOG TERMINAL',
                style: GoogleFonts.ptMono(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
              ),
              InkWell(
                onTap: service.clearLogs,
                child: Text('Clear Log', style: GoogleFonts.ptSans(fontSize: 10, color: AppTheme.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              reverse: true,
              child: SelectableText(
                service.consoleLogs.isEmpty ? 'Waiting for CLI execution...' : service.consoleLogs.join('\n'),
                style: GoogleFonts.ptMono(fontSize: 11, color: Colors.greenAccent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIosTab(DevDebugService service) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.apple_rounded, size: 24, color: AppTheme.accentWhite),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('iOS Wireless Remote Debugging Guide', style: GoogleFonts.ptSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text('Apple devicectl & Safari Web Inspector integration for iOS real devices', style: GoogleFonts.ptSans(fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Steps to Debug iOS Devices Over Wi-Fi:', style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 10),
                _iosStep('1', 'Connect your iPhone/iPad to Mac via USB cable once.'),
                _iosStep('2', 'In Xcode > Window > Devices and Simulators, check "Connect via network".'),
                _iosStep('3', 'Disconnect USB cable. The device stays connected over Wi-Fi!'),
                _iosStep('4', 'Run "flutter devices" or inspect via devicectl in terminal.'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // devicectl command helper
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SelectableText(
                  'xcrun devicectl list devices',
                  style: GoogleFonts.ptMono(fontSize: 12, color: Colors.cyanAccent),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'xcrun devicectl list devices'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Command copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
                  tooltip: 'Copy Command',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iosStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
            child: Text(num, style: GoogleFonts.ptSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentWhite)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.ptSans(fontSize: 12, color: AppTheme.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildLocalhostTab(DevDebugService service) {
    final activeIp = widget.networkInfoService.activeIp;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Host PC Network IP Addresses', style: GoogleFonts.ptSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          Text('Use these LAN IP addresses in your mobile app configuration to connect to desktop dev servers', style: GoogleFonts.ptSans(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 14),

          // IP Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wifi_rounded, color: AppTheme.accentWhite, size: 16),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Active Wi-Fi / Network IP:', style: GoogleFonts.ptSans(fontSize: 11, color: AppTheme.textMuted)),
                        SelectableText('http://$activeIp:3000', style: GoogleFonts.ptMono(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      ],
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: 'http://$activeIp:3000'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied to clipboard!')));
                  },
                  icon: const Icon(Icons.copy_rounded, size: 13),
                  label: Text('Copy URL', style: GoogleFonts.ptSans(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentWhite,
                    side: const BorderSide(color: AppTheme.cardBorderHover),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Local Server Port Inspector
          Text('Desktop Dev Server Port Tester', style: GoogleFonts.ptSans(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          Text('Verify if local dev server (e.g. 3000, 8080, 5000) is running and accessible on host PC', style: GoogleFonts.ptSans(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testPortController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.ptSans(fontSize: 13),
                  decoration: _inputDecoration('Port Number (e.g. 3000, 8080)'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _isTestingPort
                    ? null
                    : () async {
                        final port = int.tryParse(_testPortController.text.trim());
                        if (port == null) return;
                        setState(() {
                          _isTestingPort = true;
                          _portTestResult = null;
                        });
                        final isOpen = await service.isPortOpen(port);
                        setState(() {
                          _isTestingPort = false;
                          _portTestResult = isOpen
                              ? 'SUCCESS: Local server is listening on port $port!'
                              : 'NOT FOUND: Port $port is closed or not listening.';
                        });
                      },
                icon: const Icon(Icons.speed_rounded, size: 14),
                label: Text('Test Port', style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentWhite,
                  side: const BorderSide(color: AppTheme.cardBorderHover),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          if (_portTestResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _portTestResult!.startsWith('SUCCESS')
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _portTestResult!.startsWith('SUCCESS') ? Colors.green : Colors.red,
                ),
              ),
              child: Text(
                _portTestResult!,
                style: GoogleFonts.ptSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _portTestResult!.startsWith('SUCCESS') ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      hintStyle: GoogleFonts.ptSans(fontSize: 12, color: AppTheme.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppTheme.cardBorder),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}
