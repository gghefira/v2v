import 'dart:async';
import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../domain/models/v2v_frame.dart';
import '../domain/models/vehicle_state.dart';
import '../domain/services/csv_loader.dart';
import 'data_source.dart';

// ============================================================
// 🔥 MOCK DATA SOURCE
//    Generate V2VFrame untuk testing UI tanpa hardware Pi.
//
//    Ego  : pakai CSV genba (speed, lat, lon, dll).
//    Engine RPM/Temp: derived dari speed (placeholder).
//    Neighbors: scripted scenario — 1 mobil approach dari
//    LEFT, lalu RIGHT, dengan emergency_status cycling.
//
//    Cara pakai:
//      final source = MockDataSource();
//      source.stream().listen((frame) { ... });
//      // when done:
//      await source.dispose();
// ============================================================
class MockDataSource implements DataSource {
  // ---- Konfigurasi playback ----
  /// CSV genba di-sample @100Hz (1 row tiap 10ms).
  static const int _csvIntervalMs = 10;

  /// Render rate Flutter (~60fps).
  static const int _renderIntervalMs = 16;

  /// 1.0 = realtime. Naikkan untuk demo cepat.
  static const double _playbackSpeed = 1.0;

  // ---- Konfigurasi scenario neighbor ----
  /// Periode cycle scenario (detik). Akan loop terus.
  static const double _scenarioPeriodSec = 25.0;

  // ---- Internal state ----
  List<VehicleState> _csv = [];
  bool _disposed = false;

  @override
  Stream<V2VFrame> stream() async* {
    _csv = await loadCSV();

    if (_csv.length < 2) {
      // CSV kosong/invalid — yield 1 frame default lalu stop
      yield V2VFrame(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        ego: EgoState.empty,
        neighbors: const [],
      );
      return;
    }

    final clock = Stopwatch()..start();

    while (!_disposed) {
      final elapsedMs = clock.elapsedMilliseconds * _playbackSpeed;
      final ego = _computeEgoAt(elapsedMs);
      final neighbors = _generateNeighbors(elapsedMs / 1000.0, ego);

      yield V2VFrame(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        ego: ego,
        neighbors: neighbors,
      );

      await Future.delayed(const Duration(milliseconds: _renderIntervalMs));
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }

  // ============================================================
  // EGO STATE dari CSV (dengan interpolasi smooth)
  // ============================================================
  EgoState _computeEgoAt(double elapsedMs) {
    final indexFloat = elapsedMs / _csvIntervalMs;
    int index = indexFloat.floor();

    // Loop kalau sudah sampai akhir CSV (supaya demo tidak stop)
    if (index >= _csv.length - 1) {
      index = (_csv.length - 2);
    }
    final t = (indexFloat - index).clamp(0.0, 1.0);

    final cur = _csv[index];
    final next = _csv[index + 1];

    final speed = _lerp(cur.speed, next.speed, t);
    final x = _lerp(cur.x, next.x, t);
    final y = _lerp(cur.y, next.y, t);

    final lat = _lerp(cur.lat, next.lat, t);
    final lon = _lerp(cur.lng, next.lng, t);

    final heading = _bearing(
      LatLng(cur.lat, cur.lng),
      LatLng(next.lat, next.lng),
    );

    return EgoState(
      lat: lat,
      lon: lon,
      x: x,
      y: y,
      speedKmh: speed,
      headingDeg: heading,
      // Placeholder: RPM ~ speed × 45 (nanti diganti OBD PID 0x0C)
      engineRpm: (speed * 45).clamp(800, 8000),
      // Placeholder: temp naik linear dari 85→100°C seiring load
      engineTempC: 85 + (speed / 160) * 15,
    );
  }

  // ============================================================
  // NEIGHBORS — scripted scenario
  // ============================================================
  // Phase    Time(s)   Posisi neighbor     Emergency status
  // ────────────────────────────────────────────────────────
  //   1      0  - 8    LEFT, 50m → 5m      NORMAL → EMERGENCY
  //   2      8  - 12   far (off-screen)    NORMAL
  //   3      12 - 20   RIGHT, 50m → 5m     NORMAL → EMERGENCY
  //   4      20 - 25   far (off-screen)    NORMAL
  //   (loop)
  // ============================================================
  List<NeighborState> _generateNeighbors(double tSec, EgoState ego) {
    final t = tSec % _scenarioPeriodSec;

    NeighborState b01;

    if (t < 8) {
      // LEFT approach: jarak 50m → 5m
      final progress = t / 8.0;
      final distance = 50 - (progress * 45);
      b01 = _placeNeighbor(
        id: 'B01',
        ego: ego,
        dxRel: -distance, // negatif = kiri
        dyRel: 0,
        status: distance < 10
            ? EmergencyStatus.emergency
            : EmergencyStatus.normal,
      );
    } else if (t < 12) {
      // Far away (safe gap)
      b01 = _placeNeighbor(
        id: 'B01',
        ego: ego,
        dxRel: -80,
        dyRel: 30,
        status: EmergencyStatus.normal,
      );
    } else if (t < 20) {
      // RIGHT approach
      final progress = (t - 12) / 8.0;
      final distance = 50 - (progress * 45);
      b01 = _placeNeighbor(
        id: 'B01',
        ego: ego,
        dxRel: distance, // positif = kanan
        dyRel: 0,
        status: distance < 10
            ? EmergencyStatus.emergency
            : EmergencyStatus.normal,
      );
    } else {
      // Far away (safe gap)
      b01 = _placeNeighbor(
        id: 'B01',
        ego: ego,
        dxRel: 80,
        dyRel: 30,
        status: EmergencyStatus.normal,
      );
    }

    return [b01];
  }

  /// Helper untuk place neighbor di posisi relatif terhadap ego.
  /// dxRel: meter ke kanan (positif) / kiri (negatif)
  /// dyRel: meter ke depan (positif) / belakang (negatif)
  NeighborState _placeNeighbor({
    required String id,
    required EgoState ego,
    required double dxRel,
    required double dyRel,
    required EmergencyStatus status,
  }) {
    return NeighborState(
      id: id,
      // Lat/lon disimplifikasi — pakai posisi ego (sebenarnya akan dihitung
      // dari x,y di production)
      lat: ego.lat,
      lon: ego.lon,
      x: ego.x + dxRel,
      y: ego.y + dyRel,
      speedKmh: 40,
      headingDeg: 0,
      emergencyStatus: status,
    );
  }

  // ============================================================
  // UTILS
  // ============================================================
  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _bearing(LatLng start, LatLng end) {
    final dLon = (end.longitude - start.longitude) * pi / 180;
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }
}
