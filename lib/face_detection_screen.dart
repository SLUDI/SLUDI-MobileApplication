import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:new_project/main_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';
import 'api_service.dart';

class FaceDetectionScreen extends StatefulWidget {
  final String idNumber;

  const FaceDetectionScreen({super.key, required this.idNumber});

  @override
  State<FaceDetectionScreen> createState() =>
      _FaceDetectionScreenImprovedState();
}

class _FaceDetectionScreenImprovedState extends State<FaceDetectionScreen> {
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
  final int _maxRecordingDuration = 5;
  XFile? _recordedVideo;
  String? _compressedVideoPath;
  bool _verificationSuccess = false;
  double _similarityScore = 0.0;

  // Verification details
  Map<String, dynamic>? _verificationDetails;

  // Face detection variables
  late FaceDetector _faceDetector;
  bool _faceDetected = false;
  String _faceStatus = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeFaceDetector();
    _initializeCamera();
    _initializeVideoCompression();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableLandmarks: false,
      enableContours: false,
      enableClassification: false,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _initializeVideoCompression() async {
    await VideoCompress.setLogLevel(0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recordingTimer?.cancel();
    _faceDetectionTimer?.cancel();
    _faceDetector.close();
    VideoCompress.dispose();
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
                _faceStatus = 'Face the camera and click Start';
              });
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

