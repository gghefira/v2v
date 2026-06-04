import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../domain/models/v2v_frame.dart';

// ============================================================
// 🔥 WARNING MODEL (UI-only; nanti di-feed dari DecisionService)
// ============================================================
enum WarningLevel { safe, warning, danger }
enum WarningDirection { left, right, front, rear }

class WarningInfo {
  final WarningLevel level;
  final WarningDirection direction;
  final double distance;

  const WarningInfo({
    required this.level,
    required this.direction,
    required this.distance,
  });
}

// ============================================================
// 🔥 CONNECTION STATUS (untuk badge di pojok atas)
// ============================================================
enum ConnectionLevel { mock, ok, stale, error }

class ConnectionStatus {
  final String label;
  final ConnectionLevel level;

  const ConnectionStatus({required this.label, required this.level});

  const ConnectionStatus.mock()
      : label = 'MOCK DATA',
        level = ConnectionLevel.mock;

  const ConnectionStatus.live()
      : label = 'LIVE — PI',
        level = ConnectionLevel.ok;

  const ConnectionStatus.stale()
      : label = 'NO DATA',
        level = ConnectionLevel.stale;

  const ConnectionStatus.disconnected()
      : label = 'DISCONNECTED',
        level = ConnectionLevel.error;
}

// ============================================================
// 🔥 MAIN VIEW
// ============================================================
class SensorView extends StatelessWidget {
  final EgoState ego;
  final WarningInfo? warning;
  final String timeText;
  final ConnectionStatus connectionStatus;

