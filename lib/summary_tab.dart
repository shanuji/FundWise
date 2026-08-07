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

  Color _getValueColor(double? value) {
    if (value == null || value == 0.0) return Colors.grey;
    return value > 0.0 ? const Color(0xFF00BFA5) : Colors.redAccent;
  }

  String _formatCurrency(double? value) {
    if (value == null) return "N/A";
    return NumberFormat.currency(locale: "en_IN", symbol: "₹").format(value);
  }

  String _formatPercent(double? value) {
    if (value == null) return "N/A";
    String prefix = value > 0 ? "+" : "";
    return "$prefix${value.toStringAsFixed(2)}%";
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = (widget.portfolioSummary['current_portfolio_value'] as num?)?.toDouble();
    final totalProfit = (widget.portfolioSummary['total_profit'] as num?)?.toDouble();
    final netCapitalDeployed = (widget.portfolioSummary['total_capital_deployed'] as num?)?.toDouble();
    final statementReturn = (widget.portfolioSummary['statement_annualized_return'] as num?)?.toDouble();
    final benchmarkReturn = (widget.portfolioSummary['benchmark_annualized_return'] as num?)?.toDouble();
    
    String benchmarkText = "Benchmark Unavailable";
    if (benchmarkReturn != null) {
      benchmarkText = "Nifty 50: ${_formatPercent(benchmarkReturn)}";
    }

    final validFunds = widget.fundsList.where((fund) {
      final cVal = (fund['current_value'] as num?)?.toDouble();
      if (cVal == null || cVal < 1.0) return false;
      return true;
    }).toList();

    final sortedFunds = List.from(validFunds)..sort((a, b) {
      if (_sortOption == 'Alphabetical') {
        final nameA = (a['scheme_name'] ?? '').toString();
        final nameB = (b['scheme_name'] ?? '').toString();
        return nameA.compareTo(nameB);
      } else if (_sortOption == 'Profit') {
        final valA = (a['absolute_profit'] as num?)?.toDouble() ?? -999999999.0;
        final valB = (b['absolute_profit'] as num?)?.toDouble() ?? -999999999.0;
        return valB.compareTo(valA);
      } else if (_sortOption == 'Statement Return') {
        final valA = (a['statement_annualized_return'] as num?)?.toDouble() ?? -999999999.0;
        final valB = (b['statement_annualized_return'] as num?)?.toDouble() ?? -999999999.0;
        return valB.compareTo(valA);
      } else {
        final valA = (a['current_value'] as num?)?.toDouble() ?? -999999999.0;
        final valB = (b['current_value'] as num?)?.toDouble() ?? -999999999.0;
        return valB.compareTo(valA);
      }
    });

    Map<String, dynamic>? bestPerformer;
    if (sortedFunds.isNotEmpty) {
      final candidates = sortedFunds.where((fund) {
        return fund['statement_annualized_return'] != null;
      }).toList();

      if (candidates.isNotEmpty) {
        bestPerformer = candidates.reduce((curr, next) {
          final currReturn = (curr['statement_annualized_return'] as num?)?.toDouble() ?? -999999.0;
          final nextReturn = (next['statement_annualized_return'] as num?)?.toDouble() ?? -999999.0;
          return currReturn > nextReturn ? curr : next;
        });
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildPortfolioSnapshot(currentValue, totalProfit, netCapitalDeployed, statementReturn, benchmarkText),
        const SizedBox(height: 8),
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

  Widget _buildPortfolioSnapshot(double? currentValue, double? totalProfit, double? netCapitalDeployed, double? statementReturn, String benchmarkText) {
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
                    (totalProfit != null && totalProfit > 0) ? "+${_formatCurrency(totalProfit)}" : _formatCurrency(totalProfit),
                    style: TextStyle(color: _getValueColor(totalProfit), fontSize: 18, fontWeight: FontWeight.bold),
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
                    _formatPercent(statementReturn),
                    style: TextStyle(color: _getValueColor(statementReturn), fontSize: 15, fontWeight: FontWeight.w600),
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
    final fundName = fund['scheme_name']?.toString() ?? 'Unknown Fund';
    final returnPct = (fund['statement_annualized_return'] as num?)?.toDouble();
    final profit = (fund['absolute_profit'] as num?)?.toDouble();

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
                    Text(_formatPercent(returnPct), style: TextStyle(color: _getValueColor(returnPct), fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Profit", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text((profit != null && profit > 0) ? "+${_formatCurrency(profit)}" : _formatCurrency(profit), style: TextStyle(color: _getValueColor(profit), fontSize: 15, fontWeight: FontWeight.bold)),
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
    final fundName = fund['scheme_name']?.toString() ?? 'Unknown Fund';
    final openingVal = (fund['opening_value'] as num?)?.toDouble();
    final freshInvestments = (fund['fund_investments'] as num?)?.toDouble();
    final redemptions = (fund['fund_redemptions'] as num?)?.toDouble();
    final netCapital = (fund['capital_deployed'] as num?)?.toDouble();
    final currentVal = (fund['current_value'] as num?)?.toDouble();
    final profit = (fund['absolute_profit'] as num?)?.toDouble();
    final annReturn = (fund['statement_annualized_return'] as num?)?.toDouble();

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
                _buildMetric("Redemptions", _formatCurrency(redemptions), Colors.black87, crossAxisAlignment: CrossAxisAlignment.end),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric("Capital Deployed", _formatCurrency(netCapital), Colors.black87),
                _buildMetric("Profit", (profit != null && profit > 0) ? "+${_formatCurrency(profit)}" : _formatCurrency(profit), _getValueColor(profit)),
                _buildMetric("Statement Return", _formatPercent(annReturn), _getValueColor(annReturn), crossAxisAlignment: CrossAxisAlignment.end),
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
}
