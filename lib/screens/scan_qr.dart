import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ScanQrScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ScanQrScreen({super.key, this.onBack});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final Color _primaryColor = const Color(0xFF11145A);
  final Color _textMuted = const Color(0xFF6C757D);
  final Color _bgColor = const Color(0xFFF5F6FA);

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 1; // Default to front camera
  bool _isCameraInitialized = false;

  XFile? _capturedImage;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      enableLandmarks: false,
      enableTracking: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isProcessingImage = false;
  bool _isFaceDetected = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndInitCamera();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locationController.text = 'Mencari lokasi otomatis...';
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() { _locationController.text = 'GPS dinonaktifkan'; });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() { _locationController.text = 'Izin lokasi ditolak'; });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() { _locationController.text = 'Izin lokasi ditolak permanen'; });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Susun alamat sederhana
        String address = '';
        if (place.street != null && place.street!.isNotEmpty) address += '${place.street}, ';
        if (place.subLocality != null && place.subLocality!.isNotEmpty) address += '${place.subLocality}, ';
        if (place.locality != null && place.locality!.isNotEmpty) address += '${place.locality}';
        
        setState(() {
          _locationController.text = address.isNotEmpty ? address : '${position.latitude}, ${position.longitude}';
        });
      } else {
        setState(() {
          _locationController.text = '${position.latitude}, ${position.longitude}';
        });
      }
    } catch (e) {
      setState(() { _locationController.text = 'Gagal melacak lokasi: $e'; });
    }
  }

  Future<void> _requestPermissionAndInitCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initCamera();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin kamera ditolak')),
        );
      }
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _selectedCameraIndex = _cameras!.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }
      _startCamera(_cameras![_selectedCameraIndex]);
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await _cameraController!.initialize();
      _isCameraInitialized = true;
      if (mounted) setState(() {});

      _cameraController!.startImageStream((CameraImage image) {
        if (!_isProcessingImage && _capturedImage == null) {
          _processImage(image);
        }
      });
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _processImage(CameraImage image) async {
    _isProcessingImage = true;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final camera = _cameras![_selectedCameraIndex];
    final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    final InputImageMetadata metadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty && !_isFaceDetected) {
        if (mounted) {
          setState(() {
            _isFaceDetected = true;
          });
        }
      } else if (faces.isEmpty && _isFaceDetected) {
        if (mounted) {
          setState(() {
            _isFaceDetected = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Face detection error: $e");
    }

    _isProcessingImage = false;
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_cameraController!.value.isTakingPicture) return;

    try {
      final XFile image = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = image;
      });
    } catch (e) {
      debugPrint("Take picture error: $e");
    }
  }

  void _retakePicture() {
    setState(() {
      _capturedImage = null;
    });
  }

  void _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    await _startCamera(_cameras![_selectedCameraIndex]);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Menu Absensi',
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Absen Foto Selfie ya!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // LABEL AMBIL FOTO
              const Text(
                'Ambil Foto',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // CAMERA / CAPTURE VIEW
              GestureDetector(
                onTap: _capturedImage == null ? _takePicture : null,
                child: Container(
                  width: double.infinity,
                  height: 260,
                  decoration: BoxDecoration(
                    color: _bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isFaceDetected && _capturedImage == null 
                          ? Colors.green 
                          : _primaryColor.withValues(alpha: 0.3),
                      width: _isFaceDetected && _capturedImage == null ? 3 : 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _capturedImage != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: _retakePicture,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : (_isCameraInitialized && _cameraController != null)
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _cameraController!.value.previewSize?.height ?? 1,
                                      height: _cameraController!.value.previewSize?.width ?? 1,
                                      child: CameraPreview(_cameraController!),
                                    ),
                                  ),
                                  Center(
                                    child: Icon(
                                      Icons.camera_alt,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      size: 48,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: _switchCamera,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.flip_camera_android, color: Colors.white, size: 24),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: CircularProgressIndicator(color: _primaryColor),
                              ),
                  ),
                ),
              ),
              
              if (_capturedImage == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _isFaceDetected ? 'Wajah terdeteksi. Tap kotak untuk memotret!' : 'Arahkan wajah ke kamera...',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isFaceDetected ? Colors.green : _textMuted,
                      fontWeight: _isFaceDetected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // FORM NAMA
              const Text(
                'Masukan Nama Anda',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Arya',
                  hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // FORM LOKASI
              const Text(
                'Lokasi Anda',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Sistem sedang membaca lokasi...',
                  hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // BUTTON ABSEN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Tindakan submit presensi
                    if (_capturedImage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Silakan ambil foto terlebih dahulu!')),
                      );
                      return;
                    }

                    // Capture context-dependent objects SEBELUM async gap
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);

                    // Tampilkan loading dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        // 1. Ambil data presensi user untuk mengecek hari ini
                        final presensiSnapshot = await FirebaseFirestore.instance
                            .collection('presensi')
                            .where('uid', isEqualTo: user.uid)
                            .get();

                        int countHariIni = 0;
                        final now = DateTime.now();

                        for (var doc in presensiSnapshot.docs) {
                          final data = doc.data();
                          final waktu = (data['waktu_scan'] as Timestamp?)?.toDate();
                          if (waktu != null && 
                              waktu.year == now.year && 
                              waktu.month == now.month && 
                              waktu.day == now.day) {
                            countHariIni++;
                          }
                        }

                        // 2. Tolak jika sudah 2 kali
                        if (countHariIni >= 2) {
                          if (mounted) navigator.pop(); // Tutup loading dialog
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Anda sudah mencapai maksimal presensi hari ini (Masuk & Pulang).'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                          return;
                        }

                        // 3. Tentukan jenis presensi berdasarkan jumlah presensi hari ini
                        final String jenisPresensi = countHariIni == 0 ? 'Presensi Masuk' : 'Presensi Pulang';

                        // 4. Logika Keterlambatan (Batas Masuk 07:15)
                        final batasAbsen = DateTime(now.year, now.month, now.day, 7, 15);
                        String statusAbsen = 'Hadir';
                        int menitTerlambat = 0;

                        if (jenisPresensi == 'Presensi Masuk') {
                          if (now.isAfter(batasAbsen)) {
                            statusAbsen = 'Terlambat';
                            menitTerlambat = now.difference(batasAbsen).inMinutes;
                          }
                        }

                        // 5. Simpan ke Firestore
                        await FirebaseFirestore.instance.collection('presensi').add({
                          'uid': user.uid,
                          'waktu_scan': FieldValue.serverTimestamp(),
                          'status': statusAbsen,
                          'presensi_masuk': jenisPresensi, // "Presensi Masuk" atau "Presensi Pulang"
                          'lokasi': _locationController.text.isNotEmpty 
                              ? _locationController.text 
                              : 'Lokasi tidak diketahui',
                          'keterlambatan_menit': menitTerlambat, 
                          'nama_siswa': _nameController.text,
                        });
                      }

                      // Tutup loading dialog
                      if (mounted) navigator.pop();

                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Presensi berhasil dikirim!')),
                        );
                        Future.delayed(const Duration(seconds: 1), () {
                          if (mounted) {
                            if (widget.onBack != null) {
                              widget.onBack!(); // Balik ke Home Tab
                            } else {
                              navigator.pop(); // Fallback
                            }
                          }
                        });
                      }
                    } catch (e) {
                      // Tutup loading dialog
                      if (mounted) navigator.pop();
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Gagal mengirim presensi: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Absen Sekarang',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}