import 'package:flutter/material.dart';

class SummaryTab extends StatelessWidget {
  final Map<String, dynamic> portfolioSummary;
  final List<dynamic> fundsList;
  final String statementPeriod;

  const SummaryTab({
    Key? key,
    required this.portfolioSummary,
    required this.fundsList,
    required this.statementPeriod,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // REMOVED ALL HARDCODED DUMMY DATA. Default is strictly 0.0.
    final currentValue = (portfolioSummary['current_portfolio_value'] ?? portfolioSummary['current_value'] ?? 0.0).toDouble();
    final totalProfit = (portfolioSummary['total_profit'] ?? portfolioSummary['profit'] ?? portfolioSummary['total_gains'] ?? 0.0).toDouble();
    final totalInvested = (portfolioSummary['total_capital_deployed'] ?? portfolioSummary['total_invested'] ?? portfolioSummary['invested_amount'] ?? 0.0).toDouble();
    final statementReturn = (portfolioSummary['statement_annualized_return'] ?? portfolioSummary['xirr'] ?? portfolioSummary['annualized_return'] ?? 0.0).toDouble();
    
    // RESTORED NIFTY BENCHMARK
    final benchmarkReturn = (portfolioSummary['benchmark_annualized_return'] ?? portfolioSummary['benchmark_return'] ?? 0.0).toDouble();

    final sortedFunds = List.from(fundsList)..sort((a, b) {
      final valA = (a['current_value'] ?? a['value'] ?? 0.0).toDouble();
      final valB = (b['current_value'] ?? b['value'] ?? 0.0).toDouble();
      return valB.compareTo(valA);
    });

    Map<String, dynamic>? bestPerformer;
    if (sortedFunds.isNotEmpty) {
      bestPerformer = sortedFunds.reduce((curr, next) {
        final currReturn = (curr['xirr'] ?? curr['annualized_return'] ?? curr['absolute_return'] ?? curr['cagr'] ?? 0.0).toDouble();
        final nextReturn = (next['xirr'] ?? next['annualized_return'] ?? next['absolute_return'] ?? next['cagr'] ?? 0.0).toDouble();
        return currReturn > nextReturn ? curr : next;
      });
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildPortfolioSnapshot(currentValue, totalProfit, totalInvested, statementReturn, benchmarkReturn),
        const SizedBox(height: 16),
        if (bestPerformer != null) _buildBestPerformer(bestPerformer),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Funds Breakdown",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            Text(
              "Sort by: Current Value ▾",
              style: TextStyle(fontSize: 12, color: Colors.deepPurple[400]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sortedFunds.map((fund) => _buildFundCard(fund)).toList(),
      ],
    );
  }

  Widget _buildPortfolioSnapshot(double currentValue, double totalProfit, double totalInvested, double statementReturn, double benchmarkReturn) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF5E35B1), Color(0xFF4527A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5E35B1).withOpacity(0.3),
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
              Text("Portfolio Snapshot", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              Text("Nifty 50: ${benchmarkReturn.toStringAsFixed(2)}%", style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Current Value", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    "₹${_formatCurrency(currentValue)}",
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Total Profit", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    "+₹${_formatCurrency(totalProfit)}",
                    style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.2), height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Invested", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    "₹${_formatCurrency(totalInvested)}",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Statement Return", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    "${statementReturn.toStringAsFixed(2)}%",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBestPerformer(Map<String, dynamic> fund) {
    final fundName = fund['fund_name'] ?? fund['scheme'] ?? fund['scheme_name'] ?? fund['name'] ?? 'Unknown Fund';
    final returnPct = (fund['xirr'] ?? fund['annualized_return'] ?? fund['absolute_return'] ?? fund['cagr'] ?? 0.0).toDouble();
    final profit = (fund['profit'] ?? fund['total_profit'] ?? fund['gain'] ?? fund['unrealized_profit'] ?? 0.0).toDouble();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Best Performer", style: TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(fundName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Return", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("+${returnPct.toStringAsFixed(2)}%", style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Profit", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("₹${_formatCurrency(profit)}", style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundCard(Map<String, dynamic> fund) {
    final fundName = fund['fund_name'] ?? fund['scheme'] ?? fund['scheme_name'] ?? fund['name'] ?? 'Unknown Fund';
    final currentValue = (fund['current_value'] ?? fund['value'] ?? 0.0).toDouble();
    final invested = (fund['invested_value'] ?? fund['invested'] ?? fund['total_invested'] ?? fund['cost_value'] ?? fund['amount'] ?? 0.0).toDouble();
    final profit = (fund['profit'] ?? fund['total_profit'] ?? fund['gain'] ?? fund['unrealized_profit'] ?? 0.0).toDouble();
    final returnPct = (fund['xirr'] ?? fund['annualized_return'] ?? fund['absolute_return'] ?? fund['cagr'] ?? fund['return'] ?? 0.0).toDouble();

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
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(fundName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text("₹${_formatCurrency(currentValue)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric("Invested", "₹${_formatCurrency(invested)}", Colors.black87),
                _buildMetric("Profit", "₹${_formatCurrency(profit)}", const Color(0xFF00BFA5)),
                _buildMetric("Return", "${returnPct.toStringAsFixed(2)}%", const Color(0xFF00BFA5), crossAxisAlignment: CrossAxisAlignment.end),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor, {CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
