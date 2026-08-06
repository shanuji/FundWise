import 'package:flutter/material.dart';

class HoldingsTab extends StatelessWidget {
  final Map<String, dynamic> portfolioSummary;
  final List<dynamic> fundsList;

  const HoldingsTab({
    Key? key,
    required this.portfolioSummary,
    required this.fundsList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (fundsList.isEmpty) return const Center(child: Text("No holdings data available."));

    final totalCurrentValue = (portfolioSummary['current_portfolio_value'] ?? portfolioSummary['current_value'] ?? 0.0).toDouble();

    final sortedFunds = List.from(fundsList)..sort((a, b) {
      final valA = (a['current_value'] ?? a['value'] ?? 0.0).toDouble();
      final valB = (b['current_value'] ?? b['value'] ?? 0.0).toDouble();
      return valB.compareTo(valA);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedFunds.length,
      itemBuilder: (context, index) {
        return _buildHoldingCard(sortedFunds[index], totalCurrentValue);
      },
    );
  }

  Widget _buildHoldingCard(Map<String, dynamic> fund, double totalPortfolioValue) {
    final fundName = fund['fund_name'] ?? fund['scheme'] ?? fund['scheme_name'] ?? fund['name'] ?? 'Unknown Fund';
    final currentValue = (fund['current_value'] ?? fund['value'] ?? 0.0).toDouble();
    final invested = (fund['invested_value'] ?? fund['invested'] ?? fund['total_invested'] ?? 0.0).toDouble();
    final profit = (fund['profit'] ?? fund['total_profit'] ?? fund['gain'] ?? 0.0).toDouble();
    final units = (fund['units'] ?? fund['closing_balance'] ?? fund['balance'] ?? fund['total_units'] ?? 0.0).toDouble();
    final nav = (fund['nav'] ?? fund['latest_nav'] ?? fund['current_nav'] ?? 0.0).toDouble();
    
    double allocationPct = totalPortfolioValue > 0 ? (currentValue / totalPortfolioValue) * 100 : 0.0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(fundName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text("${allocationPct.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: allocationPct / 100, backgroundColor: Colors.grey[100], color: Colors.deepPurple, minHeight: 6, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric("Invested", "₹${_formatCurrency(invested)}"),
                _buildMetric("Current Value", "₹${_formatCurrency(currentValue)}"),
                _buildMetric("Profit", "₹${_formatCurrency(profit)}", color: const Color(0xFF00BFA5), align: CrossAxisAlignment.end),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric("Total Units", units.toStringAsFixed(3)),
                _buildMetric("Latest NAV", "₹${_formatCurrency(nav)}", align: CrossAxisAlignment.end),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, {Color color = Colors.black87, CrossAxisAlignment align = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
