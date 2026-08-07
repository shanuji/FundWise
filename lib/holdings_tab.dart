import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HoldingsTab extends StatefulWidget {
  final Map<String, dynamic> portfolioSummary;
  final List<dynamic> fundsList;

  const HoldingsTab({
    Key? key,
    required this.portfolioSummary,
    required this.fundsList,
  }) : super(key: key);

  @override
  State<HoldingsTab> createState() => _HoldingsTabState();
}

class _HoldingsTabState extends State<HoldingsTab> {
  String _sortOption = 'Current Value';

  Color _getValueColor(double? value) {
    if (value == null || value == 0.0) return Colors.grey;
    return value > 0.0 ? const Color(0xFF00BFA5) : Colors.redAccent;
  }

  String _formatCurrency(double? value) {
    if (value == null) return "N/A";
    return NumberFormat.currency(locale: "en_IN", symbol: "₹").format(value);
  }

  @override
  Widget build(BuildContext context) {
    final validFunds = widget.fundsList.where((fund) {
      final cVal = (fund['current_value'] as num?)?.toDouble();
      if (cVal == null || cVal < 1.0) return false;
      
      final unitsNum = fund['units'] as num?;
      if (unitsNum != null && unitsNum.toDouble() < 0.001) return false;

      return true;
    }).toList();

    if (validFunds.isEmpty) {
      return const Center(child: Text("No active holdings found."));
    }

    final totalCurrentValue = (widget.portfolioSummary['current_portfolio_value'] as num?)?.toDouble();

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Your Holdings",
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
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: sortedFunds.length,
            itemBuilder: (context, index) {
              return _buildHoldingCard(sortedFunds[index], totalCurrentValue);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHoldingCard(Map<String, dynamic> fund, double? totalPortfolioValue) {
    final fundName = fund['scheme_name']?.toString() ?? 'Unknown Fund';
    final currentVal = (fund['current_value'] as num?)?.toDouble();
    final profit = (fund['absolute_profit'] as num?)?.toDouble();
    final units = (fund['units'] as num?)?.toDouble();
    final nav = (fund['nav'] as num?)?.toDouble();
    
    double allocationPct = 0.0;
    if (totalPortfolioValue != null && totalPortfolioValue > 0 && currentVal != null) {
      allocationPct = (currentVal / totalPortfolioValue) * 100;
    }

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
                _buildMetric("Current Value", _formatCurrency(currentVal)),
                _buildMetric("Profit", (profit != null && profit > 0) ? "+${_formatCurrency(profit)}" : _formatCurrency(profit), color: _getValueColor(profit), align: CrossAxisAlignment.end),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric("Total Units", units != null ? units.toStringAsFixed(3) : "N/A"),
                _buildMetric("Latest NAV", _formatCurrency(nav), align: CrossAxisAlignment.end),
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
}
