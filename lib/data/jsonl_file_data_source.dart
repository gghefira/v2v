import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/models/v2v_frame.dart';
import 'data_source.dart';

// ============================================================
// 🔥 JSONL FILE DATA SOURCE
//    Playback V2VFrame dari file recording hasil sensor test.
//
//    Format file: JSONL (JSON Lines) — satu V2VFrame per baris.
//    Schema persis sama dengan wire format yang Pi kirim live.
//
//    Cara pakai:
//      final source = JsonlFileDataSource('assets/recordings/test_1.jsonl');
//      source.stream().listen((frame) { ... });
//
//    Playback otomatis pakai timestamp di tiap frame, jadi
//    realistis sesuai recording asli.
// ============================================================
class JsonlFileDataSource implements DataSource {
  /// Path file di assets/ (relatif ke project root).
  /// Pastikan path-nya juga di-register di pubspec.yaml > flutter > assets.
  final String assetPath;

  /// 1.0 = realtime sesuai timestamp recording.
  /// 2.0 = playback 2x lebih cepat (untuk demo cepat).
  /// 0.5 = setengah kecepatan (untuk debug).
  final double playbackSpeed;

  /// Kalau true, akan loop ulang saat sampai akhir file.
  final bool loop;

  JsonlFileDataSource(
    this.assetPath, {
    this.playbackSpeed = 1.0,
    this.loop = true,
  });

  bool _disposed = false;

  @override
  Stream<V2VFrame> stream() async* {
    // Load file dari assets
    final raw = await rootBundle.loadString(assetPath);
    final lines = const LineSplitter()
        .convert(raw)
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      yield V2VFrame(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        ego: EgoState.empty,
        neighbors: const [],
      );
      return;
    }

    // Parse semua frame dulu (file recording biasanya kecil, <50MB)
    final frames = <V2VFrame>[];
    for (final line in lines) {
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        frames.add(_parseFrame(json));
      } catch (e) {
        // Skip line yang rusak, jangan crash
        continue;
      }
    }

    if (frames.isEmpty) {
      yield V2VFrame(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        ego: EgoState.empty,
        neighbors: const [],
      );
      return;
    }

    while (!_disposed) {
      final clock = Stopwatch()..start();
      final startTs = frames.first.timestamp;

      for (int i = 0; i < frames.length && !_disposed; i++) {
        final frame = frames[i];

        // Hitung kapan frame ini harus tampil
        final targetElapsedMs =
            (frame.timestamp - startTs) / playbackSpeed;

        // Tunggu sampai waktunya
        final waitMs = targetElapsedMs - clock.elapsedMilliseconds;
        if (waitMs > 0) {
          await Future.delayed(Duration(milliseconds: waitMs.round()));
        }

        if (_disposed) return;

        yield frame;
      }

      if (!loop) break;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
  }

  // ============================================================
  // Parser (schema match dengan SerialDataSource)
  // ============================================================
  V2VFrame _parseFrame(Map<String, dynamic> json) {
    final ego = json['ego'] as Map<String, dynamic>;
    final neighbors = (json['neighbors'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    return V2VFrame(
      timestamp: (json['ts'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      ego: EgoState(
        lat: (ego['lat'] as num).toDouble(),
        lon: (ego['lon'] as num).toDouble(),
        speedKmh: (ego['speed_kmh'] as num).toDouble(),
        headingDeg: (ego['heading_deg'] as num?)?.toDouble() ?? 0,
        engineRpm: (ego['engine_rpm'] as num?)?.toDouble() ?? 0,
        engineTempC: (ego['engine_temp_c'] as num?)?.toDouble() ?? 0,
        fuelLevelPct: (ego['fuel_level_pct'] as num?)?.toDouble() ?? 0,
      ),
      neighbors: neighbors.map((n) {
        return NeighborState(
          id: n['id'] as String,
          lat: (n['lat'] as num).toDouble(),
          lon: (n['lon'] as num).toDouble(),
          speedKmh: (n['speed_kmh'] as num).toDouble(),
          headingDeg: (n['heading_deg'] as num?)?.toDouble() ?? 0,
          emergencyStatus: _parseStatus(n['emergency_status'] as String?),
        );
      }).toList(),
    );
  }

  static EmergencyStatus _parseStatus(String? s) {
    switch (s?.toUpperCase()) {
      case 'EMERGENCY':
        return EmergencyStatus.emergency;
      case 'WARNING':
        return EmergencyStatus.warning;
      default:
        return EmergencyStatus.normal;
    }
  }
}
