import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/app_settings_model.dart';

class SettingsService {
  static AppSettingsModel? _cached;

  static Future<AppSettingsModel> getSettings() async {
    if (_cached != null) return _cached!;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('config')
          .get();
      if (doc.exists && doc.data() != null) {
        _cached = AppSettingsModel.fromFirestore(doc.data()!);
        return _cached!;
      }
    } catch (e) {
      debugPrint('⚠️ Settings load failed, using defaults: $e');
    }
    _cached = AppSettingsModel.defaults();
    return _cached!;
  }

  static void clearCache() => _cached = null;

  static Stream<AppSettingsModel> watchSettings() {
    return FirebaseFirestore.instance
        .collection('app_settings')
        .doc('config')
        .snapshots()
        .map((doc) => doc.exists && doc.data() != null
            ? AppSettingsModel.fromFirestore(doc.data()!)
            : AppSettingsModel.defaults());
  }

  static Stream<bool> maintenanceModeStream() {
    return FirebaseFirestore.instance
        .collection('app_settings')
        .doc('config')
        .snapshots()
        .map((snap) => snap.data()?['maintenanceMode'] ?? false);
  }
}
