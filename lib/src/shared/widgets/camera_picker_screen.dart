import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/file_storage_service.dart';

/// A full-screen in-app camera that lets the user capture a photo,
/// preview it, and either retake or confirm.
///
/// ## Usage
/// ```dart
/// final path = await CameraPickerScreen.open(context);
/// if (path != null) {
///   // path is an absolute local file path, ready for display or cloud upload
/// }
/// ```
///
/// Returns the absolute path of the saved JPEG, or `null` on cancel / error.
class CameraPickerScreen extends StatefulWidget {
  const CameraPickerScreen._();

  /// Push a full-screen camera onto [context] and await the result.
  static Future<String?> open(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraPickerScreen._(),
      ),
    );
  }

  @override
  State<CameraPickerScreen> createState() => _CameraPickerScreenState();
}

class _CameraPickerScreenState extends State<CameraPickerScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  FlashMode _flashMode = FlashMode.auto;

  bool _initialising = true;
  bool _capturing    = false;
  String? _permissionError;

  /// Non-null while showing the post-capture preview.
  String? _capturedPath;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _checkPermissionAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_cameras[_cameraIndex]);
    }
  }

  // ── Initialisation ──────────────────────────────────────────────────────────

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      setState(() {
        _permissionError = status.isPermanentlyDenied
            ? 'Camera permission is permanently denied.\n'
              'Please enable it in App Settings.'
            : 'Camera permission is required to take photos.';
        _initialising = false;
      });
      return;
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      if (!mounted) return;
      setState(() {
        _permissionError = 'No cameras found on this device.';
        _initialising = false;
      });
      return;
    }

    // Default to back camera
    _cameraIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (_cameraIndex < 0) _cameraIndex = 0;

    await _initCamera(_cameras[_cameraIndex]);
  }

  Future<void> _initCamera(CameraDescription cam) async {
    final ctrl = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await ctrl.initialize();
      await ctrl.setFlashMode(_flashMode);
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _controller  = ctrl;
        _initialising = false;
      });
    } on CameraException catch (e) {
      ctrl.dispose();
      if (!mounted) return;
      setState(() {
        _permissionError = 'Camera error: ${e.description}';
        _initialising    = false;
      });
    }
  }

  // ── Camera controls ─────────────────────────────────────────────────────────

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() => _initialising = true);
    await _controller?.dispose();
    _controller = null;
    await _initCamera(_cameras[_cameraIndex]);
  }

  Future<void> _cycleFlash() async {
    final next = switch (_flashMode) {
      FlashMode.off    => FlashMode.auto,
      FlashMode.auto   => FlashMode.always,
      FlashMode.always => FlashMode.off,
      _                => FlashMode.off,
    };
    await _controller?.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  // ── Capture ─────────────────────────────────────────────────────────────────

  Future<void> _capture() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final xfile = await ctrl.takePicture();
      final saved = await FileStorageService.instance
          .saveImage(xfile, 'camera_captures');
      if (mounted) setState(() => _capturedPath = saved);
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: ${e.description}')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _retake()   => setState(() => _capturedPath = null);
  void _usePhoto() => Navigator.of(context).pop(_capturedPath);

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialising)       return _buildLoading();
    if (_permissionError != null) return _buildError();
    if (_capturedPath != null)    return _buildPreview();
    return _buildCamera();
  }

  // ── Loading ─────────────────────────────────────────────────────────────────

  Widget _buildLoading() => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );

  // ── Error / permission denied ───────────────────────────────────────────────

  Widget _buildError() {
    final isPermanent = _permissionError!.contains('Settings');
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined,
              color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _permissionError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          if (isPermanent)
            OutlinedButton(
              style:
                  OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: openAppSettings,
              child: const Text('Open App Settings'),
            ),
          const SizedBox(height: 12),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ── Live preview ────────────────────────────────────────────────────────────

  Widget _buildCamera() {
    final ctrl   = _controller!;
    final size   = MediaQuery.of(context).size;
    final previewAspect = ctrl.value.aspectRatio;   // width / height
    final screenAspect  = size.width / size.height;
    final scale = previewAspect > screenAspect
        ? previewAspect / screenAspect
        : screenAspect / previewAspect;

    final hasFront = _cameras.any(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview — scaled to fill the screen
        Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: CameraPreview(ctrl),
        ),

        // ── Top controls ───────────────────────────────────────────────
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  // Flash
                  IconButton(
                    icon: Icon(_flashIcon, color: Colors.white),
                    tooltip: 'Toggle flash',
                    onPressed: _cycleFlash,
                  ),
                  // Flip (only when front camera present)
                  if (hasFront)
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_outlined,
                          color: Colors.white),
                      tooltip: 'Flip camera',
                      onPressed: _flipCamera,
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── Bottom — shutter button ─────────────────────────────────────
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 44),
              child: _ShutterButton(
                capturing: _capturing,
                onCapture: _capture,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData get _flashIcon => switch (_flashMode) {
    FlashMode.off    => Icons.flash_off,
    FlashMode.auto   => Icons.flash_auto,
    FlashMode.always => Icons.flash_on,
    _                => Icons.flash_auto,
  };

  // ── Post-capture preview ────────────────────────────────────────────────────

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed captured image
        Image.file(
          File(_capturedPath!),
          fit: BoxFit.cover,
        ),

        // Gradient at bottom for button legibility
        const Align(
          alignment: Alignment.bottomCenter,
          child: _BottomGradient(),
        ),

        // Close (discard)
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Discard',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),

        // Retake / Use Photo
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _retake,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Use Photo'),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _usePhoto,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shutter button ─────────────────────────────────────────────────────────────

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.capturing,
    required this.onCapture,
  });
  final bool capturing;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: capturing ? null : onCapture,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3.5),
          color: capturing ? Colors.white30 : Colors.transparent,
        ),
        padding: const EdgeInsets.all(6),
        child: capturing
            ? const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                ),
              )
            : Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

// ── Bottom gradient overlay ────────────────────────────────────────────────────

class _BottomGradient extends StatelessWidget {
  const _BottomGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
    );
  }
}
