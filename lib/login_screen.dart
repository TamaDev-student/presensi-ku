
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFF11145A);
  final Color _bgColor = const Color(0xFFF8F9FA);
  final Color _textColor = const Color(0xFF1A1C1E);
  final Color _textMutedColor = const Color(0xFF6C757D);

  Future<void> signInWithGoogle({bool loginAsGuru = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // initialize() bisa throw error jika sudah pernah dipanggil sebelumnya
      // (misalnya setelah logout). Tangkap errornya agar alur tetap berjalan.
      try {
        await GoogleSignIn.instance.initialize(
          serverClientId:
              '524638568840-ugbg4g2dblsjaelh0dhs446pesn5g5tt.apps.googleusercontent.com',
        );
      } catch (_) {
        // Sudah diinisialisasi sebelumnya — lanjutkan saja
      }

      final googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: null,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final DocumentReference userRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final DocumentSnapshot userDoc = await userRef.get();

        if (!userDoc.exists) {
          // Auto-Register: akun baru → selalu role siswa
          await userRef.set({
            'nama': user.displayName ?? '',
            'email': user.email ?? '',
            'kelas': '',
            'nis': '',
            'role': 'siswa',
            'created_at': FieldValue.serverTimestamp(),
          });
        }

        // ── Validasi Role vs Pilihan Login ─────────────────────
        final data = userDoc.data() as Map<String, dynamic>?;
        final role = (data?['role'] ?? 'siswa').toString().toLowerCase().trim();
        final isGuru = role == 'guru' || role == 'admin';

        if (loginAsGuru && !isGuru) {
          // Siswa mencoba login sebagai guru → tolak
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Akun Anda bukan akun Guru. Silakan login sebagai Siswa.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        if (!loginAsGuru && isGuru) {
          // Guru mencoba login sebagai siswa → arahkan ke pilihan guru
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Akun Anda adalah akun Guru. Silakan login sebagai Guru.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }
      // Navigasi ditangani otomatis oleh StreamBuilder di main.dart
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login gagal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/smaperak-logo.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SMA Perak Yogyakarta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Welcome Text
              Center(
                child: Column(
                  children: [
                    Text(
                      'Selamat Datang di',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SMA Perak Yogyakarta',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),


              // --- FORM MANUAL TELAH DIHAPUS ---
              // Login hanya menggunakan Google Sign-In yang terintegrasi dengan deteksi Role
              const SizedBox(height: 32),

              // TOMBOL LOGIN SISWA
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => signInWithGoogle(loginAsGuru: false),
                  icon: const Icon(Icons.school_outlined, size: 22, color: Colors.white),
                  label: const Text(
                    'Masuk sebagai Siswa',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF11145A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // TOMBOL LOGIN GURU
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => signInWithGoogle(loginAsGuru: true),
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 22, color: Color(0xFF11145A)),
                  label: const Text(
                    'Masuk sebagai Guru',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF11145A)),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Color(0xFF11145A), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // FOOTER
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFBBF7D0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user,
                      color: Color(0xFF16A34A),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dilindungi oleh Protokol Identitas Academic Pulse. Data Anda tetap bersifat pribadi dan terenkripsi.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textMutedColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}