import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/peer_device.dart';
import '../theme/app_theme.dart';

class PeerCard extends StatelessWidget {
  final PeerDevice peer;
  final int stagedCount;
  final VoidCallback onSendPressed;

  const PeerCard({
    super.key,
    required this.peer,
    required this.stagedCount,
    required this.onSendPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Device Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              shape: BoxShape.circle,
              border: Border.all(
                color: peer.hasDirectIp ? AppTheme.accentWhite.withValues(alpha: 0.3) : AppTheme.cardBorderHover,
                width: 1,
              ),
            ),
            child: Icon(
              peer.deviceType.icon,
              color: peer.hasDirectIp ? AppTheme.accentWhite : AppTheme.textMuted,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),

          // Device Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        peer.name,
                        style: GoogleFonts.ptSans(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildMediumBadge(peer.medium),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      peer.ip,
                      style: GoogleFonts.ptSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (peer.port != 0 && peer.hasDirectIp) ...[
                      Text(
                        ':${peer.port}',
                        style: GoogleFonts.ptSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    const Text('•', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
                    const SizedBox(width: 6),
                    Text(
                      peer.deviceType.name.toUpperCase(),
                      style: GoogleFonts.ptSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Button
          OutlinedButton.icon(
            onPressed: stagedCount > 0 ? onSendPressed : null,
            icon: Icon(
              peer.hasDirectIp ? Icons.arrow_outward_rounded : Icons.qr_code_2_rounded,
              size: 14,
            ),
            label: Text(
              peer.hasDirectIp
                  ? (stagedCount > 0 ? 'Send ($stagedCount)' : 'Select Files')
                  : (stagedCount > 0 ? 'Share ($stagedCount)' : 'Share via QR'),
              style: GoogleFonts.ptSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              disabledForegroundColor: AppTheme.textMuted,
              side: BorderSide(
                color: stagedCount > 0 ? AppTheme.accentWhite : AppTheme.cardBorder,
                width: 1,
              ),
              backgroundColor: stagedCount > 0 ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediumBadge(ConnectionMedium medium) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.cardBorder, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(medium.icon, size: 10, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            medium.label,
            style: GoogleFonts.ptSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
