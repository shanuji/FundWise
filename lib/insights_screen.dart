import 'package:flutter/material.dart';
import 'summary_tab.dart';
import 'cashflows_tab.dart';
import 'holdings_tab.dart';

class InsightsScreen extends StatelessWidget {
  // This expects the full JSON response map from your FastAPI backend
  final Map<String, dynamic> parsedData; 
  final List<dynamic> transactions; // Pass the flat list of transactions here

  const InsightsScreen({
    Key? key, 
    required this.parsedData,
    required this.transactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extract the main data blocks from your backend response
    final portfolioSummary = parsedData['portfolio_summary'] ?? {};
    final fundsList = parsedData['funds_breakdown'] ?? [];
    final statementPeriodInfo = parsedData['statement_period'] ?? {};
    final statementPeriod = "${statementPeriodInfo['from'] ?? ''} - ${statementPeriodInfo['to'] ?? ''}";

    return DefaultTabController(
      length: 3, // Summary, Cashflows, Holdings
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          title: const Text(
            "Detailed Breakdown",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.black54),
              onPressed: () {
                // TODO: Show info tooltip or dialog
              },
            )
          ],
          bottom: TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: const [
              Tab(text: "Summary"),
              Tab(text: "Cashflows"),
              Tab(text: "Holdings"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 1. Summary Tab
            SummaryTab(
              portfolioSummary: portfolioSummary,
              fundsList: fundsList,
              statementPeriod: statementPeriod,
            ),
            
            // 2. Cashflows Tab
            CashflowsTab(
              transactions: transactions,
            ),
            
            // 3. Holdings Tab
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
