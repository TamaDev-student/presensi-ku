import 'package:flutter/material.dart';
import 'scan_qr.dart';
import 'riwayat_screen.dart';
import 'profil_screen.dart';
import 'izin_screen.dart';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // Firebase User Data
  String _nama = 'Loading...';
  String _kelas = '';
  String? _photoBase64;
  int _hariHadir = 0;
  int _hariTanpaKeterangan = 0;
  int _menitTerlambat = 0;
  double _rasioKehadiran = 0.0;
  bool _sudahPresensiHariIni = false;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Fetch User Data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _nama = data['nama'] ?? user.displayName ?? 'Siswa';
        _kelas = data['kelas'] ?? '-';
        _photoBase64 = data['photo_base64'];
      }

      // 2. Fetch Presensi Data
      final presensiSnapshot = await FirebaseFirestore.instance
          .collection('presensi')
          .where('uid', isEqualTo: user.uid)
          .get();

      int hadir = 0;
      int alpha = 0;
      int menitTerlambat = 0;
      bool sudahPresensi = false;
      final now = DateTime.now();

      final docs = presensiSnapshot.docs.map((doc) => doc.data()).toList();

      for (var data in docs) {
        final status = data['status'] ?? '';
        final waktu = (data['waktu_scan'] as Timestamp?)?.toDate();

        if (waktu != null && 
            waktu.year == now.year && 
            waktu.month == now.month && 
            waktu.day == now.day) {
          sudahPresensi = true;
        }

        if (status == 'Hadir') hadir++;
        if (status == 'Alpha') alpha++;
        if (status == 'Terlambat') {
          hadir++; // Usually terlambat counts as hadir but with penalty
          menitTerlambat += (data['keterlambatan_menit'] as int?) ?? 0;
        }
      }

      // Hitung rasio kehadiran (asumsi 1 semester = 100 hari efektif)
      int totalHariEfektif = 100;
      double rasio = (hadir / totalHariEfektif);

      setState(() {
        _hariHadir = hadir;
        _hariTanpaKeterangan = alpha;
        _menitTerlambat = menitTerlambat;
        _rasioKehadiran = rasio;
        _sudahPresensiHariIni = sudahPresensi;
      });
    } catch (e) {
      debugPrint("Gagal mengambil data: $e");
    }
  }

  // Colors
  final Color _primaryColor = const Color(0xFF11145A);
  final Color _darkBlue = const Color(0xFF0D0F4A);
  final Color _accentBlue = const Color(0xFF2A2D7C);
  final Color _bgColor = const Color(0xFFF5F6FA);
  final Color _greenAccent = const Color(0xFF34D399);
  final Color _pinkAccent = const Color(0xFFFFE0E6);
  final Color _blueLight = const Color(0xFFE8F0FE);
  final Color _textMuted = const Color(0xFF6C757D);

  Widget _buildHomeContent() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== HEADER ==========
            _buildHeader(),

            // ========== GREETING CARD ==========
            _buildGreetingCard(),

            // ========== SCAN BUTTON ==========
            _buildScanButton(),

            const SizedBox(height: 24),

            // ========== RINGKASAN KEHADIRAN ==========
            _buildKehadiranSection(),

            const SizedBox(height: 20),

            // ========== STATS CARDS ==========
            _buildStatsCards(),

            const SizedBox(height: 16),

            // ========== ABSEN CARD ==========
            _buildAbsenCard(),

            const SizedBox(height: 16),

            // ========== MOTIVATIONAL BANNER ==========
            _buildMotivationalBanner(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Home
          _buildHomeContent(),
          // Tab 1: Scan
          ScanQrScreen(
            onBack: () {
              setState(() {
                _currentIndex = 0;
              });
              _fetchDashboardData();
            },
          ),
          // Tab 2: Riwayat
          const RiwayatScreen(),
          // Tab 3: Profile
          const ProfilScreen(),
        ],
      ),
      // bottom navigation bar
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  
  // HEADER
  String _formatCurrentDate() {
    final now = DateTime.now();
    final List<String> hari = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final List<String> bulan = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    int dayIndex = now.weekday == 7 ? 0 : now.weekday;
    return '${hari[dayIndex]}, ${now.day} ${bulan[now.month]} ${now.year}';
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_primaryColor, _accentBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _photoBase64 != null && _photoBase64!.isNotEmpty
                ? ClipOval(
                    child: Image.memory(
                      base64Decode(_photoBase64!),
                      fit: BoxFit.cover,
                      width: 44,
                      height: 44,
                    ),
                  )
                : const Center(
                    child: Icon(Icons.person, color: Colors.white, size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Presensi Ku',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _nama,
                  style: TextStyle(fontSize: 13, color: _textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // greeting card
  Widget _buildGreetingCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkBlue, const Color(0xFF1A1D6E), _accentBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            'Selamat Pagi, ${_nama.split(' ')[0]} 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_kelas.isNotEmpty)
            Text(
              'Kelas : $_kelas',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 8),
          // Date Row
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.white.withValues(alpha: 0.7),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                _formatCurrentDate(), // Memanggil helper method
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _sudahPresensiHariIni ? _greenAccent.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _sudahPresensiHariIni ? _greenAccent.withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _sudahPresensiHariIni ? _greenAccent : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _sudahPresensiHariIni ? 'Status : Sudah Presensi' : 'Status : Belum Presensi',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // scan button
  Widget _buildScanButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentIndex = 1;
                });
              },
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text(
                'Scan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _primaryColor,
                elevation: 2,
                shadowColor: _primaryColor.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: _primaryColor.withValues(alpha: 0.15)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const IzinScreen()),
                );
              },
              icon: const Icon(Icons.edit_document, size: 20),
              label: const Text(
                'Ajukan Izin',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF11145A),
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

 
  // ringkasan kehadiran
  Widget _buildKehadiranSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ringkasan Kehadiran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _blueLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SEMESTER GENAP',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Rasio Kehadiran
            Text(
              'Rasio Kehadiran',
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (_rasioKehadiran * 100).toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _rasioKehadiran,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  
  // STATS CARDS
  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // PRESENSI card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE8FFF0),
                    const Color(0xFFD1FAE5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _greenAccent.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _greenAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.check_circle,
                          color: _greenAccent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PRESENSI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF059669),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_hariHadir',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hari tercatat',
                    style: TextStyle(fontSize: 11, color: _textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // TERLAMBAT card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.access_time,
                          color: _textMuted,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Terlambat',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$_menitTerlambat Menit',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'akumulasi terlambat',
                    style: TextStyle(fontSize: 11, color: _textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  // ABSEN CARD
  Widget _buildAbsenCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _pinkAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cancel,
                color: Color(0xFFE11D48),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hariTanpaKeterangan.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tanpa keterangan',
                    style: TextStyle(fontSize: 12, color: _textMuted),
                  ),
                ],
              ),
            ),
            // ABSEN label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ABSEN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MOTIVATIONAL BANNER
  Widget _buildMotivationalBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_blueLight, const Color(0xFFD6E4FF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emoji_events, color: _primaryColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jumlah Presensi: $_hariHadir Hari',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pertahankan konsistensi kehadiranmu di bulan ini.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ==========================================
  // BOTTOM NAVIGATION
  // ==========================================
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // Refresh data home saat kembali dari Scan atau Profile
            if (index == 0 && _currentIndex != 0) {
              _fetchDashboardData();
            }
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: _primaryColor,
          unselectedItemColor: _textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}