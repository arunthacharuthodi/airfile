import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/file_payload.dart';
import '../models/peer_device.dart';
import '../services/discovery_service.dart';
import '../services/network_info_service.dart';
import '../services/storage_service.dart';
import '../services/transfer_client.dart';
import '../services/transfer_server.dart';
import '../theme/app_theme.dart';
import '../widgets/drag_drop_staging_zone.dart';
import '../widgets/peer_card.dart';
import '../widgets/qr_hotspot_modal.dart';
import '../widgets/radar_visualizer.dart';
import '../widgets/share_to_device_modal.dart';
import '../widgets/transfer_progress_card.dart';

class HomeScreen extends StatefulWidget {
  final NetworkInfoService networkInfoService;
  final DiscoveryService discoveryService;
  final TransferServer transferServer;
  final TransferClient transferClient;
  final StorageService storageService;

  const HomeScreen({
    super.key,
    required this.networkInfoService,
    required this.discoveryService,
    required this.transferServer,
    required this.transferClient,
    required this.storageService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _directIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.transferServer.onTransferProgress = (_) {
      if (mounted) setState(() {});
    };
    widget.transferServer.onTransferCompleted = (payload) {
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Received ${payload.name} from ${payload.peerName}',
              style: GoogleFonts.alumniSans(fontSize: 13, fontWeight: FontWeight.w300),
            ),
            action: payload.savedPath != null
                ? SnackBarAction(
                    label: 'Show in Finder',
                    textColor: AppTheme.accentWhite,
                    onPressed: () => widget.storageService.revealInFinder(payload.savedPath!),
                  )
                : null,
          ),
        );
      }
    };
  }

  @override
  void dispose() {
    _directIpController.dispose();
    super.dispose();
  }

  void _showQrModal() {
    showDialog(
      context: context,
      builder: (_) => QrHotspotModal(
        ip: widget.networkInfoService.activeIp,
        port: widget.transferServer.port,
        isHotspot: widget.networkInfoService.isHotspot,
        deviceName: widget.networkInfoService.deviceName,
      ),
    );
  }

  void _showDirectConnectDialog() {
    _directIpController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Connect by IP Address',
          style: GoogleFonts.alumniSans(fontSize: 17, fontWeight: FontWeight.w400),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter peer device IP address:',
              style: GoogleFonts.alumniSans(fontSize: 13, fontWeight: FontWeight.w300, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _directIpController,
              autofocus: true,
              style: GoogleFonts.alumniSans(fontSize: 14, fontWeight: FontWeight.w300),
              decoration: InputDecoration(
                hintText: widget.networkInfoService.isHotspot ? '172.20.10.1' : '192.168.1.50',
                prefixIcon: const Icon(Icons.lan_outlined, color: AppTheme.textSecondary, size: 16),
                isDense: true,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.alumniSans(fontSize: 13, color: AppTheme.textMuted)),
          ),
          OutlinedButton(
            onPressed: () async {
              final ip = _directIpController.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await widget.discoveryService.probeDirectIp(ip);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Connected to peer at $ip' : 'Could not reach device at $ip',
                        style: GoogleFonts.alumniSans(fontSize: 13),
                      ),
                    ),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentWhite,
              side: const BorderSide(color: AppTheme.cardBorderHover),
            ),
            child: Text('Connect', style: GoogleFonts.alumniSans(fontSize: 13, fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendStagedFilesToPeer(PeerDevice peer) async {
    final staged = widget.transferServer.stagedFiles;
    if (staged.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please stage files first by dropping them in or clicking Browse',
            style: GoogleFonts.alumniSans(fontSize: 13),
          ),
        ),
      );
      return;
    }

    if (!peer.hasDirectIp) {
      showDialog(
        context: context,
        builder: (_) => ShareToDeviceModal(
          peer: peer,
          stagedFiles: staged,
          localIp: widget.networkInfoService.activeIp,
          localPort: widget.transferServer.port,
          isHotspot: widget.networkInfoService.isHotspot,
          onSendToDirectIp: (targetIp) async {
            final directPeer = peer.copyWith(ip: targetIp, medium: ConnectionMedium.direct);
            await _sendDirectFilesToPeer(directPeer);
          },
        ),
      );
      return;
    }

    await _sendDirectFilesToPeer(peer);
  }

  Future<void> _sendDirectFilesToPeer(PeerDevice peer) async {
    final staged = widget.transferServer.stagedFiles;
    for (final file in staged) {
      await widget.transferClient.sendFile(
        peer: peer,
        filePath: file.path,
        onComplete: (payload) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Successfully sent ${payload.name} to ${peer.name}',
                  style: GoogleFonts.alumniSans(fontSize: 13),
                ),
              ),
            );
          }
        },
        onError: (payload, err) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Notice: $err',
                  style: GoogleFonts.alumniSans(fontSize: 13),
                ),
              ),
            );
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.networkInfoService,
        widget.discoveryService,
        widget.transferServer,
        widget.transferClient,
      ]),
      builder: (context, child) {
        final profile = widget.networkInfoService.currentProfile;
        final peers = widget.discoveryService.peers;
        final stagedFiles = widget.transferServer.stagedFiles;
        final activeTransfers = [
          ...widget.transferClient.outgoingTransfers.where((t) => t.status.isActive),
          ...widget.transferServer.activeTransfers.where((t) => t.status.isActive),
        ];
        final completedTransfers = [
          ...widget.transferServer.transferHistory,
          ...widget.transferClient.outgoingTransfers.where((t) => t.status.isDone),
        ];

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Top App Header
                _buildTopAppBar(profile),

                // Main Content Area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Radar, Staged Files, Discovered Devices
                            Expanded(
                              flex: 7,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(20, 14, 14, 20),
                                child: _buildMainColumn(
                                  peers: peers,
                                  stagedFiles: stagedFiles,
                                  profile: profile,
                                ),
                              ),
                            ),

                            // Right Column: Active Transfers & Transfer History
                            Expanded(
                              flex: 4,
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: AppTheme.cardBorder, width: 1),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(14, 14, 20, 20),
                                  child: _buildSideColumn(
                                    activeTransfers: activeTransfers,
                                    completedTransfers: completedTransfers,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Mobile & Portrait Tablet Layout (Android phones & tablets)
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMainColumn(
                                peers: peers,
                                stagedFiles: stagedFiles,
                                profile: profile,
                              ),
                              const SizedBox(height: 20),
                              const Divider(color: AppTheme.cardBorder, height: 1),
                              const SizedBox(height: 18),
                              _buildSideColumn(
                                activeTransfers: activeTransfers,
                                completedTransfers: completedTransfers,
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainColumn({
    required List<PeerDevice> peers,
    required List<StagedFile> stagedFiles,
    required NetworkProfile profile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Radar Visualizer
        RadarVisualizer(
          isScanning: widget.discoveryService.isManualScanning,
          peerCount: peers.length,
          onScanPressed: () => widget.discoveryService.triggerFastScan(isManual: true),
        ),
        const SizedBox(height: 14),

        // Drag & Drop Staging Area
        DragDropStagingZone(
          stagedFiles: stagedFiles,
          onFileAdded: widget.transferServer.stageFile,
          onFileRemoved: widget.transferServer.removeStagedFile,
          onClearAll: widget.transferServer.clearStagedFiles,
        ),
        const SizedBox(height: 18),

        // Discovered Peers Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.devices_outlined, color: AppTheme.textPrimary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Discovered Peers',
                  style: GoogleFonts.alumniSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                  ),
                  child: Text(
                    '${peers.length}',
                    style: GoogleFonts.alumniSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _showDirectConnectDialog,
              icon: const Icon(Icons.add_link_rounded, size: 14, color: AppTheme.textSecondary),
              label: Text(
                'Direct IP',
                style: GoogleFonts.alumniSans(fontSize: 13, color: AppTheme.textSecondary),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Peer List or Empty Placeholder
        if (peers.isEmpty)
          _buildNoPeersPlaceholder(profile.isHotspot)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: peers.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final peer = peers[index];
              return PeerCard(
                peer: peer,
                stagedCount: stagedFiles.length,
                onSendPressed: () => _sendStagedFilesToPeer(peer),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSideColumn({
    required List<FilePayload> activeTransfers,
    required List<FilePayload> completedTransfers,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Transfers Header
        Row(
          children: [
            const Icon(Icons.sync_rounded, color: AppTheme.textSecondary, size: 15),
            const SizedBox(width: 8),
            Text(
              'Live Transfers',
              style: GoogleFonts.alumniSans(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppTheme.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            if (activeTransfers.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${activeTransfers.length}',
                  style: GoogleFonts.alumniSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.accentWhite,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (activeTransfers.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Center(
              child: Text(
                'No active transfers',
                style: GoogleFonts.alumniSans(fontSize: 12, fontWeight: FontWeight.w300, color: AppTheme.textMuted),
              ),
            ),
          )
        else
          ...activeTransfers.map(
            (payload) => TransferProgressCard(
              payload: payload,
              storageService: widget.storageService,
              onCancel: () => widget.transferClient.cancelTransfer(payload.id),
            ),
          ),

        const SizedBox(height: 20),

        // Transfer History Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, color: AppTheme.textSecondary, size: 15),
                const SizedBox(width: 8),
                Text(
                  'Recent History',
                  style: GoogleFonts.alumniSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (completedTransfers.isNotEmpty) ...[
                  TextButton(
                    onPressed: () {
                      widget.transferClient.clearCompleted();
                      widget.transferServer.clearHistory();
                      setState(() {});
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      'Clear All',
                      style: GoogleFonts.alumniSans(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                TextButton.icon(
                  onPressed: widget.storageService.openDownloadsFolder,
                  icon: const Icon(Icons.folder_outlined, size: 13, color: AppTheme.textSecondary),
                  label: Text(
                    'Downloads',
                    style: GoogleFonts.alumniSans(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (completedTransfers.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Center(
              child: Text(
                'Transfers will appear here',
                style: GoogleFonts.alumniSans(fontSize: 12, fontWeight: FontWeight.w300, color: AppTheme.textMuted),
              ),
            ),
          )
        else
          ...completedTransfers.map(
            (payload) => TransferProgressCard(
              payload: payload,
              storageService: widget.storageService,
              onDismiss: () {
                widget.transferClient.dismissTransfer(payload.id);
                widget.transferServer.dismissTransfer(payload.id);
                setState(() {});
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTopAppBar(NetworkProfile profile) {
    final isMac = Platform.isMacOS;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 560;

    return Container(
      padding: EdgeInsets.only(
        left: isMac ? 84 : 16,
        right: 16,
        top: isMac ? 14 : 10,
        bottom: 10,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorder, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand & Name
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.cardBorderHover, width: 1),
                ),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.share_outlined, color: AppTheme.accentWhite, size: 15),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'AIRFILE',
                        style: GoogleFonts.alumniSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                        ),
                        child: Text(
                          Platform.isMacOS
                            ? 'MAC'
                            : (Platform.isWindows
                                ? 'WINDOWS'
                                : (Platform.isAndroid ? 'ANDROID' : 'PEER')),
                          style: GoogleFonts.alumniSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.8,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    widget.networkInfoService.deviceName,
                    style: GoogleFonts.alumniSans(fontSize: 12, fontWeight: FontWeight.w300, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ),

          // Actions & Badges
          Row(
            children: [
              // Network Profile Pill (Full on desktop/tablet, compact on mobile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(
                      profile.isHotspot ? Icons.wifi_tethering_rounded : Icons.wifi_rounded,
                      size: 13,
                      color: AppTheme.textSecondary,
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${profile.networkTypeLabel}: ${profile.effectiveIp}',
                        style: GoogleFonts.alumniSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (!isCompact) ...[
                const SizedBox(width: 8),
                // Bluetooth Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bluetooth_rounded,
                        size: 13,
                        color: widget.discoveryService.isBluetoothAvailable
                            ? AppTheme.accentWhite
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.discoveryService.isBluetoothAvailable ? 'BLE ON' : 'BLE OFF',
                        style: GoogleFonts.alumniSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: widget.discoveryService.isBluetoothAvailable
                              ? AppTheme.textSecondary
                              : AppTheme.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),

              // QR Code Button
              OutlinedButton.icon(
                onPressed: _showQrModal,
                icon: const Icon(Icons.qr_code_rounded, size: 14),
                label: Text(
                  isCompact ? 'QR' : 'QR Share',
                  style: GoogleFonts.alumniSans(fontSize: 13, fontWeight: FontWeight.w400, letterSpacing: 0.4),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentWhite,
                  side: const BorderSide(color: AppTheme.cardBorderHover),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoPeersPlaceholder(bool isHotspot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.radar_outlined,
            size: 32,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 10),
          Text(
            isHotspot
                ? 'Connected to iPhone Personal Hotspot'
                : 'Searching for nearby devices',
            style: GoogleFonts.alumniSans(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              isHotspot
                  ? 'Devices can connect directly via browser or peer app. Click "QR Share" in top bar to display the connection code.'
                  : 'Devices on your network will appear here automatically. You can also connect directly by entering peer IP.',
              textAlign: TextAlign.center,
              style: GoogleFonts.alumniSans(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _showQrModal,
                icon: const Icon(Icons.qr_code_2_rounded, size: 14),
                label: Text(
                  'Show QR Code',
                  style: GoogleFonts.alumniSans(fontSize: 13, fontWeight: FontWeight.w400),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentWhite,
                  side: const BorderSide(color: AppTheme.cardBorderHover),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _showDirectConnectDialog,
                icon: const Icon(Icons.cable_rounded, size: 14),
                label: Text(
                  'Enter Peer IP',
                  style: GoogleFonts.alumniSans(fontSize: 13, fontWeight: FontWeight.w400),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.cardBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
