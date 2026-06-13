import 'package:cloud_firestore/cloud_firestore.dart';
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
      if (doc.exists) {
        _cached = AppSettingsModel.fromFirestore(doc.data()!);
        return _cached!;
      }
    } catch (_) {}
    return AppSettingsModel.defaults();
  }

  static void clearCache() => _cached = null;

  static Stream<AppSettingsModel> watchSettings() {
    return FirebaseFirestore.instance
        .collection('app_settings')
        .doc('config')
        .snapshots()
        .map((doc) => doc.exists
            ? AppSettingsModel.fromFirestore(doc.data()!)
            : AppSettingsModel.defaults());
  }
}
