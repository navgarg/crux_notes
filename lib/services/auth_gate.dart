import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../screens/board_screen.dart';
import '../screens/login_screen.dart';

class AuthGate extends ConsumerWidget{
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    print("Building AuthGate, current auth state: $authState");
    return authState.when(
      data: (user) {
        if (user != null) {
          print("User is authenticated: ${user.email}");
          return const BoardScreen();
        }
        print("User is not authenticated, showing login screen");
        return const LoginScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}