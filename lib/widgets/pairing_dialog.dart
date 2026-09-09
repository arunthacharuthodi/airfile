import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/peer_device.dart';
import '../services/pairing_service.dart';
import '../theme/app_theme.dart';

/// Modal displayed on the INITIATOR device while waiting for the target device to accept the code.
class PairingInitiatorModal extends StatefulWidget {
  final PeerDevice targetPeer;
  final PairingService pairingService;

  const PairingInitiatorModal({
    super.key,
    required this.targetPeer,
    required this.pairingService,
  });

  @override
  State<PairingInitiatorModal> createState() => _PairingInitiatorModalState();
}

class _PairingInitiatorModalState extends State<PairingInitiatorModal> {
  String _code = '......';
  bool _isLoading = true;
  String? _errorMessage;
  int _secondsLeft = 45;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startPairing();
  }

  void _startPairing() async {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        if (mounted) setState(() => _secondsLeft--);
      } else {
        timer.cancel();
      }
    });

    final result = await widget.pairingService.initiatePairing(
      widget.targetPeer,
      onCodeGenerated: (code) {
        if (mounted) setState(() => _code = code);
      },
    );
    _countdownTimer?.cancel();

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully paired with ${widget.targetPeer.name}',
            style: GoogleFonts.dmSans(fontSize: 13),
          ),
          backgroundColor: AppTheme.cardBg,
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.error ?? 'Pairing failed';
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatCode(String code) {
    if (code.length == 6) {
      return '${code.substring(0, 3)}  ${code.substring(3)}';
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorderHover, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_open_rounded, color: AppTheme.accentWhite, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'DEVICE PAIRING',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$_secondsLeft s',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Target Device Details
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.targetPeer.deviceType.icon, size: 18, color: AppTheme.accentWhite),
                const SizedBox(width: 8),
                Text(
                  widget.targetPeer.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _isLoading
                  ? 'Verify this code matches on ${widget.targetPeer.name}'
                  : 'Pairing could not be completed',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),

            // Code Display Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder, width: 1),
              ),
              child: Center(
                child: Text(
                  _formatCode(_code),
                  style: GoogleFonts.dmSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                    color: AppTheme.accentWhite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 14),
            ],

            if (_isLoading)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentWhite),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Waiting for approval on ${widget.targetPeer.name}...',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.cardBorderHover, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// High-priority prompt displayed on the RECEIVER device when another device requests to pair.
class IncomingPairingDialog extends StatelessWidget {
  final IncomingPairRequest request;
  final VoidCallback onAccepted;
  final VoidCallback onDeclined;

  const IncomingPairingDialog({
    super.key,
    required this.request,
    required this.onAccepted,
    required this.onDeclined,
  });

  String _formatCode(String code) {
    if (code.length == 6) {
      return '${code.substring(0, 3)}  ${code.substring(3)}';
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentWhite, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.9),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.accentWhite, size: 16),
                const SizedBox(width: 8),
                Text(
                  'PAIRING REQUEST',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: AppTheme.accentWhite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Device Name
            Text(
              request.initiatorName,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'wants to connect and exchange files with this device',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 18),

            // Verification Code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorderHover, width: 1),
              ),
              child: Column(
                children: [
                  Text(
                    _formatCode(request.code),
                    style: GoogleFonts.dmSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                      color: AppTheme.accentWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'VERIFICATION CODE',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDeclined,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.cardBorderHover, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      'Decline',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccepted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentWhite,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      'Accept & Trust',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
