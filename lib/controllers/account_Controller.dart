import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:todo/models/user.dart';
import 'package:todo/services/userService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final GoogleSignIn googleSignIn = GoogleSignIn.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;

class AccountController {
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await googleSignIn.initialize();

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // LOGIN FIREBASE TRƯỚC
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user == null) {
        return null;
      }

      // TẠO MODEL
      final userModel = UserModel(
        uid: user.uid,
        name: user.displayName ?? "No Name",
        email: user.email ?? "No Email",
        photoUrl: user.photoURL ?? "",
        createdAt: DateTime.now(),
      );

      // LƯU FIRESTORE (NHƯNG KHÔNG GHI ĐÈ)
      await UserService().createUser(userModel: userModel);

      return userCredential;
    } catch (e) {
      print("Lỗi rồi m: $e");
      return null;
    }
  }

  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );

      final user = credential.user;
      if (user == null) return null;

      await user.updateDisplayName(name);
      await user.reload();

      // gửi email xác thực
      await sendVerifyEmail();

      // TẠO MODEL
      final userModel = UserModel(
        uid: user.uid,
        name: name,
        email: normalizedEmail,
        createdAt: DateTime.now(),
      );

      // LƯU FIRESTORE
      await UserService().createUser(userModel: userModel);

      return credential;
    } on FirebaseAuthException catch (e) {
      print("Lỗi Firebase: ${e.code}");
      return null;
    } catch (e) {
      print("Lỗi khác: $e");
      return null;
    }
  }

  Future<void> sendVerifyEmail() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return result;
    } on FirebaseAuthException catch (e) {
      print("Lỗi Firebase: ${e.code}");

      // xử lý lỗi rõ ràng
      if (e.code == 'user-not-found') {
        print("Không tìm thấy user");
      } else if (e.code == 'wrong-password') {
        print("Sai mật khẩu");
      } else if (e.code == 'invalid-email') {
        print("Email không hợp lệ");
      }

      return null;
    } catch (e) {
      print("Lỗi khác: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    print("User Logged Out");
  }

  Future<void> resetPassword(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      // Thông báo cho user check mail
      print("Check mail đi, Firebase gửi link đổi pass rồi đó!");
    } on FirebaseAuthException catch (e) {
      print("Lỗi: ${e.message}");
    }
  }

  Future<UserModel?> findUserByEmail(String email) {
    return UserService().findUserByEmail(email);
  }

  Future<List<UserModel>> getUsersFromIds(List<String> ids) async {
    try {
      if (ids.isEmpty) return [];

      // Tạo futures
      final futures = ids.map((id) async {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(id)
              .get();

          if (!doc.exists || doc.data() == null) return null;

          final data = doc.data()!;
          data['uid'] = doc.id;

          return doc.exists ? UserModel.fromJson(data) : null;
        } catch (e) {
          // Log lỗi riêng cho từng ID
          print("⚠️ Lỗi khi lấy user $id: $e");
          return null;
        }
      }).toList();

      // Chạy song song
      final results = await Future.wait(futures);

      // Lọc null
      final users = results.nonNulls.toList();

      print("✅ Lấy được ${users.length}/${ids.length} users");
      return users;
    } catch (e, stackTrace) {
      print("❌ Lỗi hệ thống: $e");
      print("Stack: $stackTrace");
      return [];
    }
  }
}
