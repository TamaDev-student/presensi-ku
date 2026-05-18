import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'homepage.dart';

class RegisterSiswaScreen extends StatefulWidget {
  const RegisterSiswaScreen({super.key});

  @override
  State<RegisterSiswaScreen> createState() => _RegisterSiswaScreenState();
}

class _RegisterSiswaScreenState extends State<RegisterSiswaScreen> {
  final _formKey = GlobalKey<FormState>();
  final Color _primaryColor = const Color(0xFF11145A);

  final TextEditingController _nisController = TextEditingController();
  final TextEditingController _kelasController = TextEditingController();
  final TextEditingController _noHpController = TextEditingController();
  String? _jenisKelamin;
  final TextEditingController _tglLahirController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _kecamatanController = TextEditingController();
  final TextEditingController _kabKotaController = TextEditingController();
  final TextEditingController _provinsiController = TextEditingController();

  bool _isLoading = false;

  Future<void> _pilihTanggalLahir() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 15, now.month, now.day),
      firstDate: DateTime(1990),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _tglLahirController.text = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      });
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'nis': _nisController.text.trim(),
          'kelas': _kelasController.text.trim(),
          'no_hp': _noHpController.text.trim(),
          'jenis_kelamin': _jenisKelamin ?? '',
          'tanggal_lahir': _tglLahirController.text.trim(),
          'alamat': '${_alamatController.text.trim()}, Kec. ${_kecamatanController.text.trim()}, ${_kabKotaController.text.trim()}, Prov. ${_provinsiController.text.trim()}',
          // Tandai bahwa profil sudah lengkap
          'is_profile_complete': true, 
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan data: $e'), backgroundColor: Colors.red),
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
  void dispose() {
    _nisController.dispose();
    _kelasController.dispose();
    _noHpController.dispose();
    _tglLahirController.dispose();
    _alamatController.dispose();
    _kecamatanController.dispose();
    _kabKotaController.dispose();
    _provinsiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Lengkapi Profil', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selamat Datang!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sebagai siswa baru, silakan lengkapi data diri Anda terlebih dahulu sebelum menggunakan aplikasi.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 32),

                _buildTextField('NIS', _nisController, Icons.badge, isNumber: true),
                const SizedBox(height: 16),
                _buildTextField('Kelas (Contoh: X IPS 1)', _kelasController, Icons.class_),
                const SizedBox(height: 16),
                _buildTextField('Nomor HP', _noHpController, Icons.phone, isNumber: true),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _jenisKelamin,
                  decoration: InputDecoration(
                    labelText: 'Jenis Kelamin',
                    prefixIcon: Icon(Icons.person, color: _primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                    DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _jenisKelamin = value;
                    });
                  },
                  validator: (value) => value == null ? 'Pilih jenis kelamin' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField('Tanggal Lahir', _tglLahirController, Icons.calendar_today, readOnly: true, onTap: _pilihTanggalLahir),
                const SizedBox(height: 16),
                _buildTextField('Detail Alamat (Jalan, RT/RW)', _alamatController, Icons.location_on),
                const SizedBox(height: 16),
                _buildTextField('Kecamatan', _kecamatanController, Icons.map),
                const SizedBox(height: 16),
                _buildTextField('Kabupaten/Kota', _kabKotaController, Icons.location_city),
                const SizedBox(height: 16),
                _buildTextField('Provinsi', _provinsiController, Icons.map_outlined),
                
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Simpan & Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumber = false, bool readOnly = false, VoidCallback? onTap}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      readOnly: readOnly,
      onTap: onTap,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label tidak boleh kosong';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
      ),
    );
  }
}
