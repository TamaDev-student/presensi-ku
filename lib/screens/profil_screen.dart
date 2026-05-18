import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:convert';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  final Color _primaryColor = const Color(0xFF11145A);
  final Color _bgColor = const Color(0xFFF5F6FA);
  final Color _textMuted = const Color(0xFF6C757D);

  Map<String, dynamic> _userData = {};
  int _hariHadir = 0;
  int _totalHari = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch User Profile
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        // Fetch Presensi untuk menghitung kehadiran
        final presensiSnapshot = await FirebaseFirestore.instance
            .collection('presensi')
            .where('uid', isEqualTo: user.uid)
            .get();

        int hadir = 0;
        int total = presensiSnapshot.docs.length;

        for (var pDoc in presensiSnapshot.docs) {
          final status = pDoc.data()['status'] ?? '';
          if (status == 'Hadir' || status == 'Terlambat') {
            hadir++;
          }
        }

        if (doc.exists && mounted) {
          setState(() {
            _userData = doc.data() as Map<String, dynamic>;
            _hariHadir = hadir;
            _totalHari = total == 0 ? 1 : total; // Hindari division by zero
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  // Helper untuk memunculkan dialog edit
  Future<void> _editField(String title, String fieldKey, String currentValue) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Edit $title', style: TextStyle(color: _primaryColor)),
        content: TextField(
          controller: controller,
          keyboardType: (fieldKey == 'no_hp' || fieldKey == 'nis' || fieldKey == 'nisn') 
              ? TextInputType.number 
              : TextInputType.text,
          inputFormatters: (fieldKey == 'no_hp' || fieldKey == 'nis' || fieldKey == 'nisn')
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(
            hintText: 'Masukkan $title baru',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _primaryColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result != currentValue) {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({fieldKey: result});
        await _fetchUserData();
      }
    }
  }

  Future<void> _updateFotoProfil() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        // Panggil ImageCropper untuk potong/zoom foto
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressQuality: 30, // Kompresi agar Base64 ringan
          maxWidth: 300,
          maxHeight: 300,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Paksa bentuk persegi
          uiSettings: [
            AndroidUiSettings(
                toolbarTitle: 'Sesuaikan Foto',
                toolbarColor: _primaryColor,
                toolbarWidgetColor: Colors.white,
                initAspectRatio: CropAspectRatioPreset.square,
                lockAspectRatio: true),
            IOSUiSettings(
              title: 'Sesuaikan Foto',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() => _isLoading = true);
          final bytes = await croppedFile.readAsBytes();
          final base64String = base64Encode(bytes);

          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'photo_base64': base64String});
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Foto profil berhasil diubah!'), backgroundColor: Colors.green),
              );
            }
            await _fetchUserData();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah foto: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    final nama = _userData['nama'] ?? 'User';
    final nis = _userData['nis'] ?? '-';
    final role = (_userData['role'] ?? 'siswa').toString().toUpperCase();
    final photoBase64 = _userData['photo_base64'];

    final username = _userData['username'] ?? '@username';
    final noHp = _userData['no_hp'] ?? '-';
    final email = _userData['email'] ?? '-';
    final tglLahir = _userData['tanggal_lahir'] ?? '-';
    final jenisKelamin = _userData['jenis_kelamin'] ?? '-';
    final alamat = _userData['alamat'] ?? '-';
    final nisn = _userData['nisn'] ?? '-';
    final sekolah = _userData['sekolah'] ?? 'SMA Negeri';

    ImageProvider profileImage;
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      profileImage = MemoryImage(base64Decode(photoBase64));
    } else {
      profileImage = const NetworkImage('https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png');
    }

    double persentaseHadir = (_hariHadir / _totalHari) * 100;
    if (_totalHari == 0) persentaseHadir = 0; // Fallback jika tidak ada data sama sekali

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          nama,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // HEADER CARD (Dark Blue)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Profile Picture
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          image: DecorationImage(
                            image: profileImage,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _updateFotoProfil,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit, size: 16, color: _primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Name
                  Text(
                    nama,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // KEHADIRAN CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'KEHADIRAN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.fact_check, size: 20, color: Colors.green.shade400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        persentaseHadir.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: _primaryColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Presensi',
                        style: TextStyle(fontSize: 12, color: _textMuted),
                      ),
                      Text(
                        '$_hariHadir HARI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: persentaseHadir / 100,
                      backgroundColor: Colors.grey.shade200,
                      color: _primaryColor,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // STATUS CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.school, size: 20, color: Colors.indigo.shade400),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // CONTACT INFO CARD
            _buildCard(
              children: [
                _buildInfoRow(
                  icon: Icons.phone_android,
                  label: noHp,
                  showVerified: true,
                  onEdit: () => _editField('Nomor HP', 'no_hp', noHp),
                ),
                const Divider(),
                _buildInfoRow(
                  icon: Icons.email_outlined,
                  label: email,
                  showVerified: true,
                  onEdit: null, 
                ),
              ],
            ),

            // PERSONAL INFO CARD
            _buildCard(
              children: [
                _buildLabelValueRow('Tanggal Lahir', tglLahir, onEdit: () => _editField('Tanggal Lahir', 'tanggal_lahir', tglLahir)),
                const SizedBox(height: 12),
                _buildLabelValueRow('Jenis Kelamin', jenisKelamin, onEdit: () => _editField('Jenis Kelamin', 'jenis_kelamin', jenisKelamin)),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 18, color: _textMuted),
                        const SizedBox(width: 8),
                        Text('Alamat', style: TextStyle(color: _textMuted, fontSize: 13)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _editField('Alamat', 'alamat', alamat),
                          child: Icon(Icons.edit, size: 16, color: _textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        alamat,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text('Pin Point', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),

            // SCHOOL INFO CARD
            _buildCard(
              children: [
                _buildLabelValueRow('Username', username, onEdit: () => _editField('Username', 'username', username)),
                const SizedBox(height: 12),
                _buildLabelValueRow('NISN', nisn, onEdit: () => _editField('NISN', 'nisn', nisn)),
                const SizedBox(height: 12),
                _buildLabelValueRow('NIS', nis, onEdit: () => _editField('NIS', 'nis', nis)),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _buildLabelValueRow('SEKOLAH', sekolah, onEdit: () => _editField('Sekolah', 'sekolah', sekolah), isBold: true),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    bool showVerified = false,
    VoidCallback? onEdit,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _textMuted),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        if (showVerified)
          const Icon(Icons.verified, size: 16, color: Colors.blue),
        const Spacer(),
        if (onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Icon(Icons.edit, size: 18, color: _textMuted),
          ),
      ],
    );
  }

  Widget _buildLabelValueRow(String label, String value, {VoidCallback? onEdit, bool isBold = false}) {
    return Row(
      children: [
        Icon(Icons.feed_outlined, size: 16, color: _textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isBold ? Colors.black87 : _textMuted,
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 8),
        if (onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Icon(Icons.edit, size: 16, color: _textMuted),
          ),
      ],
    );
  }
}
