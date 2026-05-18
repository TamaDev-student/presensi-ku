import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  // Theme Colors from HomePage
  final Color _primaryColor = const Color(0xFF11145A);
  final Color _bgColor = const Color(0xFFF5F6FA);
  final Color _textMuted = const Color(0xFF6C757D);
  final Color _greenAccent = const Color(0xFF16A34A);
  final Color _redAccent = const Color(0xFFDC2626);


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Riwayat Presensi',
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text("Silakan login terlebih dahulu."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('presensi')
                  .where('uid', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _primaryColor));
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Terjadi kesalahan memuat data.'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Ambil dan urutkan data secara lokal (menghindari error Composite Index)
                final docs = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
                docs.sort((a, b) {
                  final waktuA = (a['waktu_scan'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final waktuB = (b['waktu_scan'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return waktuB.compareTo(waktuA); // Descending (terbaru di atas)
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];
                    return _buildRiwayatCard(data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: _textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Belum Ada Riwayat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Anda belum pernah melakukan presensi.',
            style: TextStyle(color: _textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayatCard(Map<String, dynamic> data) {
    final status = data['status'] ?? 'Hadir';
    final mataPelajaran = data['mata_pelajaran'] ?? 'Presensi Hari Ini';
    final lokasi = data['lokasi'] ?? data['ruang'] ?? 'Lingkungan Sekolah';
    final Timestamp? timestamp = data['waktu_scan'] as Timestamp?;
    
    DateTime? waktu;
    String tanggalStr = '-';
    String jamStr = '-';

    if (timestamp != null) {
      waktu = timestamp.toDate();
      // Format tanggal: 24 Jan 2026
      final List<String> bulan = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      tanggalStr = '${waktu.day.toString().padLeft(2, '0')} ${bulan[waktu.month]} ${waktu.year}';
      jamStr = '${waktu.hour.toString().padLeft(2, '0')}:${waktu.minute.toString().padLeft(2, '0')}';
    }

    final isHadir = status.toLowerCase() == 'hadir';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHadir ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isHadir ? Icons.check_circle_outline : Icons.cancel_outlined,
              color: isHadir ? _greenAccent : _redAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          // Info Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        mataPelajaran,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1C1E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      tanggalStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: _textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        lokasi,
                        style: TextStyle(fontSize: 13, color: _textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: _textMuted),
                    const SizedBox(width: 4),
                    Text(
                      jamStr,
                      style: TextStyle(fontSize: 13, color: _textMuted),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isHadir ? _greenAccent.withValues(alpha: 0.1) : _redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isHadir ? _greenAccent : _redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}