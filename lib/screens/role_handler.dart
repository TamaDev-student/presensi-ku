import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';
import 'admin_homepage.dart';
import '../login_screen.dart';
import 'register_siswa_screen.dart';

class RoleHandler extends StatefulWidget {
  const RoleHandler({super.key});

  @override
  State<RoleHandler> createState() => _RoleHandlerState();
}

class _RoleHandlerState extends State<RoleHandler> {
  static const Color _primaryColor = Color(0xFF11145A);

  Future<Widget> _getTargetPage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginScreen();

    // Retry hingga 3x jika Firestore lambat
    for (int i = 0; i < 3; i++) {
      try {
        // Coba baca dari cache lokal terlebih dahulu agar instan
        DocumentSnapshot doc;
        try {
          doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.cache));
        } catch (_) {
          // Jika tidak ada di cache, paksa ambil dari server
          doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.server));
        }

        if (!doc.exists) {
          // Dokumen belum ada, default ke siswa
          return const HomePage();
        }

        final data = doc.data() as Map<String, dynamic>?;
        final role = (data?['role'] ?? 'siswa').toString().toLowerCase().trim();

        if (role == 'guru' || role == 'admin') {
          return const AdminHomePage();
        } else {
          final isProfileComplete = data?['is_profile_complete'] == true;
          // Cek juga fallback kalau field is_profile_complete belum ada tapi nis kosong (untuk keamanan)
          final hasNis = (data?['nis'] != null && data!['nis'].toString().trim().isNotEmpty);
          
          if (!isProfileComplete && !hasNis) {
            return const RegisterSiswaScreen();
          }
          return const HomePage();
        }
      } catch (e) {
        // Tunggu sebentar lalu coba lagi
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Jika 3x gagal semua, lempar ke LoginScreen bukan ke siswa
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getTargetPage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  SizedBox(height: 16),
                  Text(
                    'Memverifikasi akun...',
                    style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text('Gagal memuat profil.\nPeriksa koneksi Anda.', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                    onPressed: () => setState(() {}),
                    child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        return snapshot.data!;
      },
    );
  }
}
