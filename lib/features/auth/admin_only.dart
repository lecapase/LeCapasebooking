import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Mount sensitive content only while the current account is an active admin.
class AdminOnly extends StatelessWidget {
  const AdminOnly({super.key, required this.child});
  final Widget child;

  Widget _blocked({bool loading = false}) => Scaffold(
    appBar: AppBar(title: const Text('Accesso riservato')),
    body: Center(
      child: loading
          ? const CircularProgressIndicator()
          : const Text('Questa sezione è riservata agli amministratori.'),
    ),
  );

  Widget _profile(String collection, String uid, {bool legacy = false}) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey('$collection/$uid'),
        stream: FirebaseFirestore.instance
            .collection(collection)
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _blocked();
          if (!snapshot.hasData) return _blocked(loading: true);
          if (!snapshot.data!.exists && !legacy) {
            return _profile('admins', uid, legacy: true);
          }
          final data = snapshot.data!.data();
          return data?['active'] == true && data?['role'] == 'admin'
              ? child
              : _blocked();
        },
      );

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _blocked();
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _blocked(loading: true);
      }
      final user = snapshot.data;
      return user == null ? _blocked() : _profile('staff_users', user.uid);
    },
  );
}
