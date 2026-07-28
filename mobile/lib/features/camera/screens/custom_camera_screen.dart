import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ijwi_mobile/core/image_helper.dart';
import '../../../core/theme.dart';

class CustomCameraScreen extends StatefulWidget {
  final bool initialIsVideo;
  const CustomCameraScreen({Key? key, this.initialIsVideo = false}) : super(key: key);

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  int _selectedCameraIndex = 0;
  Timer? _timer;
  int _secondsRecorded = 0;
  FlashMode _flashMode = FlashMode.auto;
  bool _isVideoMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isVideoMode = widget.initialIsVideo;
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _setCamera(_selectedCameraIndex);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _setCamera(int index) async {
    if (_cameras.isEmpty) return;
    
    final previousController = _controller;
    
    final CameraController cameraController = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.jpeg,
    );

    await previousController?.dispose();

    if (mounted) {
      setState(() {
        _controller = cameraController;
      });
    }

    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _selectedCameraIndex = index;
        });
      }
    } on CameraException catch (e) {
      debugPrint('Camera Exception: ${e.code}, ${e.description}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setCamera(_selectedCameraIndex);
    }
  }
  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isTakingPicture) {
      return;
    }
    try {
      final XFile picture = await _controller!.takePicture();
      final fixedPath = await ImageHelper.compressAndFixRotation(picture.path);
      if (mounted) {
        Navigator.pop(context, fixedPath);
      }
    } on CameraException catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _controller!.value.isRecordingVideo) {
      return;
    }
    try {
      await _controller!.startVideoRecording();
      _secondsRecorded = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() => _secondsRecorded++);
      });
      setState(() {
        _isRecording = true;
      });
    } on CameraException catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return;
    }
    try {
      _timer?.cancel();
      final XFile video = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
      if (mounted) {
        Navigator.pop(context, video.path);
      }
    } on CameraException catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  void _switchCamera() {
    if (_cameras.length > 1) {
      final newIndex = _selectedCameraIndex == 0 ? 1 : 0;
      _setCamera(newIndex);
    }
  }

  void _toggleFlash() {
    if (_controller == null) return;
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      default:
        nextMode = FlashMode.auto;
    }
    _controller!.setFlashMode(nextMode);
    setState(() => _flashMode = nextMode);
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final gold = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          SizedBox(
            width: size.width,
            height: size.height,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize?.height ?? 1,
                height: _controller!.value.previewSize?.width ?? 1,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          
          // Top Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close Button
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                // Timer
                if (_isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_secondsRecorded),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(width: 28), // placeholder

                // Flash Toggle
                IconButton(
                  icon: Icon(
                    _flashMode == FlashMode.auto
                        ? LucideIcons.zap
                        : _flashMode == FlashMode.always
                            ? LucideIcons.zap
                            : LucideIcons.zap_off,
                    color: _flashMode == FlashMode.always ? gold : Colors.white,
                    size: 28,
                  ),
                  onPressed: _toggleFlash,
                ),
              ],
            ),
          ),

          // Controls
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Switch Camera
                    IconButton(
                      icon: const Icon(LucideIcons.switch_camera, color: Colors.white, size: 28),
                      onPressed: _switchCamera,
                    ),

                    // Capture Button
                    GestureDetector(
                      onTap: () {
                        if (_isRecording) {
                          _stopRecording();
                        } else if (_isVideoMode) {
                          _startRecording();
                        } else {
                          _takePicture();
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: (_isRecording || _isVideoMode) ? Colors.redAccent : gold, width: 4),
                          color: _isRecording ? Colors.redAccent.withValues(alpha: 0.2) : Colors.transparent,
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isRecording ? 36 : 60,
                            height: _isRecording ? 36 : 60,
                            decoration: BoxDecoration(
                              shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
                              borderRadius: _isRecording ? BorderRadius.circular(8) : null,
                              color: (_isRecording || _isVideoMode) ? Colors.redAccent : gold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 48), // Placeholder for symmetry
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Pill Switcher
                if (!_isRecording)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isVideoMode = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isVideoMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              'Photo',
                              style: TextStyle(
                                color: !_isVideoMode ? Colors.black : Colors.white70,
                                fontWeight: !_isVideoMode ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isVideoMode = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: _isVideoMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              'Video',
                              style: TextStyle(
                                color: _isVideoMode ? Colors.black : Colors.white70,
                                fontWeight: _isVideoMode ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 14,
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
