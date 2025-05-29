import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text(user != null ? '${user.displayName ?? user.email}\'s Notes ' : 'Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // AuthGate will automatically navigate to LoginScreen
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Welcome to your Pinboard! Items will go here.'),
      ),
    );
  }
}