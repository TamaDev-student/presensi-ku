import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profil_screen.dart';
import 'dart:convert';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF11145A);
  static const Color _bg = Color(0xFFF5F6FA);

  late TabController _tabController;

  String? _photoBase64;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAdminProfile();
  }

  Future<void> _fetchAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _photoBase64 = doc.data()?['photo_base64'];
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Dashboard Guru',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilScreen()),
                ).then((_) {
                  _fetchAdminProfile(); // Refresh jika foto diganti
                });
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: _photoBase64 != null && _photoBase64!.isNotEmpty
                    ? ClipOval(
                        child: Image.memory(
                          base64Decode(_photoBase64!),
                          fit: BoxFit.cover,
                          width: 36,
                          height: 36,
                        ),
                      )
                    : const Icon(Icons.person, color: _primary, size: 20),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.fact_check_outlined, size: 20), text: 'Presensi Siswa'),
            Tab(icon: Icon(Icons.mail_outline, size: 20), text: 'Pengajuan Izin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPresensiTab(),
          _buildIzinTab(),
        ],
      ),
    );
  }

  
  // TAB 1 — DAFTAR PRESENSI
  Widget _buildPresensiTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('presensi').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Gagal memuat data presensi."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState('Belum ada data presensi\ndari siswa manapun.', Icons.fact_check_outlined);
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final waktuA = (dataA['waktu_scan'] as Timestamp?)?.toDate() ?? DateTime(0);
            final waktuB = (dataB['waktu_scan'] as Timestamp?)?.toDate() ?? DateTime(0);
            return waktuB.compareTo(waktuA);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Hadir';
            final namaSiswa = data['nama_siswa'] ?? 'Siswa';
            final lokasi = data['lokasi'] ?? data['ruang'] ?? '-';
            final Timestamp? ts = data['waktu_scan'] as Timestamp?;
            String waktuStr = '-';
            if (ts != null) {
              final dt = ts.toDate();
              waktuStr = '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
            }
            final isHadir = status.toString().toLowerCase() == 'hadir';

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isHadir ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  child: Icon(
                    isHadir ? Icons.check_circle : Icons.warning_rounded,
                    color: isHadir ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                ),
                title: Text(namaSiswa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('📍 $lokasi', style: const TextStyle(fontSize: 12)),
                    Text('🕒 $waktuStr', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isHadir ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.toString().toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  
  // TAB 2 — PENGAJUAN IZIN
  Widget _buildIzinTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('izin').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primary));
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Gagal memuat pengajuan izin."));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState('Belum ada pengajuan izin\ndari siswa manapun.', Icons.mail_outline);
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final tA = (dataA['created_at'] as Timestamp?)?.toDate() ?? DateTime(0);
            final tB = (dataB['created_at'] as Timestamp?)?.toDate() ?? DateTime(0);
            return tB.compareTo(tA);
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final nama = data['nama_siswa'] ?? 'Siswa';
            final jenis = data['jenis_izin'] ?? 'Izin';
            final alasan = data['alasan'] ?? '-';
            final status = data['status_izin'] ?? 'Menunggu';
            final dari = (data['tanggal_dari'] as Timestamp?)?.toDate();
            final sampai = (data['tanggal_sampai'] as Timestamp?)?.toDate();
            final tglStr = (dari != null && sampai != null)
                ? '${dari.day}/${dari.month}/${dari.year} – ${sampai.day}/${sampai.month}/${sampai.year}'
                : '-';

            Color statusColor;
            IconData statusIcon;
            if (status == 'Disetujui') {
              statusColor = const Color(0xFF16A34A);
              statusIcon = Icons.check_circle;
            } else if (status == 'Ditolak') {
              statusColor = const Color(0xFFDC2626);
              statusIcon = Icons.cancel;
            } else {
              statusColor = Colors.orange;
              statusIcon = Icons.hourglass_top;
            }

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header baris nama + badge status
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: _primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(nama,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(status,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text('📋 Jenis  : $jenis', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('📅 Tanggal: $tglStr', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('📝 Alasan  : $alasan', style: const TextStyle(fontSize: 13)),

                    // Tombol Setujui / Tolak hanya tampil jika masih "Menunggu"
                    if (status == 'Menunggu') ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _updateStatusIzin(doc.id, 'Ditolak'),
                              icon: const Icon(Icons.close, size: 18, color: Color(0xFFDC2626)),
                              label: const Text('Tolak', style: TextStyle(color: Color(0xFFDC2626))),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFDC2626)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _updateStatusIzin(doc.id, 'Disetujui'),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Setujui'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatusIzin(String docId, String statusBaru) async {
    try {
      await FirebaseFirestore.instance.collection('izin').doc(docId).update({
        'status_izin': statusBaru,
        'diproses_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Izin berhasil $statusBaru!'),
            backgroundColor: statusBaru == 'Disetujui' ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses: $e')),
        );
      }
    }
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
  }
}
