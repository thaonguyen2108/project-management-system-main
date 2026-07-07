import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:todo/models/user.dart';

class UserService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  String? get uid => currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _currentUserRef {
    final currentUid = uid;
    if (currentUid == null || currentUid.isEmpty) return null;
    return _db.collection('users').doc(currentUid);
  }

  Future<void> createUser({required UserModel userModel}) async {
    final userId = userModel.uid.trim();
    if (userId.isEmpty) {
      throw StateError("Missing user uid");
    }

    final userRef = _db.collection('users').doc(userId);
    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set(userModel.toJson(isCreate: true));
    }
  }

  Future<Map<String, dynamic>?> getUser() async {
    final userRef = _currentUserRef;
    if (userRef == null) return null;

    final doc = await userRef.get();
    if (!doc.exists) return null;

    return doc.data();
  }

  Future<UserModel?> getUserById(String uid) async {
    final userId = uid.trim();
    if (userId.isEmpty) return null;

    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;

    return UserModel.fromJson({...data, 'uid': doc.id});
  }

  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedIds.isEmpty) return [];

    final users = await Future.wait(normalizedIds.map(getUserById));
    return users.nonNulls.toList();
  }

  Future<UserModel?> findUserByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();
    data['uid'] = doc.id;

    return UserModel.fromJson(data);
  }

  Future<void> updateUser({required UserModel userModel}) async {
    final userRef = _currentUserRef;
    if (userRef == null) {
      throw StateError("No authenticated user");
    }

    await userRef.update(userModel.toJson());
  }

  Future<void> updateDisplayName(String name) async {
    final userRef = _currentUserRef;
    final normalizedName = name.trim();
    if (userRef == null) {
      throw StateError("No authenticated user");
    }
    if (normalizedName.isEmpty) {
      throw ArgumentError("Display name cannot be empty");
    }

    await userRef.update({"name": normalizedName});
  }

  Future<void> deleteUserData() async {
    final userRef = _currentUserRef;
    if (userRef == null) return;

    await userRef.delete();
  }
}
