import 'package:flutter/material.dart';
import '../auth/googleSignIn.dart';
import '../main.dart'; // AuthWrapper を使います

class SignInPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // gradient: LinearGradient(
          //   begin: Alignment.topCenter,
          //   end: Alignment.bottomCenter,
          //   colors: [
          //     Colors.indigoAccent,
          //     Colors.deepPurpleAccent,
          //   ],
          // ),
          color: Colors.white,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Text(
                //   'taskEcho',
                //   style: TextStyle(
                //     fontSize: 40,
                //     fontWeight: FontWeight.bold,
                //     color: Colors.white,
                //     letterSpacing: 2,
                //   ),
                // ),
                Image.asset(
                  'assets/images/TaskEcho_lightmode.png',
                  width: 280,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 65),
                ElevatedButton.icon(
                  icon: Icon(Icons.login, size: 24, color: Colors.white),
                  label: Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(33, 150, 243, 0.75),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 6,
                  ),
                  onPressed: () async {
                    final user = await GoogleAuth.signInWithGoogle();
                    if (user != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => AuthWrapper()),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),  // ← ここで間隔を空ける
                ElevatedButton.icon(
                  icon: Icon(Icons.person_outline, size: 24, color: Colors.white),
                  label: Text(
                    'Continue as Guest',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    // backgroundColor: Color.fromRGBO(65, 30, 124, 0.75),
                    backgroundColor: Colors.black54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 6,
                  ),
                  onPressed: () async {
                    final user = await GoogleAuth.signInAnonymously();
                    if (user != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => AuthWrapper()),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}