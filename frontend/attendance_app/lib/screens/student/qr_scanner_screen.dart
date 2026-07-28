import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/attendance_service.dart';
import '../../services/session_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final SessionService _sessionService = SessionService();
  
  // Scanner for Online mode (forced flash via returnImage maybe not needed, but we force torch on)
  late final MobileScannerController _scannerController;
  
  // Camera for Offline mode capture
  CameraController? _cameraController;
  
  bool isProcessing = false;
  bool hasScanned = false;
  String? scannedData;
  bool isOfflineMode = false;
  bool _cameraPermissionGranted = false;
  
  bool _isCameraInitializing = false;
  bool _isSwitchingMode = false;

  // Zoom control variables for both modes
  double _baseZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  
  // Camera package zoom bounds
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  @override
  void initState() {
    super.initState();
    // Initialize MobileScannerController with torch enabled
    _scannerController = MobileScannerController(torchEnabled: true);
    _checkCameraPermission();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _cameraPermissionGranted = status.isGranted;
      });
      if (!status.isGranted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
            'This app needs camera access to scan QR codes for attendance. Please grant camera permission in app settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeOfflineCamera() async {
    if (_isCameraInitializing) return;
    
    setState(() {
      _isCameraInitializing = true;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Using max resolution for native OS app clarity!
      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.max,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      // Get zoom limits
      _minAvailableZoom = await _cameraController!.getMinZoomLevel();
      _maxAvailableZoom = await _cameraController!.getMaxZoomLevel();
      _currentZoomLevel = _minAvailableZoom;
      
    } catch (e) {
      debugPrint('Error initializing camera for offline capture: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
        
        // Force flash ON after a tiny delay to ensure hardware readiness after initialization
        if (_cameraController != null && _cameraController!.value.isInitialized) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && isOfflineMode) {
              _cameraController!.setFlashMode(FlashMode.torch).catchError((e) {
                debugPrint('Flash mode toggle failed: $e');
              });
            }
          });
        }
      }
    }
  }

  void _toggleMode(bool val) async {
    if (val == isOfflineMode || _isSwitchingMode) return;
    
    setState(() {
      _isSwitchingMode = true;
      isOfflineMode = val;
    });

    try {
      if (isOfflineMode) {
        // Switch to Offline Mode
        await _scannerController.stop();
        await _initializeOfflineCamera();
      } else {
        // Switch to Online Mode
        if (_cameraController != null) {
          await _cameraController!.dispose();
          _cameraController = null;
        }
        await _scannerController.start();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingMode = false;
        });
      }
    }
  }
  
  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoomLevel = _currentZoomLevel;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) async {
    if (isOfflineMode && _cameraController != null) {
      // Handle camera package zoom
      _currentZoomLevel = (_baseZoomLevel * details.scale)
          .clamp(_minAvailableZoom, _maxAvailableZoom);
      await _cameraController!.setZoomLevel(_currentZoomLevel);
    } else if (!isOfflineMode) {
      // Handle mobile_scanner zoom (0.0 to 1.0 ratio typically in newer versions)
      // We estimate standard clamp logic here
      _currentZoomLevel = (_baseZoomLevel * details.scale).clamp(1.0, 5.0);
      // scale for mobile_scanner is usually expected to be between 0.0 and 1.0 in some versions,
      // but if we pass it directly we can convert it to a ratio.
      final zoomRatio = ((_currentZoomLevel - 1.0) / 4.0).clamp(0.0, 1.0);
      _scannerController.setZoomScale(zoomRatio);
    }
  }

  Future<void> _handleQRCode(String qrData) async {
    if (isProcessing || hasScanned || isOfflineMode) return;

    setState(() {
      isProcessing = true;
      scannedData = qrData;
    });

    try {
      final dynamic decoded = jsonDecode(qrData);
      
      if (decoded is! Map<String, dynamic>) {
        _showError('Invalid QR code format. Not an attendance code.');
        setState(() => isProcessing = false);
        return;
      }
      
      final data = decoded;
      final sessionId = data['session_id'];

      if (sessionId == null) {
        _showError('Invalid QR code');
        setState(() => isProcessing = false);
        return;
      }

      final result = await _attendanceService.markAttendance(sessionId);

      if (mounted) {
        if (result['success']) {
          setState(() => hasScanned = true);
          _showSuccessDialog(result['message']);
        } else {
          _showError(result['message']);
          setState(() => isProcessing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Invalid QR code format: $e');
        setState(() => isProcessing = false);
      }
    }
  }

  Future<void> _handleOfflineCapture() async {
    if (isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) return;
    setState(() => isProcessing = true);

    try {
      // Ensure flash fires on capture
      await _cameraController!.setFlashMode(FlashMode.torch);
      final XFile picture = await _cameraController!.takePicture();
      final String imagePath = picture.path;

      final sessions = await _sessionService.getStudentActiveSessions();
      final offlineSessions =
          sessions.where((s) => s['class_type'] == 'offline').toList();

      if (offlineSessions.isEmpty) {
        _showError('No active offline sessions found.');
        setState(() => isProcessing = false);
        return;
      }

      final String sessionId = offlineSessions.first['session_id'].toString();

      final result = await _attendanceService.verifyImage(
        sessionId: sessionId,
        imagePath: imagePath,
        focalDistance: 2.0,
      );

      if (mounted) {
        if (result['success']) {
          setState(() => hasScanned = true);
          _showSuccessDialog(
              result['message'] ?? 'Attendance marked successfully');
        } else {
          _showError(result['message'] ?? 'Verification failed');
          setState(() => isProcessing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error capturing or verifying image: $e');
        setState(() => isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.green.shade100, shape: BoxShape.circle),
              child:
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 60),
            ),
            const SizedBox(height: 16),
            const Text('Success!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937))),
          ],
        ),
        content: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16)),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007C91),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(isOfflineMode ? 'Capture Pattern' : 'Scan QR Code'),
        backgroundColor: const Color(0xFF007C91),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Row(
            children: [
              Text(
                isOfflineMode ? 'Offline' : 'Online',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Switch(
                value: isOfflineMode,
                activeThumbColor: Colors.orange,
                activeTrackColor: Colors.orange.withValues(alpha: 0.5),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.white30,
                onChanged: _toggleMode,
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Camera Background
          if (_cameraPermissionGranted)
            Positioned.fill(
              child: GestureDetector(
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                child: isOfflineMode
                    ? (_cameraController != null && _cameraController!.value.isInitialized
                        ? CameraPreview(_cameraController!)
                        : const Center(child: CircularProgressIndicator()))
                    : MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          if (isOfflineMode) return;
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null) {
                              _handleQRCode(barcode.rawValue!);
                              break;
                            }
                          }
                        },
                      ),
              ),
            )
          else
            // No permission
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white54, size: 80),
                    SizedBox(height: 16),
                    Text(
                      'Camera permission required',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Scanning Frame Overlay
          Center(
            child: IgnorePointer(
              child: Container(
                width: isMobile ? 250 : 300,
                height: isMobile ? 250 : 300,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasScanned
                        ? Colors.green
                        : (isProcessing ? Colors.orange : Colors.white),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: isProcessing
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.orange.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Processing...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Corner Markers
          if (!isProcessing && !hasScanned) ...[
            _buildCornerMarker(Alignment.topLeft),
            _buildCornerMarker(Alignment.topRight),
            _buildCornerMarker(Alignment.bottomLeft),
            _buildCornerMarker(Alignment.bottomRight),
          ],

          // Instructions or Capture Button
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: isOfflineMode
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Capture Board Pattern',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Point camera at the board pattern and tap Capture',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isProcessing ? null : _handleOfflineCapture,
                            icon: const Icon(Icons.camera_alt),
                            label: Text(isProcessing
                                ? 'Processing...'
                                : 'Capture Pattern'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade400,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasScanned
                              ? Icons.check_circle
                              : (isProcessing
                                  ? Icons.hourglass_empty
                                  : Icons.qr_code_scanner),
                          color: hasScanned
                              ? Colors.green
                              : (isProcessing ? Colors.orange : Colors.white),
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasScanned
                              ? 'Attendance Marked Successfully!'
                              : (isProcessing
                                  ? 'Verifying...'
                                  : 'Position QR code within the frame'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerMarker(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(60),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: alignment == Alignment.topLeft ||
                      alignment == Alignment.topRight
                  ? const BorderSide(color: Colors.green, width: 4)
                  : BorderSide.none,
              bottom: alignment == Alignment.bottomLeft ||
                      alignment == Alignment.bottomRight
                  ? const BorderSide(color: Colors.green, width: 4)
                  : BorderSide.none,
              left: alignment == Alignment.topLeft ||
                      alignment == Alignment.bottomLeft
                  ? const BorderSide(color: Colors.green, width: 4)
                  : BorderSide.none,
              right: alignment == Alignment.topRight ||
                      alignment == Alignment.bottomRight
                  ? const BorderSide(color: Colors.green, width: 4)
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}