import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/customer/emergency_contacts_screen.dart';

class EmergencyContactService {
  static Future<List<EmergencyContact>> getContacts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('emergency_contacts')
        .get();

    if (!snap.exists) return [];

    final data = snap.data() as Map<String, dynamic>;

    return (data['contacts'] as List? ?? [])
        .map((e) => EmergencyContact.fromMap(e))
        .toList();
  }
}