// lib/id_card_selection_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'theme_provider.dart';

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
    await _loadSelectedFields();
    
    final filteredCardData = _filterDataByCardType();
    
    for (var cardEntry in filteredCardData.entries) {
      for (var fieldEntry in cardEntry.value.entries) {
        if (!fieldSources.containsKey(fieldEntry.key)) {
          fieldSources[fieldEntry.key] = [];
        }
        fieldSources[fieldEntry.key]!.add(cardEntry.key);
        
        if (!selectedFields.containsKey(fieldEntry.key)) {
          selectedFields[fieldEntry.key] = 
              filteredCardData[widget.selectedCardType]?.containsKey(fieldEntry.key) ?? false;
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, Map<String, String>> _filterDataByCardType() {
    final filteredData = <String, Map<String, String>>{};
    
    if (_isDigitalIDCard(widget.selectedCardType)) {
      for (var cardEntry in widget.allCardData.entries) {
        if (_isDigitalIDCard(cardEntry.key)) {
          filteredData[cardEntry.key] = cardEntry.value;
        }
      }
    } else if (_isDigitalLicenseCard(widget.selectedCardType)) {
      for (var cardEntry in widget.allCardData.entries) {
        if (_isDigitalLicenseCard(cardEntry.key)) {
          filteredData[cardEntry.key] = cardEntry.value;
        }
      }
    } else {
      return widget.allCardData;
    }
    
    return filteredData;
  }

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
      debugPrint('Error loading saved selections: $e');
    }
  }

  Future<void> _saveSelectedFields() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'selected_fields_${widget.selectedCardType}',
        json.encode(selectedFields),
      );
    } catch (e) {
      debugPrint('Error saving selections: $e');
    }
  }

  void _generateQRCode() async {
    final selectedData = <String, String>{};
    final filteredCardData = _filterDataByCardType();
    final selectedCardData = filteredCardData[widget.selectedCardType];
    
    if (selectedCardData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available for selected card')),
      );
      return;
    }
    
    for (var field in selectedFields.entries) {
      if (field.value) {
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
        
        if (fieldValue != null) {
          selectedData[field.key] = fieldValue;
        }
      }
    }

    if (selectedData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid data selected to share')),
      );
      return;
    }

    await _saveSelectedFields();

    _qrId = DateTime.now().millisecondsSinceEpoch.toString();
    _qrExpiry = DateTime.now().add(const Duration(minutes: 2));
    
    await _storeQRData(_qrId!, selectedData, _qrExpiry!);
    
    setState(() {
      _qrData = selectedData;
      _showQRCode = true;
    });

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

  String _formatDataForQR(Map<String, String> data) {
    final lines = <String>[];
    for (var entry in data.entries) {
      lines.add('${entry.key}: ${entry.value}');
    }
    return lines.join('\n');
  }

  Future<void> _storeQRData(String id, Map<String, String> data, DateTime expiry) async {
    final prefs = await SharedPreferences.getInstance();
    final qrData = {
      'data': data,
      'expiry': expiry.toIso8601String(),
      'used': false,
      'card_type': widget.selectedCardType,
    };
    await prefs.setString('qr_$id', json.encode(qrData));
    _cleanupOldQRCodes();
  }

  Future<void> _invalidateQRCode(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('qr_$id');
  }

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
          await prefs.remove(key);
        }
      }
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

  String _getCardTypeDescription() {
    if (_isDigitalIDCard(widget.selectedCardType)) {
      return 'Digital ID';
    } else if (_isDigitalLicenseCard(widget.selectedCardType)) {
      return 'Digital License';
    } else {
      return widget.selectedCardType;
    }
  }

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

  double get _fontSizeTitle => _isSmallScreen ? 18.0 : (_isMediumScreen ? 20.0 : 22.0);
  double get _fontSizeBody => _isSmallScreen ? 14.0 : (_isMediumScreen ? 16.0 : 17.0);
  double get _fontSizeSmall => _isSmallScreen ? 12.0 : (_isMediumScreen ? 13.0 : 14.0);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final textColor = AppTheme.getTextPrimary(isDarkMode);
        
        // Get unique field names
        final uniqueFields = fieldSources.keys.toList()..sort();

        return Scaffold(
          backgroundColor: AppTheme.getBackgroundColor(isDarkMode),
          body: Container(
            decoration: BoxDecoration(gradient: AppTheme.getGradient(isDarkMode)),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _showQRCode ? _closeQRCode : () => Navigator.pop(context),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _showQRCode 
                                ? 'Share via QR'
                                : 'Select Info to Share',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
                      child: _isLoading 
                          ? _buildLoadingView(textColor)
                          : (_showQRCode ? _buildQRCodeView(isDarkMode, textColor) : _buildSelectionView(uniqueFields, isDarkMode, textColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingView(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your preferences...',
            style: TextStyle(
              fontSize: 16,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionView(List<String> uniqueFields, bool isDarkMode, Color textColor) {
    final secondaryTextColor = AppTheme.getTextSecondary(isDarkMode);

    return Column(
      children: [
        // Information header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(_isSmallScreen ? 16.0 : 20.0),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: AppTheme.getCardDecoration(isDarkMode),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isDigitalIDCard(widget.selectedCardType) 
                        ? Icons.perm_identity
                        : Icons.drive_eta,
                    color: AppTheme.primaryColor,
                    size: _fontSizeTitle,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getCardTypeDescription(),
                      style: TextStyle(
                        fontSize: _fontSizeTitle,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isDigitalIDCard(widget.selectedCardType)
                    ? 'Select the Digital ID information you want to share.'
                    : 'Select the Digital License information you want to share.',
                style: TextStyle(
                  fontSize: _fontSizeBody,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: _fontSizeSmall,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing only ${_getCardTypeDescription().toLowerCase()} fields',
                        style: TextStyle(
                          fontSize: _fontSizeSmall,
                          color: AppTheme.primaryColor,
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
              ? _buildGridView(uniqueFields, isDarkMode, textColor, secondaryTextColor)
              : _buildListView(uniqueFields, isDarkMode, textColor, secondaryTextColor),
        ),
        const SizedBox(height: 16),
        _buildActionButtons(context, isDarkMode, textColor),
      ],
    );
  }

  Widget _buildListView(List<String> uniqueFields, bool isDarkMode, Color textColor, Color secondaryTextColor) {
    return ListView(
      children: [
        for (var field in uniqueFields)
          _buildFieldItem(
            field,
            _getFieldValue(field),
            fieldSources[field]!,
            isDarkMode,
            textColor,
            secondaryTextColor,
          ),
      ],
    );
  }

  Widget _buildGridView(List<String> uniqueFields, bool isDarkMode, Color textColor, Color secondaryTextColor) {
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
          isDarkMode,
          textColor,
          secondaryTextColor,
        );
      },
    );
  }

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

  Widget _buildFieldItem(String fieldName, String fieldValue, List<String> sourceCards, bool isDarkMode, Color textColor, Color secondaryTextColor) {
    return Container(
      margin: EdgeInsets.symmetric(
        vertical: _isSmallScreen ? 4.0 : 6.0,
      ),
      decoration: AppTheme.getCardDecoration(isDarkMode),
      child: CheckboxListTile(
        title: Text(
          fieldName,
          style: TextStyle(
            fontSize: _fontSizeBody,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fieldValue,
              style: TextStyle(fontSize: _fontSizeSmall, color: secondaryTextColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Available in: ${_getSourcesDescription(sourceCards)}',
              style: TextStyle(
                fontSize: _fontSizeSmall - 2,
                color: secondaryTextColor.withOpacity(0.7),
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
          _saveSelectedFields();
        },
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppTheme.primaryColor,
        contentPadding: EdgeInsets.symmetric(
          horizontal: _isSmallScreen ? 16.0 : 20.0,
          vertical: _isSmallScreen ? 8.0 : 12.0,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDarkMode, Color textColor) {
    final selectedCount = selectedFields.values.where((value) => value).length;
    
    return Column(
      children: [
        if (selectedCount > 0)
          Container(
            padding: EdgeInsets.all(_isSmallScreen ? 12.0 : 16.0),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, 
                    size: _isSmallScreen ? 16 : 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$selectedCount ${_getCardTypeDescription().toLowerCase()} field${selectedCount > 1 ? 's' : ''} selected for sharing',
                    style: TextStyle(
                      fontSize: _fontSizeBody,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
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
                style: AppTheme.getOutlineButtonStyle(isDarkMode),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: _fontSizeBody, color: textColor),
                ),
              ),
            ),
            SizedBox(width: _isSmallScreen ? 16 : 20),
            Expanded(
              child: ElevatedButton(
                onPressed: selectedCount > 0 ? _generateQRCode : null,
                style: AppTheme.primaryButtonStyle.copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                     if (states.contains(WidgetState.disabled)) {
                       return isDarkMode ? Colors.grey[800] : Colors.grey[300];
                     }
                     return AppTheme.primaryColor;
                  }),
                ),
                child: Text(
                  'Generate QR Code',
                  style: TextStyle(fontSize: _fontSizeBody, color: Colors.black),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQRCodeView(bool isDarkMode, Color textColor) {
    final selectedFieldsCount = _qrData?.length ?? 0;
    final qrContent = _formatDataForQR(_qrData!);
    
    // QR Code background should be light to ensure scannability
    final qrBgColor = Colors.white;
    final qrTextColor = Colors.black;

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
              decoration: AppTheme.getCardDecoration(isDarkMode),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isDigitalIDCard(widget.selectedCardType) 
                            ? Icons.perm_identity
                            : Icons.drive_eta,
                        color: AppTheme.primaryColor,
                        size: _fontSizeTitle,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_getCardTypeDescription()} QR Code',
                        style: TextStyle(
                          fontSize: _fontSizeTitle,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer, size: _isSmallScreen ? 16 : 18, color: textColor.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Expires in: ${_getRemainingTime()}',
                        style: TextStyle(
                          fontSize: _fontSizeBody,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This QR can only be scanned once',
                    style: TextStyle(
                      fontSize: _fontSizeSmall,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // QR Code Container (Always light)
            Container(
              padding: EdgeInsets.all(_isSmallScreen ? 20.0 : 24.0),
              decoration: BoxDecoration(
                color: qrBgColor,
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
                    backgroundColor: qrBgColor,
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
              decoration: AppTheme.getCardDecoration(isDarkMode),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sharing ${_getCardTypeDescription()} Information ($selectedFieldsCount items):',
                    style: TextStyle(
                      fontSize: _fontSizeBody,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._qrData!.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '• ${entry.key}: ${entry.value}',
                      style: TextStyle(fontSize: _fontSizeSmall, color: textColor.withOpacity(0.8)),
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
              decoration: AppTheme.getCardDecoration(isDarkMode),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code contains ONLY your selected ${_getCardTypeDescription().toLowerCase()} data:',
                    style: TextStyle(
                      fontSize: _fontSizeBody,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        qrContent,
                        style: TextStyle(
                          fontSize: _fontSizeSmall,
                          fontFamily: 'Monospace',
                          color: textColor.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            _buildQRActionButtons(isDarkMode, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildQRActionButtons(bool isDarkMode, Color textColor) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _closeQRCode,
            style: AppTheme.getOutlineButtonStyle(isDarkMode),
            child: Text(
              'Close QR',
              style: TextStyle(fontSize: _fontSizeBody, color: textColor),
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
            style: AppTheme.primaryButtonStyle.copyWith(
               foregroundColor: WidgetStateProperty.all(Colors.black),
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