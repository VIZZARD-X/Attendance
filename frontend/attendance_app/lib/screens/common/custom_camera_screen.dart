import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CustomCameraScreen extends StatefulWidget {
  final String title;
  final String helperText;
  
  const CustomCameraScreen({
    super.key,
    required this.title,
    this.helperText = 'Ensure the whiteboard and pattern are clearly visible.',
  });

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  bool _isTakingPicture = false;
  
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No cameras available on this device');
        return;
      }

      // Use the first back camera
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      // Force Flash ON for better structural capture and flash reflection test
      await _controller!.setFlashMode(FlashMode.always);
      
      // Auto focus
      await _controller!.setFocusMode(FocusMode.auto);
      
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        _showError('Camera initialization failed: $e');
        setState(() => _isInitializing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }



  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isTakingPicture) {
      return;
    }

    setState(() => _isTakingPicture = true);

    try {
      await _controller!.setFlashMode(FlashMode.always);
      final XFile rawImage = await _controller!.takePicture();
      final bytes = await rawImage.readAsBytes();
      
      final tempDir = await getTemporaryDirectory();
      
      // Run heavy image processing in a background isolate
      // This prevents the camera preview from freezing and throwing BLASTBufferQueue errors
      String finalImagePath = await compute(_processImageInBackground, {
        'bytes': bytes,
        'width': 0, // Not strictly needed since decodeImage reads it
        'height': 0,
        'tempPath': tempDir.path,
      });
      
      if (finalImagePath.isEmpty) {
        finalImagePath = rawImage.path; // fallback
      }
      
      if (mounted) {
        Navigator.pop(context, finalImagePath);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to capture image: $e');
        setState(() => _isTakingPicture = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Camera not available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview with Pinch-to-Zoom
          GestureDetector(
            onScaleStart: (details) {
              _baseZoomLevel = _currentZoomLevel;
            },
            onScaleUpdate: (details) async {
              if (_controller == null || !_controller!.value.isInitialized) return;
              
              double targetZoom = _baseZoomLevel * details.scale;
              targetZoom = targetZoom.clamp(_minZoomLevel, _maxZoomLevel);
              
              if (targetZoom != _currentZoomLevel) {
                setState(() => _currentZoomLevel = targetZoom);
                await _controller!.setZoomLevel(targetZoom);
              }
            },
            child: CameraPreview(_controller!),
          ),
          
          // Dark Overlay with Cutout
          IgnorePointer(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black54, BlendMode.srcOut),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.75,
                        height: MediaQuery.of(context).size.width * 0.75,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Targeting Box Border
          IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                height: MediaQuery.of(context).size.width * 0.75,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Icon(Icons.add, color: Colors.greenAccent, size: 40),
                ),
              ),
            ),
          ),

          // Overlay Instructions
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.helperText,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                
                // Capture Button Area
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.black54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _takePicture,
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Center(
                            child: Container(
                              height: 65,
                              width: 65,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: _isTakingPicture 
                                ? const CircularProgressIndicator(color: Colors.black)
                                : null,
                            ),
                          ),
                        ),
                      ),
                    ],
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

// Top-level function for background isolate
Future<String> _processImageInBackground(Map<String, dynamic> params) async {
  final bytes = params['bytes'] as Uint8List;
  final width = params['width'] as int;
  final height = params['height'] as int;
  final tempDirPath = params['tempPath'] as String;

  img.Image? decodedImage = img.decodeImage(bytes);
  if (decodedImage != null) {
    decodedImage = img.bakeOrientation(decodedImage);
    
    int size = math.min(decodedImage.width, decodedImage.height);
    int cropSize = (size * 0.75).toInt();
    int x = (decodedImage.width - cropSize) ~/ 2;
    int y = (decodedImage.height - cropSize) ~/ 2;
    
    img.Image cropped = img.copyCrop(decodedImage, x: x, y: y, width: cropSize, height: cropSize);
    final croppedBytes = img.encodeJpg(cropped, quality: 95);
    
    final finalImagePath = '$tempDirPath/cropped_board_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(finalImagePath).writeAsBytes(croppedBytes);
    return finalImagePath;
  }
  return "";
}
