import 'package:flutter/material.dart';
import 'dart:math' as math;

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
    final totalValue = portfolioSummary['current_portfolio_value'] ?? 0.0;
    final totalFunds = fundsList.length;
    final totalUnits = fundsList.fold<double>(0.0, (sum, fund) => sum + (fund['open_units'] ?? 0.0));

    // Sort funds by Current Value descending for allocation
    final sortedFunds = List.from(fundsList)..sort((a, b) => (b['current_value'] ?? 0.0).compareTo(a['current_value'] ?? 0.0));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Top Metrics Grid Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricColumn("Total Current Value", "₹${_formatCurrency(totalValue)}", CrossAxisAlignment.start),
                      _metricColumn("Total Funds", "$totalFunds", CrossAxisAlignment.end),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _metricColumn("Total Units", totalUnits.toStringAsFixed(3), CrossAxisAlignment.start),
                      _metricColumn("Day Change", "+₹0.00 (0.0%)", CrossAxisAlignment.end, valueColor: Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Allocation Donut Chart Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Holdings Allocation",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: CustomPaint(
                            size: const Size(140, 140),
                            painter: DonutChartPainter(funds: sortedFunds, totalValue: totalValue),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: sortedFunds.take(4).toList().asMap().entries.map((entry) {
                              int index = entry.key;
                              var fund = entry.value;
                              double allocation = totalValue > 0 ? ((fund['current_value'] ?? 0.0) / totalValue) * 100 : 0.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _getChartColor(index),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        fund['scheme_name'] ?? '',
                                        style: const TextStyle(fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      "${allocation.toStringAsFixed(1)}%",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. Detailed Holding Cards List
          const Text(
            "Portfolio Holdings",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...sortedFunds.map((fund) {
            double currentValue = fund['current_value'] ?? 0.0;
            double invested = fund['capital_deployed'] ?? 0.0;
            double profit = fund['absolute_profit'] ?? 0.0;
            double returnPct = fund['absolute_return_pct'] ?? 0.0;
            double allocation = totalValue > 0 ? (currentValue / totalValue) * 100 : 0.0;
            double units = fund['open_units'] ?? 0.0;
            double nav = units > 0 ? currentValue / units : 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            fund['scheme_name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "₹${_formatCurrency(currentValue)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(fund['resolution_path'] ?? 'Mutual Fund', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        Text("(${allocation.toStringAsFixed(1)}%)", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _subMetric("Units", units.toStringAsFixed(3)),
                        _subMetric("NAV", "₹${nav.toStringAsFixed(2)}"),
                        _subMetric("Invested", "₹${_formatCurrency(invested)}"),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _subMetric("Profit", "₹${_formatCurrency(profit)}", valueColor: Colors.green),
                        _subMetric("Return", "$returnPct%", valueColor: Colors.green),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _metricColumn(String label, String value, CrossAxisAlignment alignment, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black)),
      ],
    );
  }

  Widget _subMetric(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: valueColor ?? Colors.black87)),
      ],
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2);
  }

  Color _getChartColor(int index) {
    final colors = [
      const Color(0xFF3F51B5),
      const Color(0xFF009688),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    return colors[index % colors.length];
  }
}

class DonutChartPainter extends CustomPainter {
  final List<dynamic> funds;
  final double totalValue;

  DonutChartPainter({required this.funds, required this.totalValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24.0;

    double startAngle = -math.pi / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;

    if (totalValue <= 0) return;

    final colors = [
      const Color(0xFF3F51B5),
      const Color(0xFF009688),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];

    for (int i = 0; i < funds.length; i++) {
      double value = funds[i]['current_value'] ?? 0.0;
      double sweepAngle = (value / totalValue) * 2 * math.pi;

      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
