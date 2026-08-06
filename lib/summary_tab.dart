import 'package:flutter/material.dart';
// Note: We will create FundDetailsScreen in the next step
// import 'fund_details_screen.dart'; 

class SummaryTab extends StatelessWidget {
  final Map<String, dynamic> portfolioSummary;
  final List<dynamic> fundsList;

  const SummaryTab({
    Key? key,
    required this.portfolioSummary,
    required this.fundsList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Sort funds by Current Value (highest first)
    final sortedFunds = List.from(fundsList)
      ..sort((a, b) => (b['current_value'] ?? 0.0).compareTo(a['current_value'] ?? 0.0));

    // Find Best Performer based on Annualized Return
    Map<String, dynamic>? bestPerformer;
    if (sortedFunds.isNotEmpty) {
      bestPerformer = sortedFunds.reduce((a, b) {
        final aReturn = a['statement_annualized_return'] ?? 0.0;
        final bReturn = b['statement_annualized_return'] ?? 0.0;
        return aReturn > bReturn ? a : b;
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Portfolio Snapshot Card
          _buildPortfolioSnapshot(context),
          const SizedBox(height: 16),

          // 2. Best Performer Highlight Card
          if (bestPerformer != null) _buildBestPerformerCard(context, bestPerformer),
          const SizedBox(height: 24),

          // 3. Funds Breakdown Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Funds Breakdown",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "Sort by: Current Value ▾",
                style: TextStyle(fontSize: 13, color: Theme.of(context).primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Sorted Fund Cards
          ...sortedFunds.map((fund) => _buildFundCard(context, fund)).toList(),
        ],
      ),
    );
  }

  Widget _buildPortfolioSnapshot(BuildContext context) {
    final currentValue = portfolioSummary['current_portfolio_value'] ?? 0.0;
    final totalProfit = portfolioSummary['total_profit'] ?? 0.0;
    final capitalDeployed = portfolioSummary['total_capital_deployed'] ?? 0.0;
    final statementReturn = portfolioSummary['statement_annualized_return'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5E35B1), Color(0xFF391E85)], // Premium Purple Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5E35B1).withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Portfolio Snapshot", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              Text("As of Live", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Current Value", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  Text("₹${_formatCurrency(currentValue)}", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Total Profit", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                  Text("+₹${_formatCurrency(totalProfit)}", style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.2), height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Invested", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  Text("₹${_formatCurrency(capitalDeployed)}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Statement Return", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  Text("${statementReturn.toStringAsFixed(2)}%", style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBestPerformerCard(BuildContext context, Map<String, dynamic> fund) {
    final schemeName = fund['scheme_name'] ?? 'Unknown Fund';
    final returnPct = fund['statement_annualized_return'] ?? 0.0;
    final profit = fund['absolute_profit'] ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // TODO: Navigate to Fund Details Screen
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Best Performer", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(schemeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Annualized Return", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text("+${returnPct.toStringAsFixed(2)}%", style: const TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Profit", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text("₹${_formatCurrency(profit)}", style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFundCard(BuildContext context, Map<String, dynamic> fund) {
    final schemeName = fund['scheme_name'] ?? 'Unknown Fund';
    final currentValue = fund['current_value'] ?? 0.0;
    final invested = fund['capital_deployed'] ?? 0.0;
    final profit = fund['absolute_profit'] ?? 0.0;
    final absoluteReturnPct = fund['absolute_return_pct'] ?? 0.0;
    
    // Future placeholder: extract category natively or from backend later
    final category = fund['resolution_path']?.toString().split(':').first ?? 'Mutual Fund';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // TODO: Navigate to Fund Details Screen
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(schemeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(category, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text("₹${_formatCurrency(currentValue)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniMetric("Invested", "₹${_formatCurrency(invested)}", Colors.black87),
                  _buildMiniMetric("Profit", "₹${_formatCurrency(profit)}", Colors.green),
                  _buildMiniMetric("Return", "${absoluteReturnPct.toStringAsFixed(2)}%", Colors.green, crossAxisAlignment: CrossAxisAlignment.end),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color valueColor, {CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatCurrency(double value) {
    // Simple formatting. For robust Indian Rupee formatting in Flutter, 
    // consider adding the `intl` package and using NumberFormat.currency(locale: 'en_IN')
    return value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
