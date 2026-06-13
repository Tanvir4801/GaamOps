import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_settings_model.dart';

class SettingsService {
  static AppSettingsModel? _cached;

  static Future<AppSettingsModel> getSettings() async {
  print('SETTINGS 1');

  if (_cached != null) {
    print('SETTINGS CACHE');
    return _cached!;
  }

  try {
    print('SETTINGS 2');

    final doc = await FirebaseFirestore.instance
        .collection('app_settings')
        .doc('config')
        .get();

    print('SETTINGS 3 exists=${doc.exists}');

    if (doc.exists) {
      _cached = AppSettingsModel.fromFirestore(doc.data()!);
      print('SETTINGS 4');
      return _cached!;
    }
  } catch (e) {
    print('SETTINGS ERROR: $e');
  }

  print('SETTINGS DEFAULT');
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
