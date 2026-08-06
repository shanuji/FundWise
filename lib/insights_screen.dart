import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    // Safely extract the required dictionaries and lists to pass down to the tabs
    final portfolioSummary = parsedData['portfolio_summary'] ?? {};
    final fundsList = parsedData['funds'] ?? parsedData['funds_breakdown'] ?? [];
    
    // Extract statement period for the Summary tab
    final statementPeriodInfo = portfolioSummary['statement_period'] ?? {};
    final fromDate = statementPeriodInfo['from']?.toString() ?? 'Unknown Date';
    final toDate = statementPeriodInfo['to']?.toString() ?? 'Unknown Date';
    final statementPeriod = "$fromDate to $toDate";

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
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.grey),
              onPressed: () {
                // Info tooltip placeholder
              },
            ),
          ],
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
