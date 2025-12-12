import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:new_project/app_theme.dart';
import 'presentation_approval_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isFlashOn = false;
  bool isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _handleQRCode(String qrData) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      cameraController.stop();

      final uri = Uri.parse(qrData);
      final pathSegments = uri.pathSegments;

      final requestIndex = pathSegments.indexOf('request');
      if (requestIndex != -1 && requestIndex < pathSegments.length - 1) {
        final sessionId = pathSegments[requestIndex + 1];

        final drivingLicenseIndex = pathSegments.indexOf('driving-license');
        if (drivingLicenseIndex != -1 && drivingLicenseIndex < requestIndex) {
          if (mounted) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PresentationApprovalScreen(
                  sessionId: sessionId,
                  requestUrl: qrData,
                ),
              ),
            );

            if (result != true && mounted) {
              setState(() {
                isProcessing = false;
              });
              cameraController.start();
            }
          }
        } else {
          _showErrorDialog(
            'Invalid QR Code',
            'This QR code is not a valid driving license request.',
          );
          setState(() {
            isProcessing = false;
          });
          cameraController.start();
        }
      } else {
        _showErrorDialog(
          'Invalid QR Code',
          'This QR code is not a valid request format.',
        );
        setState(() {
          isProcessing = false;
        });
        cameraController.start();
      }
    } catch (e) {
      _showErrorDialog('Error', 'Failed to process QR code: ${e.toString()}');
      setState(() {
        isProcessing = false;
      });
      cameraController.start();
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkBg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(message, style: TextStyle(color: Colors.white.withOpacity(0.7))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _toggleFlash() {
    setState(() {
      isFlashOn = !isFlashOn;
    });
    cameraController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !isProcessing) {
                final barcode = barcodes.first;
                if (barcode.rawValue != null) {
                  _handleQRCode(barcode.rawValue!);
                }
              }
            },
          ),

          // Dark overlay with cutout
          CustomPaint(
            size: Size.infinite,
            painter: ScanOverlayPainter(),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button - hidden since this is a tab
                  const SizedBox(width: 48),
                  
                  // Title
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // Flash toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(
                        isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: isFlashOn ? AppTheme.accentColor : Colors.white,
                      ),
                      onPressed: _toggleFlash,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scanning frame
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  // Animated corners
                  _buildCorner(Alignment.topLeft),
                  _buildCorner(Alignment.topRight),
                  _buildCorner(Alignment.bottomLeft),
                  _buildCorner(Alignment.bottomRight),
                ],
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg2.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isProcessing ? Icons.hourglass_top_rounded : Icons.qr_code_scanner_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isProcessing ? 'Processing...' : 'Point camera at QR code',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: AppTheme.glassDecoration(borderRadius: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.primaryColor),
                      const SizedBox(height: 20),
                      Text(
                        'Processing QR Code...',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? const BorderSide(color: AppTheme.primaryColor, width: 4)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? const BorderSide(color: AppTheme.primaryColor, width: 4)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? const BorderSide(color: AppTheme.primaryColor, width: 4)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? const BorderSide(color: AppTheme.primaryColor, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// Custom painter for the scan overlay
class ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    const scanAreaSize = 280.0;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2;

    // Draw dark overlay with rounded cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize),
        const Radius.circular(24),
      ));
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
