import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/clipboard_sync_service.dart';
import '../theme/app_theme.dart';

class ClipboardSyncCard extends StatefulWidget {
  final ClipboardSyncService clipboardSyncService;

  const ClipboardSyncCard({
    super.key,
    required this.clipboardSyncService,
  });

  @override
  State<ClipboardSyncCard> createState() => _ClipboardSyncCardState();
}

class _ClipboardSyncCardState extends State<ClipboardSyncCard> {
  bool _justCopied = false;

  void _handleCopy() async {
    await widget.clipboardSyncService.copyCurrentToClipboard();
    setState(() => _justCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.clipboardSyncService,
      builder: (context, _) {
        final service = widget.clipboardSyncService;
        final hasContent = service.hasContent;
        final text = service.currentText ?? '';
        final sender = service.lastSenderDeviceName ?? 'Local';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: AppTheme.glassCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: service.autoSyncEnabled
                              ? AppTheme.accentWhite
                              : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'UNIVERSAL CLIPBOARD',
                        style: GoogleFonts.ptSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (service.isBroadcasting) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.2,
                            color: AppTheme.accentWhite,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        service.autoSyncEnabled ? 'AUTO-SYNC ON' : 'AUTO-SYNC OFF',
                        style: GoogleFonts.ptSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: service.autoSyncEnabled ? AppTheme.accentWhite : AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 20,
                        width: 32,
                        child: Switch(
                          value: service.autoSyncEnabled,
                          onChanged: service.setAutoSync,
                          activeColor: AppTheme.accentWhite,
                          activeTrackColor: AppTheme.cardBorderHover,
                          inactiveThumbColor: AppTheme.textMuted,
                          inactiveTrackColor: AppTheme.cardBg,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Content Box
              if (hasContent) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ptSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Synced from $sender • ${text.length} chars',
                            style: GoogleFonts.ptSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          Row(
                            children: [
                              InkWell(
                                onTap: _handleCopy,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _justCopied ? Icons.check_rounded : Icons.copy_rounded,
                                        size: 12,
                                        color: AppTheme.accentWhite,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _justCopied ? 'Copied' : 'Copy',
                                        style: GoogleFonts.ptSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accentWhite,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: service.pushLocalClipboardNow,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.arrow_upward_rounded, size: 12, color: AppTheme.accentWhite),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Push Now',
                                        style: GoogleFonts.ptSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accentWhite,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.cardBorder, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Copy any text on Mac, iOS, Windows, or Android to auto-sync',
                          style: GoogleFonts.ptSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: service.pushLocalClipboardNow,
                        icon: const Icon(Icons.arrow_upward_rounded, size: 12),
                        label: Text(
                          'Push Clipboard',
                          style: GoogleFonts.ptSans(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentWhite,
                          side: const BorderSide(color: AppTheme.cardBorderHover, width: 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