  void _startSimpleFaceDetection() {
    _faceDetectionTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (!_isCameraInitialized ||
          _controller == null ||
          !_controller!.value.isInitialized ||
          _isRecording) {
        return;
      }

      try {
        final image = await _controller!.takePicture();
        final inputImage = InputImage.fromFilePath(image.path);
        final List<Face> faces = await _faceDetector.processImage(inputImage);

        final tempFile = File(image.path);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        if (faces.isEmpty) {
          setState(() {
            _faceDetected = false;
            _faceStatus = 'No face detected. Face the camera.';
          });
          return;
        }

        setState(() {
          _faceDetected = true;
          _faceStatus = 'Face detected! Ready to verify.';
        });
      } catch (e) {
        print('Face detection error: $e');
      }
    });
  }

  Future<void> _startRecording() async {
    if (!_isCameraInitialized || _isRecording) {
      return;
    }

    try {
      _faceDetectionTimer?.cancel();

      await _controller!.startVideoRecording();

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _errorMessage = null;
        _verificationSuccess = false;
        _similarityScore = 0.0;
        _verificationDetails = null;
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
    } catch (e, stackTrace) {
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
          _isLoading = true;
          _faceStatus = 'Processing...';
        });

        // Start processing
        _processAndSubmitVideo(videoFile);
      } else {
        setState(() {
          _isRecording = false;
          _errorMessage = 'Camera was not recording';
        });
      }
    } catch (e, stackTrace) {
      setState(() {
        _errorMessage = 'Failed to stop recording: ${e.toString()}';
        _isRecording = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _processAndSubmitVideo(XFile videoFile) async {
    try {
      setState(() {
        _faceStatus = 'Compressing video...';
      });

      // Compress video
      final mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: false,
      );

      if (mediaInfo == null || mediaInfo.file == null) {
        throw Exception('Video compression failed');
      }

      _compressedVideoPath = mediaInfo.file!.path;

      setState(() {
        _faceStatus = 'Verifying identity...';
        _isVerifying = true;
      });

      // Submit video
      await _submitVideo(mediaInfo.file!.path);
    } catch (e) {
      setState(() {
        _faceStatus = 'Using original video...';
      });
      
      // Fallback: submit original video
      await _submitVideo(videoFile.path);
    }
  }

  Future<void> _submitVideo(String videoPath) async {
    File videoFile = File(videoPath);

    if (!await videoFile.exists()) {
      setState(() {
        _errorMessage = 'Video file not found';
        _faceStatus = 'Error - please try again';
        _isLoading = false;
        _isVerifying = false;
      });
      return;
    }

    try {
      final result = await ApiService.verifyVideoWithEmbedding(
        videoFile: videoFile,
        idNumber: widget.idNumber,
      );

      setState(() {
        _isLoading = false;
        _isVerifying = false;
      });

      if (result['success'] == true) {
        final isVerified = result['is_verified'] ?? false;
        final similarity = result['similarity'] ?? 0.0;
        final message = result['message'] ?? 'Verification completed';
        
        // Extract JWT token from various possible response formats
        final String? jwtToken = _extractJwtToken(result);

        final verificationData = {
          'isMatch': result['is_match'] ?? false,
          'similarity': similarity,
          'confidence': result['confidence'] ?? 0.0,
          'message': message,
          'deepfakeDetected': result['deepfake_detected'] ?? false,
          'livenessCheckPassed': result['liveness_check_passed'] ?? false,
          'blinksDetected': result['blinks_detected'] ?? 0,
          'processingTimeMs': result['processing_time_ms'] ?? 0,
          'thresholdUsed': result['threshold_used'] ?? 0.7,
          'citizenId': result['citizen_id'] ?? widget.idNumber,
          'token': jwtToken,
        };

        setState(() {
          _verificationSuccess = isVerified;
          _similarityScore = similarity;
          _verificationDetails = verificationData;
          _faceStatus = isVerified
              ? '✅ Identity Verified!'
              : '❌ Verification Failed';
        });

        // If verification is successful and we have a token, handle login
        if (isVerified && jwtToken != null && jwtToken.isNotEmpty) {
          await _handleSuccessfulLogin(jwtToken);
        }
      } else {
        setState(() {
          _errorMessage =
              result['error'] ??
              result['message'] ??
              'Face verification failed';
          _faceStatus = 'Verification failed - try again';
          _verificationSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isVerifying = false;
        _errorMessage = 'Failed to verify video: $e';
        _verificationSuccess = false;
        _faceStatus = 'Error - please try again';
      });
    }
  }

  // Helper method to extract JWT token from API response
  String? _extractJwtToken(Map<String, dynamic> result) {
    // Try to extract token from various possible locations in the response
    String? token = result['token'];
    
    if (token == null || token.isEmpty) {
      token = result['access_token'];
    }
    
    if (token == null || token.isEmpty) {
      token = result['accessToken'];
    }
    
    if (token == null || token.isEmpty) {
      token = result['jwt'];
    }
    
    if (token == null || token.isEmpty && result['data'] != null) {
      final data = result['data'];
      if (data is Map<String, dynamic>) {
        token = data['token'] ?? data['access_token'] ?? data['accessToken'] ?? data['jwt'];
      }
    }
    
    return token;
  }

  // Handle successful face verification login
  Future<void> _handleSuccessfulLogin(String jwtToken) async {
    try {
      // Store the JWT token using the existing ApiService method
      ApiService.setAuthToken(jwtToken);
      print('[FaceDetection] ✅ JWT token stored: ${jwtToken.substring(0, 30)}...');
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face verification successful! Logging you in...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Navigate to MainScreen after a short delay
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainScreen(),
          ),
        );
      }
    } catch (e) {
      print('[FaceDetection] ❌ Error during login: $e');
      setState(() {
        _errorMessage = 'Login failed. Please try again.';
      });
    }
  }

  Future<void> _retakeVideo() async {
    if (_compressedVideoPath != null &&
        File(_compressedVideoPath!).existsSync()) {
      await File(_compressedVideoPath!).delete();
    }

    setState(() {
      _recordedVideo = null;
      _compressedVideoPath = null;
      _isLoading = false;
      _isVerifying = false;
      _recordingDuration = 0;
      _verificationSuccess = false;
      _similarityScore = 0.0;
      _verificationDetails = null;
      _faceDetected = false;
      _faceStatus = 'Face the camera and click Start';
    });

    _startSimpleFaceDetection();
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _controller == null) {
      return Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.4,
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF13A4B4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Initializing Camera...',
              style: TextStyle(
                color: Color(0xFF13A4B4),
                fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  final circleDiameter = MediaQuery.of(context).size.width * 0.7;

  return Container(
    width: double.infinity,
    height: MediaQuery.of(context).size.height * 0.4,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Circular camera preview with transparent background
        Container(
          width: circleDiameter,
          height: circleDiameter,
          child: ClipOval(
            child: Container(
              color: Colors.transparent, // Transparent background
              child: FittedBox(
                fit: BoxFit.cover,
                child: Container(
                  width: _controller!.value.previewSize!.height,
                  height: _controller!.value.previewSize!.width,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
        ),
        
        // Circular border with shadow for better visibility
        Container(
          width: circleDiameter,
          height: circleDiameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getBorderColor(),
              width: 4.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        
        // Face Detected Check Icon
        if (_faceDetected)
          Positioned(
            top: (MediaQuery.of(context).size.height * 0.2) - (circleDiameter / 2),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        
        // Recording Indicator
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
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
        
        // Status Text with semi-transparent background
        Positioned(
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5), // Semi-transparent
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
      ],
    ),
  );
}

  // Helper method to determine border color based on state
  Color _getBorderColor() {
    if (_isRecording) {
      return Colors.red;
    } else if (_faceDetected) {
      return Colors.green;
    } else {
      return const Color(0xFF13A4B4);
    }
  }

  Widget _buildLoadingScreen() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading)
            Column(
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF13A4B4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Processing Video...',
                  style: TextStyle(
                    color: Color(0xFF13A4B4),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _faceStatus,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            )
          else if (_isVerifying)
            Column(
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF13A4B4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Verifying Identity...',
                  style: TextStyle(
                    color: Color(0xFF13A4B4),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _faceStatus,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _verificationSuccess ? Icons.verified : Icons.error_outline,
            size: 80,
            color: _verificationSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 20),
          Text(
            _verificationSuccess ? 'Identity Verified!' : 'Verification Failed',
            style: TextStyle(
              color: _verificationSuccess ? Colors.green : Colors.red,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Similarity Score: ${(_similarityScore * 100).toStringAsFixed(2)}%',
            style: const TextStyle(
              color: Color(0xFF13A4B4),
              fontSize: 16,
            ),
          ),
          if (_verificationDetails != null &&
              _verificationDetails!['confidence'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Confidence: ${(_verificationDetails!['confidence'] * 100).toStringAsFixed(2)}%',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_verificationSuccess)
                ElevatedButton(
                  onPressed: () {
                    // If we have a token, use it to login
                    if (_verificationDetails != null && 
                        _verificationDetails!['token'] != null) {
                      _handleSuccessfulLogin(_verificationDetails!['token']);
                    } else {
                      // If no token, just navigate to MainScreen (for testing)
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MainScreen(),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Continue to App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _retakeVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
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
                    "Citizen ID: ${widget.idNumber}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        _isLoading || _isVerifying
                            ? _faceStatus
                            : _verificationSuccess || _similarityScore > 0
                                ? 'Verification Result'
                                : _isRecording
                                    ? 'Recording... ($_recordingDuration/$_maxRecordingDuration)'
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
                      child: _isLoading || _isVerifying
                          ? _buildLoadingScreen()
                          : (_verificationSuccess || _similarityScore > 0)
                              ? _buildResultScreen()
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
              if (!_isLoading &&
                  !_isVerifying &&
                  !_verificationSuccess &&
                  _similarityScore == 0 &&
                  !_isRecording)
                ElevatedButton(
                  onPressed: () {
                    _startSimpleFaceDetection();
                    _startRecording();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13A4B4),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start 5-Second Verification',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter to draw the circular overlay
class CircleOverlayPainter extends CustomPainter {
  final double circleRadius;
  final Color borderColor;
  final Color backgroundColor;

  CircleOverlayPainter({
    required this.circleRadius,
    required this.borderColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw semi-transparent background outside the circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    
    // Draw the full rectangle
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    
    // Clear the circle area (make it transparent)
    final circlePaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    
    canvas.drawCircle(center, circleRadius, circlePaint);
    
    // Draw the circular border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    
    canvas.drawCircle(center, circleRadius, borderPaint);
    
    // Draw inner guide circle
    final guidePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, circleRadius * 0.8, guidePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}