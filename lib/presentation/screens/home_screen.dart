import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/data_source.dart';
import '../../data/mock_data_source.dart';
// import '../../data/serial_data_source.dart'; // ← uncomment saat hardware ready
import '../../domain/models/v2v_frame.dart';
import '../widgets/sensor_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // 🔥 SUMBER DATA — swap di sini saat hardware Pi sudah ready
  // ============================================================
  late final DataSource _source = MockDataSource();
  // late final DataSource _source = SerialDataSource();

  EgoState _ego = EgoState.empty;
  WarningInfo? _warning;
  String _timeText = "";
  ConnectionStatus _connectionStatus = const ConnectionStatus.mock();

  StreamSubscription<V2VFrame>? _sub;
  Timer? _clockTimer;
  Timer? _staleWatcher;
  DateTime? _lastFrameAt;
  bool _firstFrame = true;

  @override
  void initState() {
    super.initState();
    _initConnectionStatus();
    _startClock();
    _startStream();
    _startStaleWatcher();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clockTimer?.cancel();
    _staleWatcher?.cancel();
    _source.dispose();
    super.dispose();
  }

  // ============================================================
  // Connection status: tergantung tipe DataSource
  // ============================================================
  void _initConnectionStatus() {
    if (_source is MockDataSource) {
      _connectionStatus = const ConnectionStatus.mock();
    } else {
      // SerialDataSource atau lainnya — mulai dengan "live" optimistic,
      // stale watcher akan override jadi DISCONNECTED kalau tidak ada data
      _connectionStatus = const ConnectionStatus.live();
    }
  }

  /// Pantau apakah data masih flowing. Kalau tidak ada frame > 2 detik
  /// dan source bukan mock, anggap stale/disconnected.
  void _startStaleWatcher() {
    _staleWatcher = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_source is MockDataSource) return; // mock selalu hidup
      if (_lastFrameAt == null) return;

      final ageSec = DateTime.now().difference(_lastFrameAt!).inSeconds;
      ConnectionStatus newStatus;
      if (ageSec >= 5) {
        newStatus = const ConnectionStatus.disconnected();
      } else if (ageSec >= 2) {
        newStatus = const ConnectionStatus.stale();
      } else {
        newStatus = const ConnectionStatus.live();
      }
      if (newStatus.level != _connectionStatus.level) {
        setState(() => _connectionStatus = newStatus);
      }
    });
  }

  // ============================================================
  // Stream subscription dari DataSource
  // ============================================================
  void _startStream() {
    _sub = _source.stream().listen(
      (frame) {
        if (!mounted) return;
        _lastFrameAt = DateTime.now();
        setState(() {
          _ego = frame.ego;
          _warning = _computeWarning(frame.ego, frame.neighbors);
          _firstFrame = false;
        });
      },
      onError: (e) {
        debugPrint('DataSource error: $e');
        if (mounted) {
          setState(() => _connectionStatus = const ConnectionStatus.disconnected());
        }
      },
    );
  }

  // ============================================================
  // Hitung warning untuk UI dari ego + list neighbors.
  //
  // Logic:
  //   1. Untuk tiap neighbor: hitung jarak & arah relatif ke ego
  //   2. Base risk dari jarak:
  //        < 10m  → DANGER
  //        < 25m  → WARNING
  //        else   → SAFE
  //   3. Override: kalau neighbor.emergency_status == EMERGENCY,
  //      paksa jadi DANGER (mobil itu broadcast bahaya).
  //   4. Ambil ancaman TERDEKAT sebagai yang ditampilkan.
  // ============================================================
  WarningInfo? _computeWarning(EgoState ego, List<NeighborState> neighbors) {
    if (neighbors.isEmpty) return null;

    WarningInfo? best;
    double bestDist = double.infinity;

    for (final n in neighbors) {
      final dx = n.x - ego.x;
      final dy = n.y - ego.y;
      final distance = sqrt(dx * dx + dy * dy);

      // Tentukan level dari jarak
      WarningLevel level;
      if (distance < 10) {
        level = WarningLevel.danger;
      } else if (distance < 25) {
        level = WarningLevel.warning;
      } else {
        level = WarningLevel.safe;
      }

      // Override dari emergency_status broadcast
      if (n.emergencyStatus == EmergencyStatus.emergency) {
        level = WarningLevel.danger;
      } else if (n.emergencyStatus == EmergencyStatus.warning &&
          level == WarningLevel.safe) {
        level = WarningLevel.warning;
      }

      if (level == WarningLevel.safe) continue;

      // Hanya ambil ancaman terdekat
      if (distance >= bestDist) continue;

      // Tentukan arah relatif (ego frame)
      WarningDirection dir;
      if (dy > 5) {
        dir = WarningDirection.front;
      } else if (dy < -5) {
        dir = WarningDirection.rear;
      } else if (dx < 0) {
        dir = WarningDirection.left;
      } else {
        dir = WarningDirection.right;
      }

      best = WarningInfo(
        level: level,
        direction: dir,
        distance: distance,
      );
      bestDist = distance;
    }

    return best;
  }

  // ============================================================
  // Clock di gauge kiri
  // ============================================================
  void _startClock() {
    _updateTime();
    _clockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    int hour = now.hour;
    final period = hour >= 12 ? "PM" : "AM";
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final mm = now.minute.toString().padLeft(2, '0');
    setState(() => _timeText = "$hour:$mm $period");
  }

  @override
  Widget build(BuildContext context) {
    if (_firstFrame) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E2A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E2A),
      body: SensorView(
        ego: _ego,
        warning: _warning,
        timeText: _timeText,
        connectionStatus: _connectionStatus,
      ),
    );
  }
}
