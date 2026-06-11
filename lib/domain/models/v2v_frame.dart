// ============================================================
// 🔥 V2V FRAME MODEL
//    Bentuk data yang mengalir dari Pi ke Flutter UI.
//
//    Mengikuti diagram arsitektur:
//
//      [Sensor] ─► [MCU: pack frame] ─► [Pi: UKF + Neighbour Track]
//                                            │
//                            output (lat/lon, speed, heading):
//                              • Ego:        dari UKF
//                              • Neighbors:  dari Neighbour Track
//                                            │
//                                      ▼ JSON @ ~10Hz
//                                 [Flutter UI]
//
//    Format koordinat: GEOGRAPHIC (lat/lon WGS84), bukan ENU/x-y.
//    Flutter yang lakukan konversi lat/lon → distance & arah relatif.
// ============================================================

/// Status emergency yang di-broadcast tiap kendaraan via LoRA.
enum EmergencyStatus {
  normal,    // NORMAL — kondisi aman
  warning,   // WARNING — perlu hati-hati (misal: pengereman)
  emergency, // EMERGENCY — bahaya (misal: kecelakaan, mogok)
}

/// State mobil ego (kendaraan kita sendiri).
/// Output dari Unscented Kalman Filter di Pi.
class EgoState {
  /// Posisi geografis (lat/lon WGS84).
  final double lat;
  final double lon;

  /// Speed dari OBD (km/h).
  final double speedKmh;

  /// Heading (derajat, 0=Utara, 90=Timur, clockwise).
  /// Penting untuk hitung arah RELATIF saat menentukan warning LEFT/RIGHT/FRONT/REAR.
  final double headingDeg;

  /// Engine RPM dari OBD PID 0x0C.
  final double engineRpm;

  /// Engine temperature dari OBD PID 0x05 (Celsius).
  final double engineTempC;

  /// Fuel level dari OBD PID 0x2F. Range 0-100 (persen).
  /// 0 = tangki kosong, 100 = tangki penuh.
  final double fuelLevelPct;

  const EgoState({
    required this.lat,
    required this.lon,
    required this.speedKmh,
    required this.headingDeg,
    required this.engineRpm,
    required this.engineTempC,
    required this.fuelLevelPct,
  });

  /// Empty state — placeholder saat data belum masuk.
  static const EgoState empty = EgoState(
    lat: 0,
    lon: 0,
    speedKmh: 0,
    headingDeg: 0,
    engineRpm: 0,
    engineTempC: 0,
    fuelLevelPct: 0,
  );
}

/// State mobil lain (neighbor) — output dari Neighbour Track di Pi.
/// Posisi datang sebagai LoRA broadcast lalu di-track/propagate.
class NeighborState {
  /// ID unik mobil lain (misal MAC LoRA atau VIN).
  final String id;

  /// Posisi geografis dari broadcast LoRA.
  final double lat;
  final double lon;

  /// Speed (km/h) dari neighbor.
  final double speedKmh;

  /// Heading (derajat, 0=Utara).
  final double headingDeg;

  /// Status emergency yang DIDEKLARASIKAN sendiri oleh mobil itu via LoRA.
  /// Beda dengan warning UI yang dihitung ego dari jarak.
  final EmergencyStatus emergencyStatus;

  const NeighborState({
    required this.id,
    required this.lat,
    required this.lon,
    required this.speedKmh,
    required this.headingDeg,
    required this.emergencyStatus,
  });
}

/// Satu frame snapshot V2V — semua yang UI butuhkan untuk 1 render cycle.
class V2VFrame {
  /// Timestamp millis since epoch.
  final int timestamp;

  final EgoState ego;
  final List<NeighborState> neighbors;

  const V2VFrame({
    required this.timestamp,
    required this.ego,
    required this.neighbors,
  });
}
