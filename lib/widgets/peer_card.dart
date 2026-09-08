import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/peer_device.dart';
import '../theme/app_theme.dart';

class PeerCard extends StatelessWidget {
  final PeerDevice peer;
  final int stagedCount;
  final bool isPaired;
  final VoidCallback onSendPressed;
  final VoidCallback? onPairPressed;
  final VoidCallback? onUnpairPressed;

  const PeerCard({
    super.key,
    required this.peer,
    required this.stagedCount,
    required this.onSendPressed,
    this.isPaired = false,
    this.onPairPressed,
    this.onUnpairPressed,
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
                color: isPaired ? AppTheme.accentWhite.withValues(alpha: 0.3) : AppTheme.cardBorderHover,
                width: 1,
              ),
            ),
            child: Icon(
              peer.deviceType.icon,
              color: isPaired ? AppTheme.accentWhite : AppTheme.textMuted,
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
                        style: GoogleFonts.alumniSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPairStatusBadge(isPaired),
                    const SizedBox(width: 6),
                    _buildMediumBadge(peer.medium),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      peer.ip,
                      style: GoogleFonts.alumniSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (peer.port != 0 && peer.hasDirectIp) ...[
                      Text(
                        ':${peer.port}',
                        style: GoogleFonts.alumniSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    const Text('•', style: TextStyle(color: AppTheme.textMuted, fontSize: 8)),
                    const SizedBox(width: 6),
                    Text(
                      peer.deviceType.name.toUpperCase(),
                      style: GoogleFonts.alumniSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Button
          if (!isPaired) ...[
            OutlinedButton.icon(
              onPressed: onPairPressed,
              icon: const Icon(Icons.link_rounded, size: 14),
              label: Text(
                'Pair & Connect',
                style: GoogleFonts.alumniSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.4,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentWhite,
                side: const BorderSide(color: AppTheme.cardBorderHover, width: 1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    style: GoogleFonts.alumniSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.4,
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
                if (onUnpairPressed != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.link_off_rounded, size: 14, color: AppTheme.textMuted),
                    tooltip: 'Unpair Device',
                    onPressed: onUnpairPressed,
                    splashRadius: 14,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPairStatusBadge(bool paired) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: paired ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: paired ? AppTheme.accentWhite.withValues(alpha: 0.6) : AppTheme.cardBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paired ? Icons.verified_user_outlined : Icons.lock_outline_rounded,
            size: 9,
            color: paired ? AppTheme.accentWhite : AppTheme.textMuted,
          ),
          const SizedBox(width: 3),
          Text(
            paired ? 'PAIRED' : 'UNPAIRED',
            style: GoogleFonts.alumniSans(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: paired ? AppTheme.accentWhite : AppTheme.textMuted,
              letterSpacing: 0.6,
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
            style: GoogleFonts.alumniSans(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
