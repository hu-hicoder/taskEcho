import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/calendar/v3.dart' show CalendarApi;

class GoogleAuth {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: dotenv.env['GOOGLE_CLIENT_ID'], // 環境変数からクライアントIDを取得
    scopes: [
      'email',
      'profile',
      CalendarApi.calendarScope
    ]
  );

  // サイレントサインインを試みる
  static Future<User?> signInWithGoogle() async {
    if (!kIsWeb) {
      try {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          print("Silent Sign-In failed: No previous session found.");
          return null; // 
        }

        // Google認証情報を取得
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Firebase用の資格情報を作成
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        final User? user = userCredential.user;

        return user;
      } catch (e) {
        print("Error during Google Sign In: $e");
        return null;
      }
    } else {
      final provider = GoogleAuthProvider();
      try {
        final result = await FirebaseAuth.instance.signInWithPopup(provider);
        return result.user;
      } catch (e) {
        print('Error during Google Sign In (web): $e');
        return null;
      }
    }
  }

  static Future<User?> signInAnonymously() async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("Error during Anonymous Sign-In: $e");
      return null;
    }
  }

  // ログアウト処理
  static Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}