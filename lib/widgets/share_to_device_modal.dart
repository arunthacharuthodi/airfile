import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/peer_device.dart';
import '../services/transfer_server.dart';
import '../theme/app_theme.dart';

class ShareToDeviceModal extends StatefulWidget {
  final PeerDevice peer;
  final List<StagedFile> stagedFiles;
  final String localIp;
  final int localPort;
  final bool isHotspot;
  final Future<void> Function(String directIp)? onSendToDirectIp;

  const ShareToDeviceModal({
    super.key,
    required this.peer,
    required this.stagedFiles,
    required this.localIp,
    required this.localPort,
    required this.isHotspot,
    this.onSendToDirectIp,
  });

  @override
  State<ShareToDeviceModal> createState() => _ShareToDeviceModalState();
}

class _ShareToDeviceModalState extends State<ShareToDeviceModal> {
  final TextEditingController _ipController = TextEditingController();
  bool _isSending = false;

  String get shareUrl => 'http://${widget.localIp}:${widget.localPort}';

  @override
  void initState() {
    super.initState();
    if (widget.isHotspot) {
      if (widget.localIp.startsWith('192.0.0.')) {
        _ipController.text = '192.0.0.1';
      } else if (widget.localIp.startsWith('172.20.10.')) {
        _ipController.text = '172.20.10.1';
      }
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassCardDecoration(radius: 12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                        ),
                        child: Icon(
                          widget.peer.deviceType.icon,
                          color: AppTheme.textPrimary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share to ${widget.peer.name}',
                            style: GoogleFonts.ptSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Text(
                            'Bluetooth LE Peer',
                            style: GoogleFonts.ptSans(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Staged Files Summary
              if (widget.stagedFiles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined, color: AppTheme.textSecondary, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.stagedFiles.length} file(s) staged: ${widget.stagedFiles.map((f) => "${f.name} (${_formatSize(f.size)})").join(", ")}',
                          style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.w400, color: AppTheme.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // Safari Web Share via QR
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.accentWhite, size: 15),
                        const SizedBox(width: 6),
                        Text(
                          'Scan with Camera to Download in Browser',
                          style: GoogleFonts.ptSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: QrImageView(
                        data: shareUrl,
                        version: QrVersions.auto,
                        size: 150.0,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Link pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              shareUrl,
                              style: GoogleFonts.ptSans(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 13, color: AppTheme.textSecondary),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: shareUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('URL copied to clipboard')),
                              );
                            },
                            splashRadius: 12,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Open camera on ${widget.peer.name} and scan code to download',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.ptSans(fontSize: 11, fontWeight: FontWeight.w400, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Peer IP direct send
              if (widget.onSendToDirectIp != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct App Send (requires AirFile app open on peer)',
                        style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ipController,
                              style: GoogleFonts.ptSans(fontSize: 13, fontWeight: FontWeight.w400),
                              decoration: InputDecoration(
                                hintText: 'Device IP',
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
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _isSending
                                ? null
                                : () async {
                                    final ip = _ipController.text.trim();
                                    if (ip.isNotEmpty) {
                                      setState(() => _isSending = true);
                                      await widget.onSendToDirectIp!(ip);
                                      if (context.mounted) {
                                        setState(() => _isSending = false);
                                        Navigator.of(context).pop();
                                      }
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentWhite,
                              side: const BorderSide(color: AppTheme.cardBorderHover),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(
                              _isSending ? 'Sending...' : 'Send',
                              style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
