// lib/id_card_selection_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IDCardSelectionScreen extends StatefulWidget {
  final String selectedCardType;
  final Map<String, Map<String, String>> allCardData;

  const IDCardSelectionScreen({
    super.key,
    required this.selectedCardType,
    required this.allCardData,
  });

  @override
  State<IDCardSelectionScreen> createState() => _IDCardSelectionScreenState();
}

class _IDCardSelectionScreenState extends State<IDCardSelectionScreen> {
  late Map<String, bool> selectedFields;
  late Map<String, List<String>> fieldSources;
  bool _showQRCode = false;
  Map<String, String>? _qrData;
  String? _qrId;
  DateTime? _qrExpiry;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedFields = {};
    fieldSources = {};
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load previously selected fields first
    await _loadSelectedFields();
    
    // Filter data based on card type - only include relevant fields
    final filteredCardData = _filterDataByCardType();
    
    // Build a map of unique fields and which cards they appear in (only from filtered data)
    for (var cardEntry in filteredCardData.entries) {
      for (var fieldEntry in cardEntry.value.entries) {
        if (!fieldSources.containsKey(fieldEntry.key)) {
          fieldSources[fieldEntry.key] = [];
        }
        fieldSources[fieldEntry.key]!.add(cardEntry.key);
        
        // Initialize selection - preserve previous selection if exists,
        // otherwise default to true if field exists in selected card
        if (!selectedFields.containsKey(fieldEntry.key)) {
          selectedFields[fieldEntry.key] = 
              filteredCardData[widget.selectedCardType]?.containsKey(fieldEntry.key) ?? false;
        }
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  // Filter data to only include relevant cards based on selected card type
  Map<String, Map<String, String>> _filterDataByCardType() {
    final filteredData = <String, Map<String, String>>{};
    
    if (_isDigitalIDCard(widget.selectedCardType)) {
      // Only include Digital ID related cards
      for (var cardEntry in widget.allCardData.entries) {
        if (_isDigitalIDCard(cardEntry.key)) {
          filteredData[cardEntry.key] = cardEntry.value;
        }
      }
    } else if (_isDigitalLicenseCard(widget.selectedCardType)) {
      // Only include Digital License related cards
      for (var cardEntry in widget.allCardData.entries) {
        if (_isDigitalLicenseCard(cardEntry.key)) {
          filteredData[cardEntry.key] = cardEntry.value;
        }
      }
    } else {
      // For other card types, include all data (fallback)
      return widget.allCardData;
    }
    
    return filteredData;
  }

  // Helper methods to identify card types
  bool _isDigitalIDCard(String cardType) {
    return cardType.toLowerCase().contains('digital id') ||
           cardType.toLowerCase().contains('id card') ||
           cardType.toLowerCase().contains('national id') ||
           cardType.toLowerCase().contains('identity card');
  }

  bool _isDigitalLicenseCard(String cardType) {
    return cardType.toLowerCase().contains('digital license') ||
           cardType.toLowerCase().contains('driver license') ||
           cardType.toLowerCase().contains('driving license') ||
           cardType.toLowerCase().contains('license');
  }

  // Load previously selected fields from shared preferences
  Future<void> _loadSelectedFields() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSelections = prefs.getString('selected_fields_${widget.selectedCardType}');
      
      if (savedSelections != null) {
        final Map<String, dynamic> savedData = json.decode(savedSelections);
        for (var entry in savedData.entries) {
          selectedFields[entry.key] = entry.value as bool;
        }
      }
    } catch (e) {
      print('Error loading saved selections: $e');
    }
  }

