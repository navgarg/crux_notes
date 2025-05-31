import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      // Trigger the authentication flow
      print("Attempting to get GoogleSignInAccount...");
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      print("GoogleSignInAccount: ${googleUser?.displayName}");

      // Obtain the auth details from the request
      print("Attempting to get GoogleSignInAuthentication...");
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
      print("GoogleAuth idToken present: ${googleAuth?.idToken != null}");

      // Create a new credential
      if (googleAuth != null) {
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        // Once signed in, return the UserCredential
        print("Attempting FirebaseAuth.instance.signInWithCredential...");
        UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        print("Firebase signInWithCredential SUCCESS: User: ${userCredential.user?.uid}");
      }
    } catch (e) {
      // Handle error, e.g., show a SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in with Google: $e')),
        );
      }
      print(e); // For debugging
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to Notes')),
      body: Center(
        child: _isSigningIn
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
          icon: const Icon(Icons.login), // Or a Google icon
          label: const Text('Sign in with Google'),
          onPressed: _signInWithGoogle,
        ),
      ),
    );
  }
}