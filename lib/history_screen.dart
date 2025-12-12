// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_project/api_service.dart';
import 'package:new_project/app_theme.dart';
import 'package:new_project/theme_provider.dart';
import '../models/presentation_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<PresentationHistory> _transactions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.getPresentationHistory();

      if (mounted) {
        if (response.success && response.data != null) {
          setState(() {
            _transactions = response.data!;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = response.message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load history: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshHistory() async {
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final textColor = AppTheme.getTextPrimary(isDarkMode);
        final secondaryTextColor = AppTheme.getTextSecondary(isDarkMode);

        return Scaffold(
          backgroundColor: AppTheme.getBackgroundColor(isDarkMode),
          body: Container(
            decoration: BoxDecoration(gradient: AppTheme.getGradient(isDarkMode)),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transaction History',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.refresh_rounded, color: textColor),
                            onPressed: _refreshHistory,
                            tooltip: 'Refresh',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingState(textColor, secondaryTextColor)
                        : _errorMessage.isNotEmpty
                            ? _buildErrorState(textColor, secondaryTextColor)
                            : _transactions.isEmpty
                                ? _buildEmptyState(textColor, secondaryTextColor)
                                : RefreshIndicator(
                                    onRefresh: _refreshHistory,
                                    child: _buildHistoryList(isDarkMode, textColor, secondaryTextColor),
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

  Widget _buildLoadingState(Color textColor, Color secondaryTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading transaction history...',
            style: TextStyle(
              fontSize: 16,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color textColor, Color secondaryTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to load history',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadHistory,
              style: AppTheme.primaryButtonStyle,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color secondaryTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 64,
            color: secondaryTextColor.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your shared data history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(bool isDarkMode, Color textColor, Color secondaryTextColor) {
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildTransactionCard(_transactions[index], isDarkMode, textColor, secondaryTextColor);
      },
    );
  }

  Widget _buildTransactionCard(PresentationHistory transaction, bool isDarkMode, Color textColor, Color secondaryTextColor) {
    return Container(
      decoration: AppTheme.getCardDecoration(isDarkMode),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    transaction.requesterName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: transaction.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: transaction.statusColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    transaction.statusDisplay,
                    style: TextStyle(
                      color: transaction.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            Divider(thickness: 1, color: secondaryTextColor.withOpacity(0.2)),
            _TransactionRow(
              label: 'Session ID :',
              value: transaction.sessionId,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            _TransactionRow(
              label: 'Requester ID :',
              value: transaction.requesterId,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            _TransactionRow(
              label: 'Date :',
              value: transaction.formattedDate,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            _TransactionRow(
              label: 'Time :',
              value: transaction.formattedTime,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            _TransactionRow(
              label: 'Purpose :',
              value: transaction.purpose,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
            ),
            if (transaction.requestedAttributes.isNotEmpty)
              _TransactionRow(
                label: 'Requested :',
                value: transaction.requestedAttributes.join(', '),
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            if (transaction.sharedAttributes.isNotEmpty)
              _TransactionRow(
                label: 'Shared Data :',
                value: transaction.sharedDataSummary,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
            if (transaction.fulfilledAt != null)
              _TransactionRow(
                label: 'Shared On :',
                value: '${transaction.fulfilledAt!.day}/${transaction.fulfilledAt!.month}/${transaction.fulfilledAt!.year} ${transaction.fulfilledAt!.hour.toString().padLeft(2, '0')}:${transaction.fulfilledAt!.minute.toString().padLeft(2, '0')}',
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color secondaryTextColor;

  const _TransactionRow({
    required this.label,
    required this.value,
    required this.textColor,
    required this.secondaryTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.9),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}