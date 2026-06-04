// ============================================================
// 🔥 V2V FRAME MODEL
//    Bentuk data yang mengalir dari Pi (UKF + Neighbour Track)
//    ke Flutter UI. Sesuai output di diagram arsitektur:
//
//      Pi  ──►  { ego, neighbors }  ──►  Flutter
//
//    Saat MockDataSource: bentuk ini di-generate dari CSV.
//    Saat SerialDataSource: di-parse dari frame JSON via USB CDC.
// ============================================================

/// Status emergency yang di-broadcast tiap kendaraan via LoRA.
enum EmergencyStatus {
  normal,    // NORMAL — kondisi aman
  warning,   // WARNING — perlu hati-hati (misal: pengereman)
  emergency, // EMERGENCY — bahaya (misal: kecelakaan, mogok)
}

/// State mobil ego (kendaraan kita sendiri).
/// Field: GPS fused + OBD + IMU-derived heading.
class EgoState {
  /// Posisi geografis (hasil fusion UKF di Pi).
  final double lat;
  final double lon;

  /// Posisi lokal frame (East, North) dalam meter — untuk perhitungan jarak.
  final double x;
  final double y;

  /// Speed dari OBD (km/h).
  final double speedKmh;

  /// Heading dari IMU/GPS (derajat, 0=Utara, 90=Timur).
  final double headingDeg;

  /// Engine RPM dari OBD PID 0x0C.
  final double engineRpm;

  /// Engine temperature dari OBD PID 0x05 (Celsius).
  final double engineTempC;

  const EgoState({
    required this.lat,
    required this.lon,
    required this.x,
    required this.y,
    required this.speedKmh,
    required this.headingDeg,
    required this.engineRpm,
    required this.engineTempC,
  });

  /// Empty state — placeholder saat data belum masuk.
  static const EgoState empty = EgoState(
    lat: 0,
    lon: 0,
    x: 0,
    y: 0,
    speedKmh: 0,
    headingDeg: 0,
    engineRpm: 0,
    engineTempC: 0,
  );
}

/// State mobil lain (neighbor) yang di-receive via LoRA broadcast.
class NeighborState {
  /// ID unik mobil lain (misal MAC LoRA atau VIN).
  final String id;

  /// Posisi geografis dari broadcast LoRA.
  final double lat;
  final double lon;

  /// Posisi lokal (East, North) relatif ke origin yang sama dengan ego.
  final double x;
  final double y;

  final double speedKmh;
  final double headingDeg;

  /// Status emergency yang DIDEKLARASIKAN sendiri oleh mobil itu via LoRA.
  /// Beda dengan warning UI yang dihitung ego dari jarak.
  final EmergencyStatus emergencyStatus;

  const NeighborState({
    required this.id,
    required this.lat,
    required this.lon,
    required this.x,
    required this.y,
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