  // Save selected fields to shared preferences
  Future<void> _saveSelectedFields() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'selected_fields_${widget.selectedCardType}',
        json.encode(selectedFields),
      );
    } catch (e) {
      print('Error saving selections: $e');
    }
  }

  void _generateQRCode() async {
    final selectedData = <String, String>{};
    
    // Get filtered data for the current card type
    final filteredCardData = _filterDataByCardType();
    final selectedCardData = filteredCardData[widget.selectedCardType];
    
    // Check if selectedCardData is null
    if (selectedCardData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available for selected card')),
      );
      return;
    }
    
    for (var field in selectedFields.entries) {
      if (field.value) {
        // Use value from the originally selected card if available,
        // otherwise use the first available value from filtered data
        String? fieldValue;
        
        if (selectedCardData.containsKey(field.key)) {
          fieldValue = selectedCardData[field.key];
        } else {
          final sourceCards = fieldSources[field.key];
          if (sourceCards != null && sourceCards.isNotEmpty) {
            final firstCard = filteredCardData[sourceCards.first];
            if (firstCard != null) {
              fieldValue = firstCard[field.key];
            }
          }
        }
        
        // Only add if we have a valid value
        if (fieldValue != null) {
          selectedData[field.key] = fieldValue;
        }
      }
    }

    // Check if we have any data to share
    if (selectedData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid data selected to share')),
      );
      return;
    }

    // Save the current selections before generating QR code
    await _saveSelectedFields();

    // Generate unique ID for this QR session
    _qrId = DateTime.now().millisecondsSinceEpoch.toString();
    _qrExpiry = DateTime.now().add(const Duration(minutes: 2));
    
    // Store the data locally with expiry
    await _storeQRData(_qrId!, selectedData, _qrExpiry!);
    
    // Create QR content with ONLY the selected field data (no metadata, no headers)
    final qrContent = _formatDataForQR(selectedData);

    _qrData = selectedData;
    
    setState(() {
      _showQRCode = true;
    });

    // Auto-hide QR code after 2 minutes
    Future.delayed(const Duration(minutes: 2), () {
      if (mounted && _showQRCode && _qrId != null) {
        _invalidateQRCode(_qrId!);
        setState(() {
          _showQRCode = false;
          _qrData = null;
          _qrId = null;
          _qrExpiry = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code has expired')),
        );
      }
    });
  }

  // Format data for QR code - ONLY the selected field data, nothing else
  String _formatDataForQR(Map<String, String> data) {
    final lines = <String>[];
    
    // Add ONLY the selected fields and their values
    for (var entry in data.entries) {
      lines.add('${entry.key}: ${entry.value}');
    }
    
    return lines.join('\n');
  }

  // Store QR data locally with expiry
  Future<void> _storeQRData(String id, Map<String, String> data, DateTime expiry) async {
    final prefs = await SharedPreferences.getInstance();
    final qrData = {
      'data': data,
      'expiry': expiry.toIso8601String(),
      'used': false,
      'card_type': widget.selectedCardType,
    };
    await prefs.setString('qr_$id', json.encode(qrData));
    
    // Clean up old QR codes
    _cleanupOldQRCodes();
  }

  // Invalidate QR code after use or expiry
  Future<void> _invalidateQRCode(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('qr_$id');
  }

  // Clean up expired QR codes
  Future<void> _cleanupOldQRCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('qr_'));
    
    for (final key in keys) {
      final data = prefs.getString(key);
      if (data != null) {
        try {
          final qrData = json.decode(data) as Map<String, dynamic>;
          final expiry = DateTime.parse(qrData['expiry'] as String);
          if (expiry.isBefore(DateTime.now())) {
            await prefs.remove(key);
          }
        } catch (e) {
          // Remove invalid entries
          await prefs.remove(key);
        }
      }
    }
  }

  // Method to retrieve and verify QR data (for the receiving side)
  static Future<Map<String, dynamic>?> verifyQRCode(String qrContent) async {
    try {
      // Parse the clean text format
      final lines = qrContent.split('\n');
      final data = <String, String>{};
      
      for (final line in lines) {
        if (line.contains(': ')) {
          final parts = line.split(': ');
          if (parts.length >= 2) {
            data[parts[0]] = parts.sublist(1).join(': ');
          }
        }
      }

      return {
        'data': data,
        'verified': true,
      };
    } catch (e) {
      return {'error': 'Invalid QR code format'};
    }
  }

  void _closeQRCode() {
    if (_qrId != null) {
      _invalidateQRCode(_qrId!);
    }
    setState(() {
      _showQRCode = false;
      _qrData = null;
      _qrId = null;
      _qrExpiry = null;
    });
  }

  String _getRemainingTime() {
    if (_qrExpiry == null) return 'Expired';
    
    final now = DateTime.now();
    final difference = _qrExpiry!.difference(now);
    
    if (difference.inSeconds <= 0) return 'Expired';
    
    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;
    
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Get card type description for UI
  String _getCardTypeDescription() {
    if (_isDigitalIDCard(widget.selectedCardType)) {
      return 'Digital ID';
    } else if (_isDigitalLicenseCard(widget.selectedCardType)) {
      return 'Digital License';
    } else {
      return widget.selectedCardType;
    }
  }

  // Get available sources description
  String _getSourcesDescription(List<String> sources) {
    final filteredSources = sources.where((source) {
      if (_isDigitalIDCard(widget.selectedCardType)) {
        return _isDigitalIDCard(source);
      } else if (_isDigitalLicenseCard(widget.selectedCardType)) {
        return _isDigitalLicenseCard(source);
      }
      return true;
    }).toList();

    return filteredSources.join(", ");
  }

  // Responsive helper methods
  bool get _isSmallScreen => MediaQuery.of(context).size.width < 600;
  bool get _isMediumScreen => 
      MediaQuery.of(context).size.width >= 600 && 
      MediaQuery.of(context).size.width < 1200;
  bool get _isLargeScreen => MediaQuery.of(context).size.width >= 1200;

  double get _horizontalPadding {
    if (_isSmallScreen) return 16.0;
    if (_isMediumScreen) return 24.0;
    return 32.0;
  }

  double get _qrCodeSize {
    if (_isSmallScreen) return 200.0;
    if (_isMediumScreen) return 250.0;
    return 300.0;
  }

  double get _fontSizeTitle {
    if (_isSmallScreen) return 18.0;
    if (_isMediumScreen) return 20.0;
    return 22.0;
  }

  double get _fontSizeBody {
    if (_isSmallScreen) return 14.0;
    if (_isMediumScreen) return 16.0;
    return 17.0;
  }

  double get _fontSizeSmall {
    if (_isSmallScreen) return 12.0;
    if (_isMediumScreen) return 13.0;
    return 14.0;
  }

  @override
  Widget build(BuildContext context) {
    // Get unique field names sorted alphabetically (only from filtered data)
    final uniqueFields = fieldSources.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: _showQRCode 
            ? Text('Share ${_getCardTypeDescription()} via QR Code')
            : Text('Select ${_getCardTypeDescription()} Information to Share'),
        centerTitle: true,
        leading: _showQRCode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeQRCode,
              )
            : null,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF), // White
              Color(0xFFD6E6F2), // Light blue
            ],
            stops: [0.1, 0.9],
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding, vertical: 16.0),
        child: _isLoading 
            ? _buildLoadingView()
            : (_showQRCode ? _buildQRCodeView() : _buildSelectionView(uniqueFields)),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF13A4B4)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading your preferences...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionView(List<String> uniqueFields) {
    return Column(
      children: [
        // Information header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(_isSmallScreen ? 16.0 : 20.0),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isDigitalIDCard(widget.selectedCardType) 
                        ? Icons.perm_identity
                        : Icons.drive_eta,
                    color: const Color(0xFF13A4B4),
                    size: _fontSizeTitle,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_getCardTypeDescription()}: ${widget.selectedCardType}',
                      style: TextStyle(
                        fontSize: _fontSizeTitle,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF13A4B4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isDigitalIDCard(widget.selectedCardType)
                    ? 'Select the Digital ID information you want to share. Only Digital ID related fields are shown.'
                    : 'Select the Digital License information you want to share. Only Digital License related fields are shown.',
                style: TextStyle(
                  fontSize: _fontSizeBody,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF13A4B4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: _fontSizeSmall,
                      color: const Color(0xFF13A4B4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing only ${_getCardTypeDescription().toLowerCase()} related fields',
                        style: TextStyle(
                          fontSize: _fontSizeSmall,
                          color: const Color(0xFF13A4B4),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _isLargeScreen 
              ? _buildGridView(uniqueFields)
              : _buildListView(uniqueFields),
        ),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildListView(List<String> uniqueFields) {
    return ListView(
      children: [
        for (var field in uniqueFields)
          _buildFieldItem(
            field,
            _getFieldValue(field),
            fieldSources[field]!,
          ),
      ],
    );
  }

  Widget _buildGridView(List<String> uniqueFields) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: _isLargeScreen ? 2.5 : 2.0,
      ),
      itemCount: uniqueFields.length,
      itemBuilder: (context, index) {
        final field = uniqueFields[index];
        return _buildFieldItem(
          field,
          _getFieldValue(field),
          fieldSources[field]!,
        );
      },
    );
  }

  // Helper method to get field value safely from filtered data
  String _getFieldValue(String fieldName) {
    final filteredCardData = _filterDataByCardType();
    final selectedCardData = filteredCardData[widget.selectedCardType];
    
    if (selectedCardData != null && selectedCardData.containsKey(fieldName)) {
      return selectedCardData[fieldName] ?? 'N/A';
    }
    
    final sourceCards = fieldSources[fieldName];
    if (sourceCards != null && sourceCards.isNotEmpty) {
      final firstCard = filteredCardData[sourceCards.first];
      if (firstCard != null && firstCard.containsKey(fieldName)) {
        return firstCard[fieldName] ?? 'N/A';
      }
    }
    
    return 'N/A';
  }

  Widget _buildQRCodeView() {
    final selectedFieldsCount = _qrData?.length ?? 0;
    
    // Create QR content with ONLY the selected field data
    final qrContent = _formatDataForQR(_qrData!);
    
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header with timer
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(_isSmallScreen ? 16.0 : 20.0),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isDigitalIDCard(widget.selectedCardType) 
                            ? Icons.perm_identity
                            : Icons.drive_eta,
                        color: const Color(0xFF13A4B4),
                        size: _fontSizeTitle,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_getCardTypeDescription()} QR Code',
                        style: TextStyle(
                          fontSize: _fontSizeTitle,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer, size: _isSmallScreen ? 16 : 18, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Expires in: ${_getRemainingTime()}',
                        style: TextStyle(
                          fontSize: _fontSizeBody,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This QR can only be scanned once',
                    style: TextStyle(
                      fontSize: _fontSizeSmall,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // QR Code Container
            Container(
              padding: EdgeInsets.all(_isSmallScreen ? 20.0 : 24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: qrContent,
                    version: QrVersions.auto,
                    size: _qrCodeSize,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sharing $selectedFieldsCount ${_getCardTypeDescription().toLowerCase()} fields',
                    style: TextStyle(
                      fontSize: _fontSizeBody,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF13A4B4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Selected Information Summary
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(_isSmallScreen ? 16.0 : 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sharing ${_getCardTypeDescription()} Information ($selectedFieldsCount items):',
                    style: TextStyle(
                      fontSize: _fontSizeBody,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._qrData!.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• ${entry.key}: ${entry.value}',
                      style: TextStyle(fontSize: _fontSizeSmall),
                    ),
                  )),
                ],
              ),
            ),

            const SizedBox(height: 20),
            
            // QR Content Preview
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(_isSmallScreen ? 16.0 : 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code contains ONLY your selected ${_getCardTypeDescription().toLowerCase()} data:',
                    style: TextStyle(
                      fontSize: _fontSizeBody,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        qrContent,
                        style: TextStyle(
                          fontSize: _fontSizeSmall,
                          fontFamily: 'Monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            _buildQRActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldItem(String fieldName, String fieldValue, List<String> sourceCards) {
    return Card(
      margin: EdgeInsets.symmetric(
        vertical: _isSmallScreen ? 4.0 : 6.0,
        horizontal: 0,
      ),
      child: CheckboxListTile(
        title: Text(
          fieldName,
          style: TextStyle(
            fontSize: _fontSizeBody,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fieldValue,
              style: TextStyle(fontSize: _fontSizeSmall),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Available in: ${_getSourcesDescription(sourceCards)}',
              style: TextStyle(
                fontSize: _fontSizeSmall - 2,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        value: selectedFields[fieldName] ?? false,
        onChanged: (bool? value) {
          setState(() {
            selectedFields[fieldName] = value ?? false;
          });
          // Save the selection immediately when changed
          _saveSelectedFields();
        },
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF13A4B4),
        contentPadding: EdgeInsets.symmetric(
          horizontal: _isSmallScreen ? 16.0 : 20.0,
          vertical: _isSmallScreen ? 8.0 : 12.0,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final selectedCount = selectedFields.values.where((value) => value).length;
    
    return Column(
      children: [
        if (selectedCount > 0)
          Container(
            padding: EdgeInsets.all(_isSmallScreen ? 12.0 : 16.0),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], 
                    size: _isSmallScreen ? 16 : 18),
                const SizedBox(width: 8),
                Text(
                  '$selectedCount ${_getCardTypeDescription().toLowerCase()} field${selectedCount > 1 ? 's' : ''} selected for sharing',
                  style: TextStyle(
                    fontSize: _fontSizeBody,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    vertical: _isSmallScreen ? 16.0 : 18.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: _fontSizeBody),
                ),
              ),
            ),
            SizedBox(width: _isSmallScreen ? 16 : 20),
            Expanded(
              child: ElevatedButton(
                onPressed: selectedCount > 0 ? _generateQRCode : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedCount > 0 
                      ? const Color(0xFF13A4B4)
                      : Colors.grey,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                    vertical: _isSmallScreen ? 16.0 : 18.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Generate QR Code',
                  style: TextStyle(fontSize: _fontSizeBody),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQRActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _closeQRCode,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(
                vertical: _isSmallScreen ? 16.0 : 18.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Close QR',
              style: TextStyle(fontSize: _fontSizeBody),
            ),
          ),
        ),
        SizedBox(width: _isSmallScreen ? 16 : 20),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              _closeQRCode();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR code closed')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF13A4B4),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(
                vertical: _isSmallScreen ? 16.0 : 18.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Done',
              style: TextStyle(fontSize: _fontSizeBody),
            ),
          ),
        ),
      ],
    );
  }
}