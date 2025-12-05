
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PairingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<User?> ensureSignedIn() async {
    var user = _auth.currentUser;
    if (user == null) {
      final cred = await _auth.signInAnonymously();
      user = cred.user;
    }
    return user;
  }

  Future<String?> findDeviceByCode(String code) async {
    final snap = await _db.child('pairing').get();
    if (!snap.exists) return null;

    final data = Map<dynamic, dynamic>.from(snap.value as Map);

    for (final entry in data.entries) {
      if (entry.value is Map && entry.value['code'] == code) {
        return entry.key.toString();
      }
    }
    return null;
  }

  Future<void> linkDeviceToUser(String deviceId, String uid) async {
    await _db.child('devices/$deviceId').update({
      'ownerUid': uid,
      'pairedAt': DateTime.now().millisecondsSinceEpoch,
    });

    await _db.child('pairing/$deviceId').remove();
  }
}
