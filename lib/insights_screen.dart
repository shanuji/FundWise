import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'summary_tab.dart';
import 'cashflows_tab.dart';
import 'holdings_tab.dart';

class InsightsScreen extends StatelessWidget {
  final Map<String, dynamic> parsedData;
  final List<dynamic> transactions;

  const InsightsScreen({
    Key? key,
    required this.parsedData,
    required this.transactions,
  }) : super(key: key);

  String _formatDate(String dateStr) {
    if (dateStr == 'N/A' || dateStr.isEmpty) return 'N/A';
    try {
      final DateTime parsed = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy').format(parsed);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final portfolioSummary = parsedData['portfolio_summary'] ?? {};
    final fundsList = parsedData['funds_breakdown'] ?? [];
    
    final statementPeriodInfo = parsedData['statement_period'] ?? {};
    final fromDate = _formatDate(statementPeriodInfo['from']?.toString() ?? 'N/A');
    final toDate = _formatDate(statementPeriodInfo['to']?.toString() ?? 'N/A');
    final statementPeriod = "$fromDate – $toDate";

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            "Detailed Breakdown",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Summary"),
              Tab(text: "Cashflows"),
              Tab(text: "Holdings"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SummaryTab(
              portfolioSummary: portfolioSummary,
              fundsList: fundsList,
              statementPeriod: statementPeriod,
            ),
            CashflowsTab(
              transactions: transactions,
            ),
            HoldingsTab(
              portfolioSummary: portfolioSummary,
              fundsList: fundsList,
            ),
          ],
        ),
      ),
    );
  }
}
