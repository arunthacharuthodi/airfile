import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class RadarVisualizer extends StatefulWidget {
  final bool isScanning;
  final int peerCount;
  final VoidCallback onScanPressed;

  const RadarVisualizer({
    super.key,
    required this.isScanning,
    required this.peerCount,
    required this.onScanPressed,
  });

  @override
  State<RadarVisualizer> createState() => _RadarVisualizerState();
}

class _RadarVisualizerState extends State<RadarVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: AppTheme.glassCardDecoration(),
      child: Row(
        children: [
          // Radar canvas
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(100, 100),
                      painter: _RadarPainter(
                        progress: _controller.value,
                      ),
                    );
                  },
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.cardBorderHover, width: 1),
                  ),
                  child: const Icon(
                    Icons.laptop_mac_outlined,
                    color: AppTheme.accentWhite,
                    size: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Info & CTA
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentWhite,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isScanning ? 'SCANNING NETWORK' : 'DISCOVERY ACTIVE',
                      style: GoogleFonts.ptSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  widget.peerCount == 0
                      ? 'Listening for nearby devices'
                      : '${widget.peerCount} device${widget.peerCount > 1 ? 's' : ''} detected nearby',
                  style: GoogleFonts.ptSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Wi-Fi Multicast • iPhone Hotspot Sweep • Bluetooth LE',
                  style: GoogleFonts.ptSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.isScanning ? null : widget.onScanPressed,
                  icon: widget.isScanning
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppTheme.accentWhite,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 13),
                  label: Text(
                    widget.isScanning ? 'Scanning...' : 'Scan Now',
                    style: GoogleFonts.ptSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentWhite,
                    side: const BorderSide(color: AppTheme.cardBorderHover, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;

  _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = const Color(0x1FFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Static concentric circles
    canvas.drawCircle(center, maxRadius * 0.4, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.7, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.95, ringPaint);

    // Expanding animated ripple in monochrome - continuous ambient sweep
    final rippleRadius = maxRadius * progress;
    final ripplePaint = Paint()
      ..color = Colors.white.withValues(alpha: (1.0 - progress) * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, rippleRadius, ripplePaint);

    // Rotating radar beam - continuous ambient sweep
    final angle = progress * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(angle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius * 0.95, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => true;
}
