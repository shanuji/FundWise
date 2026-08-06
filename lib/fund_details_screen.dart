import 'package:flutter/material.dart';

class FundDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> fund;
  final String statementPeriod;

  const FundDetailsScreen({
    Key? key,
    required this.fund,
    required this.statementPeriod,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final schemeName = fund['scheme_name'] ?? 'Unknown Fund';
    final returnPct = fund['statement_annualized_return'] ?? 0.0;
    final absoluteReturnPct = fund['absolute_return_pct'] ?? 0.0;
    final absoluteProfit = fund['absolute_profit'] ?? 0.0;
    final openingValue = fund['opening_value'] ?? 0.0;
    final capitalDeployed = fund['capital_deployed'] ?? 0.0;
    final currentValue = fund['current_value'] ?? 0.0;
    final resolutionPath = fund['resolution_path'] ?? 'N/A';
    
    // Future placeholder: extract category natively or from backend later
    final category = resolutionPath.toString().split(':').first;

    // Simple outperforming logic placeholder (e.g., > 12% is outperforming)
    final isOutperforming = returnPct > 12.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          schemeName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Hero Card
          _buildHeroCard(
            context: context,
            returnPct: returnPct,
            absoluteReturnPct: absoluteReturnPct,
            profit: absoluteProfit,
            isOutperforming: isOutperforming,
          ),
          const SizedBox(height: 20),

          // 2. Detailed Metrics Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildMetricRow("Opening Balance", "₹${_formatCurrency(openingValue)}"),
                  const Divider(height: 24),
                  _buildMetricRow("Capital Deployed", "₹${_formatCurrency(capitalDeployed)}"),
                  const Divider(height: 24),
                  _buildMetricRow("Current Value", "₹${_formatCurrency(currentValue)}", isBold: true),
                  const Divider(height: 24),
                  _buildMetricRow(
                    "Absolute Profit", 
                    "₹${_formatCurrency(absoluteProfit)}", 
                    valueColor: absoluteProfit >= 0 ? Colors.green : Colors.red,
                    isBold: true
                  ),
                  const Divider(height: 24),
                  _buildMetricRow("Statement Period", statementPeriod),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Future-Ready Placeholders Card
          Card(
            elevation: 1,
            color: Colors.blueGrey.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.blueGrey.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Additional Metadata",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMetricRow("Resolution Method", resolutionPath),
                  const SizedBox(height: 12),
                  _buildMetricRow("Fund Category", category),
                  const SizedBox(height: 12),
                  _buildMetricRow("Benchmark Return", "Nifty 50 TRI (Synced)"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard({
    required BuildContext context,
    required double returnPct,
    required double absoluteReturnPct,
    required double profit,
    required bool isOutperforming,
  }) {
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Statement Annualized Return",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOutperforming ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOutperforming ? "Outperforming" : "Underperforming",
                  style: TextStyle(
                    color: isOutperforming ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${returnPct.toStringAsFixed(2)}%",
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Absolute Return", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  Text("${absoluteReturnPct.toStringAsFixed(2)}%", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Net Profit", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  Text(
                    "₹${_formatCurrency(profit)}",
                    style: TextStyle(
                      color: profit >= 0 ? const Color(0xFF69F0AE) : const Color(0xFFFF5252),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.black87,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
