import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class FirebaseService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  Timer? _anomalyTimer;

  // Stream to listen to anomaly changes
  Stream<bool> get anomalyStream {
    return _database.child('anamoly').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  // Set anomaly status
  Future<void> setAnomaly(bool value) async {
    await _database.child('anamoly').set(value);
  }

  // Handle anomaly detection with 3-second reset
  Future<void> handleAnomaly() async {
    // Set anomaly to true
    await setAnomaly(true);

    // Cancel any existing timer
    _anomalyTimer?.cancel();

    // Create a new timer to set anomaly back to false after 3 seconds
    _anomalyTimer = Timer(const Duration(seconds: 3), () {
      setAnomaly(false);
    });
  }

  void dispose() {
    _anomalyTimer?.cancel();
  }
}
