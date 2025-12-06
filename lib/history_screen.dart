import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),  // White
              Color(0xFFD6E6F2),  // Light blue
            ],
            stops: [0.1, 0.9],
          ),                  
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             
              const SizedBox(height: 20),
              
              // Police Officer Transaction
              _buildTransactionCard(
                title: 'Police Officer',
                userId: '1534 8762 9836 0937',
                date: '20/07/2025',
                time: '12.40 PM',
                data: 'Driving License',
              ),
              
              const SizedBox(height: 20),
              
              // Bank Officer Transaction
              _buildTransactionCard(
                title: 'Bank Officer',
                userId: '1534 8762 9836 0937',
                date: '20/07/2025',
                time: '12.40 PM',
                data: 'Digital ID',
              ),
              
              const SizedBox(height: 20),
              
              // Doctor Transaction
              _buildTransactionCard(
                title: 'Doctor',
                userId: '1534 8762 9836 0937',
                date: '20/07/2025',
                time: '12.40 PM',
                data: 'Medical Details',
              ),
              
              const SizedBox(height: 20),
              
              // Grama Niladari Transaction
              _buildTransactionCard(
                title: 'Grama Niladari',
                userId: '1534 8762 9836 0937',
                date: '20/07/2025',
                time: '12.40 PM',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard({
    required String title,
    required String userId,
    required String date,
    required String time,
    String? data,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(thickness: 1),
            _TransactionRow(label: 'User ID :', value: userId),
            _TransactionRow(label: 'Date :', value: date),
            _TransactionRow(label: 'Time :', value: time),
            if (data != null) _TransactionRow(label: 'Data :', value: data),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final String label;
  final String value;

  const _TransactionRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}