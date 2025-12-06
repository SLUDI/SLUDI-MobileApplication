import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
      print('[LoginScreen] Device lock status: $uri');
      final pathSegments = uri.pathSegments;

      // More flexible parsing - look for the pattern anywhere in the path
      final requestIndex = pathSegments.indexOf('request');
      if (requestIndex != -1 && requestIndex < pathSegments.length - 1) {
        final sessionId = pathSegments[requestIndex + 1];

        // Additional validation - ensure this is a driving license request
        final drivingLicenseIndex = pathSegments.indexOf('driving-license');
        if (drivingLicenseIndex != -1 && drivingLicenseIndex < requestIndex) {
          // Navigate to approval screen
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

            // Resume scanning if user returns without completing
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
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
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
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
        ],
      ),
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

          // Scanning frame overlay
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Corner decorations
          Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                children: [
                  // Top-left corner
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.green, width: 4),
                          left: BorderSide(color: Colors.green, width: 4),
                        ),
                      ),
                    ),
                  ),
                  // Top-right corner
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.green, width: 4),
                          right: BorderSide(color: Colors.green, width: 4),
                        ),
                      ),
                    ),
                  ),
                  // Bottom-left corner
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.green, width: 4),
                          left: BorderSide(color: Colors.green, width: 4),
                        ),
                      ),
                    ),
                  ),
                  // Bottom-right corner
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.green, width: 4),
                          right: BorderSide(color: Colors.green, width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isProcessing
                          ? 'Processing QR code...'
                          : 'Align the QR code within the frame to scan',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
