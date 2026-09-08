import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';

class QrHotspotModal extends StatelessWidget {
  final String ip;
  final int port;
  final bool isHotspot;
  final String deviceName;

  const QrHotspotModal({
    super.key,
    required this.ip,
    required this.port,
    required this.isHotspot,
    required this.deviceName,
  });

  String get shareUrl => 'http://$ip:$port';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassCardDecoration(radius: 12),
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
                        isHotspot ? Icons.wifi_tethering_rounded : Icons.qr_code_2_rounded,
                        color: AppTheme.textPrimary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan to Connect',
                          style: GoogleFonts.alumniSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          isHotspot ? 'iPhone Personal Hotspot' : 'Local Wi-Fi Network',
                          style: GoogleFonts.alumniSans(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w300,
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
            const SizedBox(height: 16),

            // QR Code in White Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: shareUrl,
                version: QrVersions.auto,
                size: 170.0,
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
            const SizedBox(height: 14),

            // URL Pill with Copy Action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      style: GoogleFonts.alumniSans(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w300,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('URL copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Copy URL',
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick instructions
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.cardBorder, width: 0.8),
              ),
              child: Column(
                children: [
                  _buildStep(1, 'Connect phone to same Wi-Fi or iPhone Hotspot'),
                  const SizedBox(height: 4),
                  _buildStep(2, 'Point phone camera at the QR code above'),
                  const SizedBox(height: 4),
                  _buildStep(3, 'Open in Safari or Chrome to download or upload'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$number.',
          style: GoogleFonts.alumniSans(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.alumniSans(
              fontSize: 13,
              fontWeight: FontWeight.w300,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
