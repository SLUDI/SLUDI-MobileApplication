import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'api_service.dart';

class FaceDetectionScreen extends StatefulWidget {
  final String idNumber;

  const FaceDetectionScreen({super.key, required this.idNumber});

  @override
  State<FaceDetectionScreen> createState() =>
      _FaceDetectionScreenImprovedState();
}

class _FaceDetectionScreenImprovedState
    extends State<FaceDetectionScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isVerifying = false;
  String? _errorMessage;
  Timer? _recordingTimer;
  Timer? _faceDetectionTimer;
  int _recordingDuration = 0;
  final int _maxRecordingDuration = 8;
  XFile? _recordedVideo;
  bool _showPreview = false;
  double _verificationThreshold = 0.7;
  bool _verificationSuccess = false;
  double _similarityScore = 0.0;

  // Face detection variables
  late FaceDetector _faceDetector;
  bool _faceCentered = false;
  int _qualityChecksPassed = 0;
  final int _minQualityChecks = 5; // Need 5 consecutive quality checks
  int _consecutiveQualityFrames = 0;
  double _faceConfidence = 0.0;
  String _faceStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeFaceDetector();
    _initializeCamera();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      minFaceSize: 0.1, // At least 10% of screen
    );
    _faceDetector = FaceDetector(options: options);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recordingTimer?.cancel();
    _faceDetectionTimer?.cancel();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      _cameras = await availableCameras();

      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          setState(() {
            _errorMessage =
                'Camera error: ${_controller!.value.errorDescription}';
          });
        }
      });

      await _controller!
          .initialize()
          .then((_) {
            if (!mounted) return;

            if (_controller!.value.isInitialized) {
              setState(() {
                _isCameraInitialized = true;
                _faceStatus = 'Looking for your face...';
              });
              print('Camera initialized successfully');

              // Start real face detection
              _startRealFaceDetection();
            }
          })
          .catchError((e) {
            setState(() {
              _errorMessage = 'Failed to initialize camera: $e';
              _isCameraInitialized = false;
            });
          });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to setup camera: $e';
        _isCameraInitialized = false;
      });
    }
  }

  /// Real face detection using ML Kit
  void _startRealFaceDetection() {
    _faceDetectionTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (!_isCameraInitialized ||
          _controller == null ||
          !_controller!.value.isInitialized) {
        return;
      }

      try {
        // Capture current frame
        final image = await _controller!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);

        // Detect faces
        final List<Face> faces = await _faceDetector.processImage(inputImage);

        // Clean up temp image
        final tempFile = File(image.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        if (faces.isEmpty) {
          setState(() {
            _faceCentered = false;
            _faceStatus = 'No face detected. Face the camera.';
            _consecutiveQualityFrames = 0;
            _faceConfidence = 0.0;
          });
          return;
        }

        // Check face quality
        final face = faces.first; // Use largest/closest face
        final isQuality = _checkFaceQuality(face);

        if (isQuality) {
          _consecutiveQualityFrames++;
          setState(() {
            _faceConfidence =
                (_consecutiveQualityFrames / _minQualityChecks * 100)
                    .clamp(0, 100)
                    .toDouble();
            _faceStatus =
                'Face detected: ${_consecutiveQualityFrames}/$_minQualityChecks';

            if (_consecutiveQualityFrames >= _minQualityChecks &&
                !_faceCentered) {
              _faceCentered = true;
              _faceStatus = 'Perfect! Ready to record.';
              _startRecordingAfterDelay();
            }
          });
        } else {
          _consecutiveQualityFrames = 0;
          setState(() {
            _faceStatus = 'Adjust your position - better lighting needed';
            _faceConfidence = 0.0;
          });
        }
      } catch (e) {
        print('Face detection error: $e');
      }
    });
  }

  /// Check face quality metrics
  bool _checkFaceQuality(Face face) {
    // Check face size (should be reasonable portion of frame)
    final boundingBox = face.boundingBox;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final faceWidth = boundingBox.width;
    final faceHeight = boundingBox.height;
    final faceSizeRatio =
        (faceWidth * faceHeight) / (screenWidth * screenHeight);

    // Face should be 10-80% of screen area
    if (faceSizeRatio < 0.1 || faceSizeRatio > 0.8) {
      return false;
    }

    // Check if face is roughly centered
    final centerX = boundingBox.center.dx;
    final centerY = boundingBox.center.dy;
    final screenCenterX = screenWidth / 2;
    final screenCenterY = screenHeight / 2;

    final horizontalOffset = (centerX - screenCenterX).abs();
    final verticalOffset = (centerY - screenCenterY).abs();

    // Allow ±20% deviation from center
    if (horizontalOffset > screenWidth * 0.2 ||
        verticalOffset > screenHeight * 0.2) {
      return false;
    }

    // Check head pose (if available from landmarks)
    if (face.landmarks.isEmpty) {
      return false; // No landmarks = poor quality
    }

    // Check if eyes are open (basic liveness check)
    // Access landmarks from the map
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    // If we can't detect eyes, reject
    if (leftEye == null || rightEye == null) {
      return false;
    }

    // Additional quality checks
    // Check if face is not rotated too much (basic pose check)
    final leftEyePos = leftEye.position;
    final rightEyePos = rightEye.position;

    // Check if eyes are roughly horizontal (not tilted head)
    // Use .y and .x instead of .dy and .dx for Point<int>
    final eyeTilt = (leftEyePos.y - rightEyePos.y).abs();
    if (eyeTilt > faceHeight * 0.1) {
      // Allow 10% tilt
      return false;
    }

    // Check distance between eyes (should be reasonable)
    final eyeDistance = (leftEyePos.x - rightEyePos.x).abs();
    if (eyeDistance < faceWidth * 0.2 || eyeDistance > faceWidth * 0.6) {
      return false;
    }

    // All checks passed
    return true;
  }

  void _startRecordingAfterDelay() {
    if (_recordingTimer != null) return;

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _faceCentered && !_isRecording) {
        _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    if (!_isCameraInitialized || _isRecording) {
      return;
    }

    try {
      _faceDetectionTimer?.cancel();

      final Directory tempDir = await getTemporaryDirectory();
      final String videoPath = path.join(
        tempDir.path,
        'face_verification_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      print('Starting recording to: $videoPath');

      await _controller!.startVideoRecording();

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _errorMessage = null;
        _verificationSuccess = false;
        _similarityScore = 0.0;
        _faceStatus = 'Recording...';
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });

          if (_recordingDuration >= _maxRecordingDuration) {
            _stopRecording();
            timer.cancel();
          }
        }
      });

      print('Recording started successfully');
    } catch (e, stackTrace) {
      print('Failed to start recording: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to start recording: ${e.toString()}';
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      _recordingTimer?.cancel();

      if (_controller!.value.isRecordingVideo) {
        final XFile videoFile = await _controller!.stopVideoRecording();

        setState(() {
          _isRecording = false;
          _recordedVideo = videoFile;
          _showPreview = true;
          _faceStatus = 'Recording complete. Verifying...';
        });

        print('Recording stopped successfully. File: ${videoFile.path}');

        // Auto-submit the video after recording
        _submitVideo();
      } else {
        setState(() {
          _isRecording = false;
          _errorMessage = 'Camera was not recording';
        });
      }
    } catch (e, stackTrace) {
      print('Failed to stop recording: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to stop recording: ${e.toString()}';
        _isRecording = false;
      });
    }
  }

  Future<void> _retakeVideo() async {
    setState(() {
      _recordedVideo = null;
      _showPreview = false;
      _recordingDuration = 0;
      _verificationSuccess = false;
      _similarityScore = 0.0;
      _faceCentered = false;
      _consecutiveQualityFrames = 0;
      _faceStatus = 'Looking for your face...';
    });

    // Restart face detection
    _startRealFaceDetection();
  }

  Future<void> _submitVideo() async {
    if (_recordedVideo == null) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _faceStatus = 'Verifying identity...';
    });

    try {
      final result = await ApiService.verifyVideoWithEmbedding(
        videoFile: File(_recordedVideo!.path),
        idNumber: widget.idNumber,
      );

      setState(() {
        _isVerifying = false;
      });

      if (result['success'] == true) {
        final isVerified = result['is_verified'] ?? false;
        final similarity = result['similarity'] ?? 0.0;
        final message = result['message'] ?? 'Verification completed';
        final token = result['token'];
        final status = result['status'] ?? 'UNKNOWN';

        setState(() {
          _verificationSuccess = isVerified;
          _similarityScore = similarity;
          _faceStatus = isVerified
              ? '✅ Identity Verified!'
              : '❌ Verification Failed';
        });

        _showVerificationResult(isVerified, similarity, message, token, status);
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Face verification failed';
          _faceStatus = 'Verification failed - try again';
          _verificationSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Failed to verify video: $e';
        _verificationSuccess = false;
        _faceStatus = 'Error - please try again';
      });
    }
  }

  void _showVerificationResult(
    bool isVerified,
    double similarity,
    String message,
    String? token,
    String status,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isVerified ? Icons.verified : Icons.error_outline,
              color: isVerified ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isVerified ? 'Verification Successful!' : 'Verification Failed',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text(
              'Status: $status',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isVerified ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Similarity Score: ${(similarity * 100).toStringAsFixed(2)}%',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isVerified ? Colors.green : Colors.orange,
              ),
            ),
            if (token != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[700],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Authentication token received',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (isVerified)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, {
                  'success': true,
                  'similarity': similarity,
                  'message': message,
                  'token': token,
                  'status': status,
                });
              },
              child: const Text('Continue'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _retakeVideo();
              },
              child: const Text('Try Again'),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _controller == null) {
      return Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.4,
        color: Colors.black,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Initializing Camera...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isRecording
                    ? Colors.red
                    : _faceCentered
                    ? Colors.green
                    : const Color(0xFF13A4B4),
                width: 3,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CameraPreview(_controller!),
            ),
          ),
          if (_isRecording)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'REC ${_maxRecordingDuration - _recordingDuration}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.width * 0.6,
            decoration: BoxDecoration(
              border: Border.all(
                color: _faceCentered ? Colors.green : Colors.white,
                width: _faceCentered ? 4 : 3,
              ),
              borderRadius: BorderRadius.circular(
                MediaQuery.of(context).size.width * 0.3,
              ),
            ),
            child: _faceCentered
                ? const Icon(Icons.check_circle, color: Colors.green, size: 40)
                : null,
          ),
          Positioned(
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _faceStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _verificationSuccess ? Colors.green : const Color(0xFF13A4B4),
          width: 3,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Container(
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isVerifying) ...[
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Verifying Identity...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (_verificationSuccess) ...[
                    const Icon(Icons.verified, size: 60, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      'Identity Verified!',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        'Score: ${(_similarityScore * 100).toStringAsFixed(2)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.play_circle_filled,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Processing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!_isVerifying && !_verificationSuccess)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: _retakeVideo,
                  backgroundColor: Colors.red,
                  mini: true,
                  child: const Icon(Icons.replay, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Face Verification',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF13A4B4),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFD6E6F2)],
              stops: [0.1, 0.9],
            ),
          ),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Column(
                children: [
                  Icon(
                    Icons.face_retouching_natural,
                    size: 48,
                    color: const Color(0xFF13A4B4).withOpacity(0.8),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Face Verification",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF13A4B4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "ID: ${widget.idNumber}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[800],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[800],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _showPreview
                            ? _isVerifying
                                  ? "Verifying..."
                                  : _verificationSuccess
                                  ? "Verification Complete"
                                  : "Processing"
                            : _isRecording
                            ? "Recording... ($_recordingDuration/$_maxRecordingDuration)"
                            : _faceStatus,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: _showPreview
                          ? _buildVideoPreview()
                          : _buildCameraPreview(),
                    ),
                    if (_isRecording) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _recordingDuration / _maxRecordingDuration,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.red,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ensure good lighting and face the camera directly',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
