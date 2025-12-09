import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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
  bool _isCompressing = false;
  String? _errorMessage;
  Timer? _recordingTimer;
  Timer? _faceDetectionTimer;
  int _recordingDuration = 0;
  final int _maxRecordingDuration = 5; // Reduced to 5 seconds
  XFile? _recordedVideo;
  String? _compressedVideoPath;
  bool _showPreview = false;
  double _verificationThreshold = 0.7;
  bool _verificationSuccess = false;
  double _similarityScore = 0.0;

  // Verification details
  Map<String, dynamic>? _verificationDetails;

  // File size tracking
  int _originalFileSize = 0;
  int _compressedFileSize = 0;
  double _compressionRatio = 1.0;

  // Face detection variables
  late FaceDetector _faceDetector;
  bool _faceDetected = false;
  int _qualityChecksPassed = 0;
  final int _minQualityChecks = 1; // Just need 1 face detection
  int _consecutiveQualityFrames = 0;
  double _faceConfidence = 0.0;
  String _faceStatus = 'Initializing...';

  // Instructions queue
  final List<String> _instructions = [
    "Look straight",
    "Hold still",
    "Processing...",
  ];
  int _currentInstructionIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeFaceDetector();
    _initializeCamera();
    _initializeVideoCompression();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableLandmarks: false, // Simplified - no landmarks
      enableContours: false, // Simplified - no contours
      enableClassification: false, // Simplified - no classification
      minFaceSize: 0.1, // Lower minimum size
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _initializeVideoCompression() async {
    await VideoCompress.setLogLevel(0); // Disable logs for production
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

      // Use medium resolution for better face recognition
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Changed to medium for better quality
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
              print('Camera initialized at medium resolution');
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

  /// Simple face detection - just check if any face is present
  void _startSimpleFaceDetection() {
    _faceDetectionTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) async {
      if (!_isCameraInitialized ||
          _controller == null ||
          !_controller!.value.isInitialized ||
          _isRecording ||
          _showPreview) {
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
            _faceDetected = false;
            _faceStatus = 'No face detected. Face the camera.';
            _consecutiveQualityFrames = 0;
            _faceConfidence = 0.0;
          });
          return;
        }

        // Face detected - mark as ready
        setState(() {
          _faceDetected = true;
          _faceConfidence = 100.0;
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
      // Stop face detection timer when recording starts
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
        _verificationDetails = null;
        _faceStatus = 'Recording...';
        _currentInstructionIndex = 0;
      });

      // Start instruction cycling
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;

            // Cycle through instructions
            if (_recordingDuration <= _instructions.length) {
              _faceStatus = _instructions[_recordingDuration - 1];
            }
          });

          if (_recordingDuration >= _maxRecordingDuration) {
            _stopRecording();
            timer.cancel();
          }
        }
      });

      print('Recording started');
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
        final originalFile = File(videoFile.path);
        _originalFileSize = await originalFile.length();

        setState(() {
          _isRecording = false;
          _recordedVideo = videoFile;
          _showPreview = true;
          _faceStatus = 'Compressing video...';
          _isCompressing = true;
        });

        print('Original file size: ${_originalFileSize} bytes');

        // Compress video before uploading
        await _compressAndSubmitVideo(videoFile);
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
        _isCompressing = false;
      });
    }
  }

  Future<void> _compressAndSubmitVideo(XFile videoFile) async {
    try {
      print('Starting video compression...');

      // Compress video to reduce file size
      final mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality
            .MediumQuality, // Medium quality for better face recognition
        deleteOrigin: false, // Keep original for reference
        includeAudio: false,
      );

      if (mediaInfo == null || mediaInfo.file == null) {
        throw Exception('Video compression failed');
      }

      _compressedVideoPath = mediaInfo.file!.path;
      _compressedFileSize = mediaInfo.filesize ?? 0;
      _compressionRatio = _originalFileSize > 0
          ? _compressedFileSize / _originalFileSize
          : 1.0;

      print('Video compressed successfully:');
      print('  Original: ${_originalFileSize} bytes');
      print('  Compressed: ${_compressedFileSize} bytes');
      print('  Ratio: ${(_compressionRatio * 100).toStringAsFixed(1)}%');
      print('  Path: $_compressedVideoPath');

      setState(() {
        _isCompressing = false;
        _faceStatus = 'Verifying identity...';
      });

      // Submit compressed video
      await _submitVideo();
    } catch (e) {
      print('Video compression error: $e');
      setState(() {
        _isCompressing = false;
        _faceStatus = 'Using original video...';
      });

      // Fallback: submit original video if compression fails
      await _submitVideo(useOriginal: true);
    }
  }

  Future<void> _submitVideo({bool useOriginal = false}) async {
    File? videoFile;

    if (useOriginal || _compressedVideoPath == null) {
      videoFile = File(_recordedVideo!.path);
      print('Using original video file: ${videoFile.path}');
    } else {
      videoFile = File(_compressedVideoPath!);
      print('Using compressed video file: ${videoFile.path}');
    }

    if (!await videoFile.exists()) {
      setState(() {
        _errorMessage = 'Video file not found';
        _faceStatus = 'Error - please try again';
        _isVerifying = false;
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.verifyVideoWithEmbedding(
        videoFile: videoFile,
        idNumber: widget.idNumber,
      );

      setState(() {
        _isVerifying = false;
      });

      if (result['success'] == true) {
        final isVerified = result['is_verified'] ?? false;
        final similarity = result['similarity'] ?? 0.0;
        final message = result['message'] ?? 'Verification completed';
        final token =
            result['token'] ?? result['access_token']; // Use either token
        final status = result['status'] ?? 'UNKNOWN';
        final confidence = result['confidence'] ?? 0.0;
        final thresholdUsed = result['threshold_used'] ?? 0.7;

        // Extract all verification details
        final verificationData = {
          'isMatch': result['is_match'] ?? false,
          'similarity': similarity,
          'confidence': confidence,
          'message': message,
          'deepfakeDetected': result['deepfake_detected'] ?? false,
          'livenessCheckPassed': result['liveness_check_passed'] ?? false,
          'blinksDetected': result['blinks_detected'] ?? 0,
          'processingTimeMs': result['processing_time_ms'] ?? 0,
          'thresholdUsed': thresholdUsed,
          'citizenId': result['citizen_id'] ?? widget.idNumber,
          'fileSize': _compressedFileSize > 0
              ? _compressedFileSize
              : _originalFileSize,
          'compressed': !useOriginal && _compressedVideoPath != null,
        };

        setState(() {
          _verificationSuccess = isVerified;
          _similarityScore = similarity;
          _verificationDetails = verificationData;
          _faceStatus = isVerified
              ? '✅ Identity Verified!'
              : '❌ Verification Failed';
        });

        _showVerificationResult(
          isVerified,
          similarity,
          message,
          token,
          status,
          verificationData,
        );
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
      print('Submit video error: $e');
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Failed to verify video: $e';
        _verificationSuccess = false;
        _faceStatus = 'Error - please try again';
      });
    }
  }

  Future<void> _retakeVideo() async {
    // Clean up compressed file if exists
    if (_compressedVideoPath != null &&
        File(_compressedVideoPath!).existsSync()) {
      await File(_compressedVideoPath!).delete();
    }

    setState(() {
      _recordedVideo = null;
      _compressedVideoPath = null;
      _showPreview = false;
      _recordingDuration = 0;
      _verificationSuccess = false;
      _similarityScore = 0.0;
      _verificationDetails = null;
      _faceDetected = false;
      _consecutiveQualityFrames = 0;
      _originalFileSize = 0;
      _compressedFileSize = 0;
      _compressionRatio = 1.0;
      _faceStatus = 'Face the camera and click Start';
      _isCompressing = false;
    });

    // Restart face detection
    _startSimpleFaceDetection();
  }

  void _showVerificationResult(
    bool isVerified,
    double similarity,
    String message,
    String? token,
    String status,
    Map<String, dynamic> verificationData,
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
              style: TextStyle(
                color: isVerified ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(color: isVerified ? Colors.green : Colors.red),
              ),
              const SizedBox(height: 16),

              // Similarity Score
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Similarity Score:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${(similarity * 100).toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                similarity >=
                                    (verificationData['thresholdUsed'] ?? 0.7)
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Threshold: ${((verificationData['thresholdUsed'] ?? 0.7) * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (verificationData['confidence'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Confidence: ${(verificationData['confidence'] * 100).toStringAsFixed(2)}%',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),

              // File size info
              if (_compressedFileSize > 0) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.storage, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'File Size: ${(_compressedFileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Compressed to ${(_compressionRatio * 100).toStringAsFixed(1)}% of original',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Verification Details
              if (verificationData.isNotEmpty) ...[
                const Text(
                  'Verification Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...verificationData.entries.map((entry) {
                  if (entry.key == 'message' ||
                      entry.key == 'similarity' ||
                      entry.key == 'fileSize' ||
                      entry.key == 'compressed') {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '${_formatKey(entry.key)}: ',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        _formatValue(entry.key, entry.value),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
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
                  'verification_data': verificationData,
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

  String _formatKey(String key) {
    final Map<String, String> keyMap = {
      'isMatch': 'Match',
      'deepfakeDetected': 'Deepfake',
      'livenessCheckPassed': 'Liveness',
      'blinksDetected': 'Blinks',
      'processingTimeMs': 'Processing Time',
      'thresholdUsed': 'Threshold',
      'citizenId': 'Citizen ID',
    };
    return keyMap[key] ?? key;
  }

  Widget _formatValue(String key, dynamic value) {
    if (value is bool) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: value ? Colors.green[100] : Colors.red[100],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value ? 'YES' : 'NO',
          style: TextStyle(
            color: value ? Colors.green[800] : Colors.red[800],
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (key == 'processingTimeMs') {
      return Text('${value} ms', style: const TextStyle(fontSize: 12));
    } else if (key == 'thresholdUsed') {
      return Text(
        '${(value * 100).toStringAsFixed(0)}%',
        style: const TextStyle(fontSize: 12),
      );
    } else if (value is num) {
      return Text(
        value.toStringAsFixed(2),
        style: const TextStyle(fontSize: 12),
      );
    }
    return Text(value.toString(), style: const TextStyle(fontSize: 12));
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
                    : _faceDetected
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
                color: _faceDetected ? Colors.green : Colors.white,
                width: _faceDetected ? 4 : 3,
              ),
              borderRadius: BorderRadius.circular(
                MediaQuery.of(context).size.width * 0.3,
              ),
            ),
            child: _faceDetected
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
                  if (_isCompressing) ...[
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Compressing video...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_compressedFileSize / 1024 / 1024).toStringAsFixed(2)} MB',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ] else if (_isVerifying) ...[
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
                  ] else if (_similarityScore > 0) ...[
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verification Failed',
                      style: TextStyle(
                        color: Colors.red,
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
            if (!_isVerifying &&
                !_isCompressing &&
                !_verificationSuccess &&
                _similarityScore == 0)
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
                    "Citizen ID: ${widget.idNumber}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.blue),
                        SizedBox(width: 6),
                        Text(
                          'Optimized for 5MB upload limit',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                            ? _isCompressing
                                  ? "Compressing..."
                                  : _isVerifying
                                  ? "Verifying..."
                                  : _verificationSuccess
                                  ? "Verification Complete"
                                  : _similarityScore > 0
                                  ? "Verification Failed"
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
              if (!_showPreview && !_isRecording)
                ElevatedButton(
                  onPressed: () {
                    // Start face detection when button is pressed
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
              const Text(
                '5-second video • Optimized for small file size',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
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