  const SensorView({
    super.key,
    required this.ego,
    this.warning,
    this.timeText = "9:41 PM",
    this.connectionStatus = const ConnectionStatus.mock(),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0E2A),
            Color(0xFF141A47),
            Color(0xFF2A1656),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            // Skala gauge mengikuti tinggi layar agar pas di 7-inch
            final gaugeSize = (c.maxHeight * 0.92).clamp(260.0, 420.0);

            return Stack(
              children: [
                // ---- LANE + GLOW di belakang semua
                Positioned.fill(
                  child: CustomPaint(painter: _LanePainter()),
                ),

                // ---- ROW: RPM | CENTER | SPEED
                // 👉 Offset.dx = geser kiri/kanan (negatif=kiri, positif=kanan)
                // 👉 Offset.dy = geser atas/bawah (negatif=naik,  positif=turun)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(30, -10), // ⬅️ RPM: geser naik 30px
                          child: _RpmGauge(
                            rpm: ego.engineRpm,
                            speedForGear: ego.speedKmh,
                            size: gaugeSize,
                            timeText: timeText,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: _CenterStage(warning: warning),
                    ),
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(-30, -10), // ⬅️ SPEED: geser naik 30px
                          child: _SpeedGauge(
                            speed: ego.speedKmh,
                            size: gaugeSize,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ---- Connection badge (top-right)
                Positioned(
                  top: 16,
                  right: 20,
                  child: _ConnectionBadge(status: connectionStatus),
                ),

                // ---- Engine temp indicator (bottom-right)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: _EngineTempIndicator(tempC: ego.engineTempC),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// 🔥 CENTER STAGE (mobil + warning card)
class _CenterStage extends StatelessWidget {
  final WarningInfo? warning;
  const _CenterStage({this.warning});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pink glow under car (mengikuti referensi)
        Positioned(
          bottom: 0,
          child: CustomPaint(
            size: const Size(360, 220),
            painter: _GlowPainter(),
          ),
        ),

        // Car (top-down view)
        Positioned(
          bottom: 50,
          child: Image.asset(
            'assets/car_behind.png',
            width: 150,
            fit: BoxFit.contain,
          ),
        ),

        // Warning card di atas (muncul saat ada ancaman)
        Positioned(
          top: 70,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.25),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: (warning == null || warning!.level == WarningLevel.safe)
                ? const SizedBox.shrink(key: ValueKey('safe'))
                : _WarningCard(
                    key: ValueKey(
                      '${warning!.level}-${warning!.direction}',
                    ),
                    info: warning!,
                  ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 🔥 WARNING CARD
// ============================================================
class _WarningCard extends StatelessWidget {
  final WarningInfo info;
  const _WarningCard({super.key, required this.info});

  Color get _accent => info.level == WarningLevel.danger
      ? const Color(0xFFFF3B30)
      : const Color(0xFFFFB020);

  IconData get _dirIcon {
    switch (info.direction) {
      case WarningDirection.left:
        return Icons.arrow_back_rounded;
      case WarningDirection.right:
        return Icons.arrow_forward_rounded;
      case WarningDirection.front:
        return Icons.arrow_upward_rounded;
      case WarningDirection.rear:
        return Icons.arrow_downward_rounded;
    }
  }

  String get _dirLabel {
    switch (info.direction) {
      case WarningDirection.left:
        return "Vehicle from LEFT";
      case WarningDirection.right:
        return "Vehicle from RIGHT";
      case WarningDirection.front:
        return "Vehicle AHEAD";
      case WarningDirection.rear:
        return "Vehicle BEHIND";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDanger = info.level == WarningLevel.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1330).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.55),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_dirIcon, color: _accent, size: 32),
          const SizedBox(width: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${info.distance.toStringAsFixed(0)} m",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _dirLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Pulsing dot — extra emphasis untuk danger
          if (isDanger) _PulsingDot(color: _accent),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(color: widget.color, blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 🔥 RPM GAUGE (KIRI)
// ============================================================
class _RpmGauge extends StatelessWidget {
  /// RPM langsung dari OBD (atau dari MockDataSource sebagai placeholder).
  final double rpm;

  /// Speed dipakai HANYA untuk menentukan gear (gear ratio belum tersedia
  /// dari OBD; nanti bisa di-derive dari rpm/speed jika perlu).
  final double speedForGear;

  final double size;
  final String timeText;

  const _RpmGauge({
    required this.rpm,
    required this.speedForGear,
    required this.size,
    required this.timeText,
  });

  double get _rpm => rpm.clamp(0, 8000).toDouble();

  int get _gear {
    if (speedForGear < 1) return 0;
    if (speedForGear < 20) return 1;
    if (speedForGear < 40) return 2;
    if (speedForGear < 60) return 3;
    if (speedForGear < 90) return 4;
    if (speedForGear < 120) return 5;
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 0,
                maximum: 8,
                startAngle: 135,
                endAngle: 45,
                interval: 1,
                radiusFactor: 0.95,
                showLastLabel: true,
                axisLineStyle: const AxisLineStyle(
                  thickness: 3,
                  color: Color(0x33FFFFFF),
                  thicknessUnit: GaugeSizeUnit.logicalPixel,
                ),
                majorTickStyle: const MajorTickStyle(
                  length: 10,
                  thickness: 2,
                  color: Colors.white70,
                ),
                minorTickStyle: const MinorTickStyle(
                  length: 5,
                  thickness: 1,
                  color: Colors.white24,
                ),
                minorTicksPerInterval: 4,
                axisLabelStyle: const GaugeTextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                labelOffset: 16,
                // Redline zone (bg) — tetap kelihatan walau pointer belum sampai
                ranges: <GaugeRange>[
                  GaugeRange(
                    startValue: 7,
                    endValue: 8,
                    color: const Color(0x66FF3B30),
                    startWidth: 3,
                    endWidth: 3,
                  ),
                ],
                pointers: <GaugePointer>[
                  RangePointer(
                    value: _rpm / 1000,
                    width: 6,
                    // 🔥 Warna SOLID yang berubah dinamis sesuai nilai RPM
                    color: _lerpDangerColor(_rpm / 8000),
                    enableAnimation: true,
                    animationType: AnimationType.ease,
                    cornerStyle: CornerStyle.bothCurve,
                  ),
                ],
                annotations: <GaugeAnnotation>[
                  GaugeAnnotation(
                    positionFactor: 0.05,
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "$_gear",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w300,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Gear",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GaugeAnnotation(
                    positionFactor: 0.65,
                    angle: 90,
                    widget: Text(
                      timeText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 🔥 SPEED GAUGE (KANAN)
// ============================================================
class _SpeedGauge extends StatelessWidget {
  final double speed;
  final double size;

  const _SpeedGauge({required this.speed, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: 160,
            startAngle: 135,
            endAngle: 45,
            interval: 20,
            radiusFactor: 0.95,
            showLastLabel: true,
            axisLineStyle: const AxisLineStyle(
              thickness: 3,
              color: Color(0x33FFFFFF),
              thicknessUnit: GaugeSizeUnit.logicalPixel,
            ),
            majorTickStyle: const MajorTickStyle(
              length: 10,
              thickness: 2,
              color: Colors.white70,
            ),
            minorTickStyle: const MinorTickStyle(
              length: 5,
              thickness: 1,
              color: Colors.white24,
            ),
            minorTicksPerInterval: 4,
            axisLabelStyle: const GaugeTextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            labelOffset: 16,
            // Zona merah di kecepatan tinggi (bg highlight)
            ranges: <GaugeRange>[
              GaugeRange(
                startValue: 140,
                endValue: 160,
                color: const Color(0x66FF3B30),
                startWidth: 3,
                endWidth: 3,
              ),
            ],
            pointers: <GaugePointer>[
              RangePointer(
                value: speed,
                width: 6,
                // 🔥 Warna SOLID yang berubah dinamis sesuai kecepatan
                color: _lerpDangerColor(speed / 160),
                enableAnimation: true,
                animationType: AnimationType.ease,
                cornerStyle: CornerStyle.bothCurve,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                positionFactor: 0.05,
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      speed.toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w300,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "km/h",
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 🔥 CONNECTION BADGE (pojok kanan atas)
//    Tampilkan source data: MOCK / LIVE / NO DATA / DISCONNECTED
// ============================================================
class _ConnectionBadge extends StatelessWidget {
  final ConnectionStatus status;
  const _ConnectionBadge({required this.status});

  Color get _color {
    switch (status.level) {
      case ConnectionLevel.ok:
        return const Color(0xFF4ADE80); // hijau
      case ConnectionLevel.mock:
        return const Color(0xFFFFB020); // oranye
      case ConnectionLevel.stale:
        return const Color(0xFFFFCC00); // kuning
      case ConnectionLevel.error:
        return const Color(0xFFFF3B30); // merah
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1330).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color,
              boxShadow: [
                BoxShadow(color: _color, blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 🔥 ENGINE TEMP INDICATOR (pojok kanan bawah)
//    Bar horizontal kecil: biru (cold) → hijau (normal) → merah (hot)
//    Range: 60°C - 120°C
// ============================================================
class _EngineTempIndicator extends StatelessWidget {
  final double tempC;
  const _EngineTempIndicator({required this.tempC});

  static const double _minTemp = 60;
  static const double _maxTemp = 120;

  double get _normalized =>
      ((tempC - _minTemp) / (_maxTemp - _minTemp)).clamp(0.0, 1.0);

  Color get _color {
    final n = _normalized;
    if (n < 0.3) {
      // Cold: biru → hijau
      return Color.lerp(
            const Color(0xFF4DA3FF),
            const Color(0xFF4ADE80),
            n / 0.3,
          ) ??
          const Color(0xFF4ADE80);
    } else if (n < 0.75) {
      // Normal: hijau
      return const Color(0xFF4ADE80);
    } else {
      // Hot: hijau → merah
      return Color.lerp(
            const Color(0xFF4ADE80),
            const Color(0xFFFF3B30),
            (n - 0.75) / 0.25,
          ) ??
          const Color(0xFFFF3B30);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1330).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat_rounded, color: _color, size: 16),
              const SizedBox(width: 6),
              const Text(
                'ENGINE TEMP',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${tempC.toStringAsFixed(0)}°C',
                style: TextStyle(
                  color: _color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Bar progress
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  width: double.infinity,
                  color: Colors.white12,
                ),
                FractionallySizedBox(
                  widthFactor: _normalized,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: _color,
                      boxShadow: [
                        BoxShadow(color: _color.withValues(alpha: 0.5), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Tick labels C / H
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'C',
                style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1),
              ),
              Text(
                'H',
                style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 🔥 LANE PAINTER (garis perspektif jalan)
// 👉 Atur 4 angka di bawah untuk geser/perlebar lane
// ============================================================
class _LanePainter extends CustomPainter {
  /// Setengah lebar lane di bagian BAWAH (px). Naikkan = lane lebih lebar.
  static const double _bottomHalfWidth = 150;

  /// Setengah lebar lane di bagian ATAS (px). Naikkan = lebih sedikit perspektif.
  static const double _topHalfWidth = 60;

  /// Posisi Y bagian atas (0.0 = paling atas, 1.0 = paling bawah).
  /// Turunkan ke 0.35 supaya horizon lebih tinggi & lane lebih panjang.
  static const double _topYFactor = 0.60;

  /// Geser horizontal seluruh lane (px). Negatif = ke kiri, positif = ke kanan.
  /// Set 0 untuk benar-benar di tengah layar.
  static const double _xOffset = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + _xOffset;
    final bottom = size.height;
    final topY = size.height * _topYFactor;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Lane kiri: bawah-kiri → atas-kiri (sempit di atas = perspektif)
    final leftPath = Path()
      ..moveTo(cx - _bottomHalfWidth, bottom)
      ..lineTo(cx - _topHalfWidth, topY);

    // Lane kanan: mirror dari kiri = simetris penuh
    final rightPath = Path()
      ..moveTo(cx + _bottomHalfWidth, bottom)
      ..lineTo(cx + _topHalfWidth, topY);

    canvas.drawPath(leftPath, glow);
    canvas.drawPath(rightPath, glow);
    canvas.drawPath(leftPath, paint);
    canvas.drawPath(rightPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// 🔥 HELPER: warna pointer dinamis berdasarkan nilai (0.0 - 1.0)
//    Transisi: putih → kuning → oranye → merah
//    Dipakai untuk RPM & Speed pointer.
// ============================================================
Color _lerpDangerColor(double t) {
  final v = t.clamp(0.0, 1.0);

  const white = Color(0xFFFFFFFF);
  const yellow = Color(0xFFFFC857);
  const orange = Color(0xFFFF8A3D);
  const red = Color(0xFFFF3B30);

  // 0.0 - 0.55  : putih → kuning  (zona aman)
  // 0.55 - 0.8  : kuning → oranye (hati-hati)
  // 0.8  - 1.0  : oranye → merah  (bahaya)
  if (v < 0.55) {
    return Color.lerp(white, yellow, v / 0.55) ?? white;
  } else if (v < 0.8) {
    return Color.lerp(yellow, orange, (v - 0.55) / 0.25) ?? yellow;
  } else {
    return Color.lerp(orange, red, (v - 0.8) / 0.2) ?? red;
  }
}

// ============================================================
// 🔥 GLOW PAINTER (efek pink/magenta di bawah mobil)
// ============================================================
class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.65);

    final rect = Rect.fromCircle(center: center, radius: size.width * 0.6);

    final gradient = RadialGradient(
      colors: [
        const Color(0xFFFF2D7E).withValues(alpha: 0.45),
        const Color(0xFFFF2D7E).withValues(alpha: 0.15),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}