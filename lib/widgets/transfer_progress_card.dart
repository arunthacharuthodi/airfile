import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/file_payload.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class TransferProgressCard extends StatelessWidget {
  final FilePayload payload;
  final StorageService storageService;
  final VoidCallback? onCancel;
  final VoidCallback? onDismiss;

  const TransferProgressCard({
    super.key,
    required this.payload,
    required this.storageService,
    this.onCancel,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isOutgoing = payload.isOutgoing;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: payload.status == TransferStatus.transferring
              ? AppTheme.accentWhite.withValues(alpha: 0.3)
              : AppTheme.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Direction Icon
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                ),
                child: Icon(
                  isOutgoing ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: AppTheme.accentWhite,
                  size: 13,
                ),
              ),
              const SizedBox(width: 10),

              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payload.name,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${isOutgoing ? 'To' : 'From'} ${payload.peerName} • ${payload.formattedSize}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              _buildStatusBadge(),

              // Show in Finder or Cancel or Dismiss
              if (payload.status == TransferStatus.completed && payload.savedPath != null) ...[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: () => storageService.revealInFinder(payload.savedPath!),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                  ),
                  child: Text('Finder', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.accentWhite)),
                ),
              ] else if (payload.status.isActive && onCancel != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 14, color: AppTheme.textMuted),
                  tooltip: 'Cancel',
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
              if (payload.status.isDone && onDismiss != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 13, color: AppTheme.textMuted),
                  tooltip: 'Dismiss',
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),

          // Progress Bar & Speed Details
          if (payload.status.isActive) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: payload.progress > 0 ? payload.progress : null,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentWhite),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  payload.status == TransferStatus.connecting
                      ? 'Connecting...'
                      : '${(payload.progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w400, color: AppTheme.textSecondary),
                ),
                Text(
                  payload.formattedSpeed,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],

          if (payload.status == TransferStatus.failed && payload.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              payload.errorMessage!,
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w400, color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    String label;

    switch (payload.status) {
      case TransferStatus.queued:
        label = 'Queued';
        break;
      case TransferStatus.connecting:
        label = 'Connecting';
        break;
      case TransferStatus.transferring:
        label = 'Transferring';
        break;
      case TransferStatus.completed:
        label = 'Done';
        break;
      case TransferStatus.failed:
        label = 'Notice';
        break;
      case TransferStatus.cancelled:
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.cardBorder, width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
