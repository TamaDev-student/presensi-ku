import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class IzinScreen extends StatefulWidget {
  const IzinScreen({super.key});

  @override
  State<IzinScreen> createState() => _IzinScreenState();
}

class _IzinScreenState extends State<IzinScreen> {
  // ── Tema Warna ─────────────────────────────
  static const Color _primary   = Color(0xFF11145A);
  static const Color _accent    = Color(0xFF2D3AB7);
  static const Color _bg        = Color(0xFFF5F6FA);
  static const Color _muted     = Color(0xFF6C757D);
  static const Color _inputFill = Color(0xFFEEF0FB);

  // ── State ───────────────────────────────────
  String _jenisIzin = 'Pilih';
  DateTime? _tanggalDari;
  DateTime? _tanggalSampai;
  final TextEditingController _namaController    = TextEditingController();
  final TextEditingController _alasanController  = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _prefillNama();
  }

  Future<void> _prefillNama() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (mounted) {
      _namaController.text = doc.data()?['nama'] ?? user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alasanController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────
  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    const b = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${dt.day.toString().padLeft(2,'0')} ${b[dt.month]} ${dt.year}';
  }

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 14)),
    lastDate: DateTime.now().add(const Duration(days: 30)),
    builder: (ctx, child) => Theme(
      data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(primary: _primary),
      ),
      child: child!,
    ),
  );

  Future<void> _kirim() async {
    if (_namaController.text.trim().isEmpty) {
      _snack('Masukkan nama Anda terlebih dahulu.');
      return;
    }
    if (_jenisIzin == 'Pilih') {
      _snack('Pilih jenis izin terlebih dahulu.');
      return;
    }
    if (_alasanController.text.trim().isEmpty) {
      _snack('Isi keterangan / alasan terlebih dahulu.');
      return;
    }
    if (_tanggalDari == null || _tanggalSampai == null) {
      _snack('Pilih rentang tanggal terlebih dahulu.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Cek apakah sudah pernah izin hari ini
      final snapshot = await FirebaseFirestore.instance
          .collection('izin')
          .where('uid', isEqualTo: user.uid)
          .get();

      final now = DateTime.now();
      bool hasIzinToday = false;
      for (var doc in snapshot.docs) {
        final createdAt = (doc.data()['created_at'] as Timestamp?)?.toDate();
        if (createdAt != null &&
            createdAt.year == now.year &&
            createdAt.month == now.month &&
            createdAt.day == now.day) {
          hasIzinToday = true;
          break;
        }
      }

      if (hasIzinToday) {
        if (mounted) _snack('Anda sudah mengajukan izin hari ini. Maksimal 1 kali per hari.');
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('izin').add({
        'uid'            : user.uid,
        'nama_siswa'     : _namaController.text.trim(),
        'jenis_izin'     : _jenisIzin,
        'alasan'         : _alasanController.text.trim(),
        'tanggal_dari'   : Timestamp.fromDate(_tanggalDari!),
        'tanggal_sampai' : Timestamp.fromDate(_tanggalSampai!),
        'status_izin'    : 'Menunggu',
        'created_at'     : FieldValue.serverTimestamp(),
      });

      // Kirim notifikasi WhatsApp ke Wali Kelas
      await _sendWhatsApp();

      if (mounted) {
        _snack('Pengajuan izin berhasil dikirim! ✅', isSuccess: true);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) _snack('Gagal mengirim: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
    ));
  }

  // Kirim notifikasi ke WA Wali Kelas
  Future<void> _sendWhatsApp() async {
    try {
      // Ambil nomor WA wali kelas dari Firestore settings
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('sekolah')
          .get();
      final noWa = settingsDoc.data()?['no_wa_walikelas'] as String? ?? '';
      if (noWa.isEmpty) {
        // Nomor belum diatur di Firestore, tidak ada WA yang dikirim
        debugPrint('[WA] no_wa_walikelas belum diatur di settings/sekolah');
        return;
      }

      // Format nomor: hapus karakter non-angka, ganti 0 di depan dengan 62
      String nomor = noWa.replaceAll(RegExp(r'[^0-9]'), '');
      if (nomor.startsWith('0')) nomor = '62${nomor.substring(1)}';
      if (!nomor.startsWith('62')) nomor = '62$nomor';

      // Susun pesan dalam satu string
      final pesan =
          '🔔 *Pengajuan $_jenisIzin*\n'
          '👤 Nama   : ${_namaController.text.trim()}\n'
          '📅 Dari   : ${_fmt(_tanggalDari)}\n'
          '📅 Sampai : ${_fmt(_tanggalSampai)}\n'
          '📝 Alasan : ${_alasanController.text.trim()}\n\n'
          '_Mohon konfirmasi pengajuan ini._';

      // Gunakan Uri.replace agar Dart yang menangani encoding secara otomatis
      final uri = Uri.parse('https://wa.me/$nomor')
          .replace(queryParameters: {'text': pesan});

      debugPrint('[WA] Mencoba buka: $uri');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('[WA] canLaunchUrl returned false');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat membuka WhatsApp. Pastikan WA sudah terinstal.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[WA] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka WhatsApp: $e'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Menu Pengajuan Izin',
          style: TextStyle(color: _primary, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Banner ──────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _accent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_document, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Isi Form Sesuai Pengajuan ya!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Nama ───────────────────────────
            _inputField(
              controller: _namaController,
              hint: 'Masukan Nama Anda',
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 14),

            // ── Label Keterangan ───────────────
            _sectionLabel('Keterangan'),
            const SizedBox(height: 8),
            _inputField(
              controller: _alasanController,
              hint: 'Tuliskan alasan Anda...',
              icon: Icons.notes_rounded,
              maxLines: 3,
            ),

            const SizedBox(height: 14),

            // ── Dropdown Jenis Izin ────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primary.withValues(alpha: 0.15)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _jenisIzin,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: _primary),
                  style: const TextStyle(color: Color(0xFF1A1C1E), fontSize: 14),
                  items: ['Pilih', 'Sakit', 'Izin'].map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(v == 'Pilih' ? 'Pilih jenis izin...' : v),
                  )).toList(),
                  onChanged: (v) => setState(() => _jenisIzin = v!),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Rentang Tanggal ───────────────
            Row(
              children: [
                // FROM
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final d = await _pickDate(_tanggalDari ?? DateTime.now());
                      if (d != null) setState(() => _tanggalDari = d);
                    },
                    child: _dateBox('From', _tanggalDari),
                  ),
                ),
                const SizedBox(width: 12),
                // UNTIL
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final d = await _pickDate(_tanggalSampai ?? (_tanggalDari ?? DateTime.now()));
                      if (d != null) setState(() => _tanggalSampai = d);
                    },
                    child: _dateBox('Until', _tanggalSampai),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),

            // ── Tombol Kirim ──────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _kirim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Ajukan Sekarang',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget Helpers ───────────────────────────
  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _muted,
      letterSpacing: 0.5,
    ),
  );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _muted.withValues(alpha: 0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true,
        fillColor: _inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _dateBox(String label, DateTime? dt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month, color: _primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
                const SizedBox(height: 2),
                Text(
                  _fmt(dt),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: dt == null ? _muted : const Color(0xFF1A1C1E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
