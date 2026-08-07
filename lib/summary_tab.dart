import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryTab extends StatefulWidget {
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
  State<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<SummaryTab> {
  String _sortOption = 'Current Value';

  @override
  Widget build(BuildContext context) {
    // STRICT MAP: Exact keys from portfolio_summary only.
    final currentValue = (widget.portfolioSummary['current_portfolio_value'] ?? 0.0).toDouble();
    final totalProfit = (widget.portfolioSummary['total_profit'] ?? 0.0).toDouble();
    final netCapitalDeployed = (widget.portfolioSummary['total_capital_deployed'] ?? 0.0).toDouble();
    final statementReturn = (widget.portfolioSummary['statement_annualized_return'] ?? 0.0).toDouble();
    
    // BENCHMARK STRICT LOGIC
    final benchmarkReturn = widget.portfolioSummary['benchmark_annualized_return'];
    final benchmarkStatus = widget.portfolioSummary['benchmark_status']?.toString();
    String benchmarkText = "Benchmark Unavailable";
    if (benchmarkStatus == "Available" && benchmarkReturn != null) {
      benchmarkText = "Nifty 50: ${(benchmarkReturn as num).toDouble().toStringAsFixed(2)}%";
    }

    final validFunds = widget.fundsList.where((fund) {
      final cVal = (fund['current_value'] ?? 0.0).toDouble();
      final units = (fund['units'] ?? 0.0).toDouble();
      final isRedeemed = fund['is_fully_redeemed'] == true;
      return cVal >= 1.0 && units >= 0.001 && !isRedeemed;
    }).toList();

    // DYNAMIC SORTING
    final sortedFunds = List.from(validFunds)..sort((a, b) {
      if (_sortOption == 'Alphabetical') {
        final nameA = (a['scheme_name'] ?? '').toString();
        final nameB = (b['scheme_name'] ?? '').toString();
        return nameA.compareTo(nameB);
      } else if (_sortOption == 'Profit') {
        final valA = (a['absolute_profit'] ?? 0.0).toDouble();
        final valB = (b['absolute_profit'] ?? 0.0).toDouble();
        return valB.compareTo(valA);
      } else if (_sortOption == 'Statement Return') {
        final valA = (a['statement_annualized_return'] ?? 0.0).toDouble();
        final valB = (b['statement_annualized_return'] ?? 0.0).toDouble();
        return valB.compareTo(valA);
      } else {
        final valA = (a['current_value'] ?? 0.0).toDouble();
        final valB = (b['current_value'] ?? 0.0).toDouble();
        return valB.compareTo(valA);
      }
    });

    // BEST PERFORMER STRICT LOGIC (cVal >= 5000 & non-null return)
    Map<String, dynamic>? bestPerformer;
    if (sortedFunds.isNotEmpty) {
      final candidates = sortedFunds.where((fund) {
        final cVal = (fund['current_value'] ?? 0.0).toDouble();
        final ret = fund['statement_annualized_return'];
        return cVal >= 5000.0 && ret != null;
      }).toList();

      if (candidates.isNotEmpty) {
        bestPerformer = candidates.reduce((curr, next) {
          final currReturn = (curr['statement_annualized_return'] ?? -999.0).toDouble();
          final nextReturn = (next['statement_annualized_return'] ?? -999.0).toDouble();
          return currReturn > nextReturn ? curr : next;
        });
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildPortfolioSnapshot(currentValue, totalProfit, netCapitalDeployed, statementReturn, benchmarkText),
        const SizedBox(height: 8),
        // RENDER STATEMENT PERIOD
        Center(
          child: Text(
            "Statement Period: ${widget.statementPeriod}",
            style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
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
            // SORT DROPDOWN
            DropdownButton<String>(
              value: _sortOption,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
              style: TextStyle(fontSize: 12, color: Colors.deepPurple[400], fontWeight: FontWeight.bold),
              underline: const SizedBox(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _sortOption = newValue;
                  });
                }
              },
              items: <String>['Current Value', 'Profit', 'Statement Return', 'Alphabetical']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text("Sort by: $value"),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sortedFunds.map((fund) => _buildFundCard(fund)).toList(),
      ],
    );
  }

  Widget _buildPortfolioSnapshot(double currentValue, double totalProfit, double netCapitalDeployed, double statementReturn, String benchmarkText) {
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
              Text(benchmarkText, style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold)),
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
                    _formatCurrency(currentValue),
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
                    totalProfit > 0 ? "+${_formatCurrency(totalProfit)}" : _formatCurrency(totalProfit),
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
                  Text("Net Capital During Statement", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(netCapitalDeployed),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Statement Return", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    "${statementReturn.toStringAsFixed(2)}%",
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
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
    final fundName = fund['scheme_name'] ?? 'Unknown Fund';
    final returnPct = (fund['statement_annualized_return'] ?? 0.0).toDouble();
    final profit = (fund['absolute_profit'] ?? 0.0).toDouble();

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
                    const Text("Statement Return", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("+${returnPct.toStringAsFixed(2)}%", style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Profit", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(profit > 0 ? "+${_formatCurrency(profit)}" : _formatCurrency(profit), style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 15, fontWeight: FontWeight.bold)),
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
    final fundName = fund['scheme_name'] ?? 'Unknown Fund';
    final openingVal = (fund['opening_value'] ?? 0.0).toDouble();
    final freshInvestments = (fund['fund_investments'] ?? 0.0).toDouble();
    final redemptions = (fund['fund_redemptions'] ?? 0.0).toDouble();
    final netCapital = (fund['capital_deployed'] ?? 0.0).toDouble();
    final currentVal = (fund['current_value'] ?? 0.0).toDouble();
    final profit = (fund['absolute_profit'] ?? 0.0).toDouble();
    final annReturn = (fund['statement_annualized_return'] ?? 0.0).toDouble();

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
                Text(_formatCurrency(currentVal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric("Opening Value", _formatCurrency(openingVal), Colors.black87),
                _buildMetric("Fresh Investment", _formatCurrency(freshInvestments), Colors.black87),
                _buildMetric("Redemptions", _formatCurrency(redemptions), Colors.redAccent, crossAxisAlignment: CrossAxisAlignment.end),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric("Net Capital", _formatCurrency(netCapital), Colors.black87),
                _buildMetric("Profit", profit > 0 ? "+${_formatCurrency(profit)}" : _formatCurrency(profit), const Color(0xFF00BFA5)),
                _buildMetric("Statement Return", "${annReturn.toStringAsFixed(2)}%", const Color(0xFF00BFA5), crossAxisAlignment: CrossAxisAlignment.end),
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // EN_IN LOCALIZED CURRENCY FORMAT
  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: "en_IN", symbol: "₹").format(value);
  }
}
