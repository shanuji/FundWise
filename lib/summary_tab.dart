import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'market_data_cache.dart';

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
  double? _benchmarkReturn;
  bool _benchmarkLoading = false;

  @override
  void initState() {
    super.initState();
    _benchmarkReturn = (widget.portfolioSummary['nifty_statement_return_pct'] as num?)?.toDouble();
    _loadBenchmark();
  }

  @override
  void didUpdateWidget(covariant SummaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPeriod = oldWidget.portfolioSummary['statement_period']?.toString();
    final newPeriod = widget.portfolioSummary['statement_period']?.toString();
    if (oldPeriod != newPeriod) {
      _benchmarkReturn = (widget.portfolioSummary['nifty_statement_return_pct'] as num?)?.toDouble();
      _loadBenchmark();
    }
  }

  Future<void> _loadBenchmark() async {
    final period = widget.portfolioSummary['statement_period'];
    if (period is! Map) return;

    final from = DateTime.tryParse(period['from']?.toString() ?? '');
    final to = DateTime.tryParse(period['to']?.toString() ?? '');
    if (from == null || to == null || to.isBefore(from)) return;

    if (mounted) setState(() => _benchmarkLoading = true);
    try {
      final history = await MarketDataCache.instance.niftyRange(from, to);
      if (history.isEmpty) return;

      final first = history.entries.first.value;
      final last = history.entries.last.value;
      if (first <= 0) return;

      final returnPct = ((last / first) - 1.0) * 100.0;
      if (!mounted) return;
      setState(() => _benchmarkReturn = returnPct);
    } catch (_) {
      // Benchmark is supplementary. A network/API failure must not affect
      // statement parsing, fund calculations, or any existing UI.
    } finally {
      if (mounted) setState(() => _benchmarkLoading = false);
    }
  }

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
    final prefix = value > 0 ? "+" : "";
    return "$prefix${value.toStringAsFixed(2)}%";
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = (widget.portfolioSummary['ending_portfolio_value'] as num?)?.toDouble();
    final totalProfit = (widget.portfolioSummary['net_wealth_gain'] as num?)?.toDouble();
    final freshInvestments = (widget.portfolioSummary['total_statement_investments'] as num?)?.toDouble();
    final statementReturn = (widget.portfolioSummary['statement_return_pct'] as num?)?.toDouble();
    final annualizedReturn = (widget.portfolioSummary['statement_annualized_return'] as num?)?.toDouble();
    final portfolioStatus = widget.portfolioSummary['portfolio_return_status']?.toString() ?? '';

    final benchmarkText = _benchmarkReturn != null
        ? "Nifty 50: ${_formatPercent(_benchmarkReturn)}"
        : (_benchmarkLoading ? "Nifty 50: Loading…" : "Benchmark Unavailable");

    final validFunds = widget.fundsList.toList();
    final sortedFunds = List.from(validFunds)..sort((a, b) {
      if (_sortOption == 'Alphabetical') {
        return (a['scheme_name'] ?? '').toString().compareTo((b['scheme_name'] ?? '').toString());
      }
      if (_sortOption == 'Profit') {
        final va = (a['net_wealth_gain'] as num?)?.toDouble() ?? -999999999.0;
        final vb = (b['net_wealth_gain'] as num?)?.toDouble() ?? -999999999.0;
        return vb.compareTo(va);
      }
      if (_sortOption == 'Statement Return') {
        final va = (a['statement_return_pct'] as num?)?.toDouble() ?? -999999999.0;
        final vb = (b['statement_return_pct'] as num?)?.toDouble() ?? -999999999.0;
        return vb.compareTo(va);
      }
      final va = (a['ending_market_value'] as num?)?.toDouble() ?? -999999999.0;
      final vb = (b['ending_market_value'] as num?)?.toDouble() ?? -999999999.0;
      return vb.compareTo(va);
    });

    Map<String, dynamic>? bestPerformer;
    final candidates = sortedFunds.where((fund) => fund['statement_return_pct'] != null).toList();
    if (candidates.isNotEmpty) {
      bestPerformer = candidates.reduce((curr, next) {
        final a = (curr['statement_return_pct'] as num?)?.toDouble() ?? -999999.0;
        final b = (next['statement_return_pct'] as num?)?.toDouble() ?? -999999.0;
        return a > b ? curr : next;
      });
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildPortfolioSnapshot(currentValue, totalProfit, freshInvestments, statementReturn, annualizedReturn, benchmarkText, portfolioStatus),
        const SizedBox(height: 8),
        Center(child: Text("Statement Period: ${widget.statementPeriod}", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500))),
        const SizedBox(height: 16),
        if (bestPerformer != null) _buildBestPerformer(bestPerformer),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Funds Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            DropdownButton<String>(
              value: _sortOption,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
              style: TextStyle(fontSize: 12, color: Colors.deepPurple[400], fontWeight: FontWeight.bold),
              underline: const SizedBox(),
              onChanged: (value) { if (value != null) setState(() => _sortOption = value); },
              items: ['Current Value', 'Profit', 'Statement Return', 'Alphabetical'].map((value) => DropdownMenuItem(value: value, child: Text("Sort by: $value"))).toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sortedFunds.map((fund) => _buildFundCard(fund)),
      ],
    );
  }

  Widget _buildPortfolioSnapshot(double? currentValue, double? totalProfit, double? freshInvestments, double? statementReturn, double? annualizedReturn, String benchmarkText, String portfolioStatus) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF5E35B1), Color(0xFF4527A0)], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: [BoxShadow(color: const Color(0xFF5E35B1).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Portfolio Snapshot", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)), Text(benchmarkText, style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold))]),
        if (portfolioStatus.isNotEmpty) ...[const SizedBox(height: 4), Text("Status: $portfolioStatus", style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic))],
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Current Value", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)), const SizedBox(height: 4), Text(_formatCurrency(currentValue), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("Total Profit", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)), const SizedBox(height: 4), Text((totalProfit != null && totalProfit > 0) ? "+${_formatCurrency(totalProfit)}" : _formatCurrency(totalProfit), style: TextStyle(color: _getValueColor(totalProfit), fontSize: 18, fontWeight: FontWeight.bold))]),
        ]),
        const SizedBox(height: 20),
        Divider(color: Colors.white.withOpacity(0.2), height: 1),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Fresh Investments", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)), const SizedBox(height: 4), Text(_formatCurrency(freshInvestments), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("Statement Return", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)), const SizedBox(height: 4), Text(_formatPercent(statementReturn), style: TextStyle(color: _getValueColor(statementReturn), fontSize: 15, fontWeight: FontWeight.w600))]),
        ]),
        if (annualizedReturn != null) ...[const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: Text("Annualized: ${_formatPercent(annualizedReturn)}", style: const TextStyle(color: Colors.white70, fontSize: 11)))],
      ]),
    );
  }

  Widget _buildBestPerformer(Map<String, dynamic> fund) {
    final fundName = fund['scheme_name']?.toString() ?? 'Unknown Fund';
    final returnPct = (fund['statement_return_pct'] as num?)?.toDouble();
    final profit = (fund['net_wealth_gain'] as num?)?.toDouble();
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)), color: Colors.white, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.emoji_events, color: Colors.amber, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Best Performer", style: TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold)), Text(fundName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)]))]),
      const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Statement Return", style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), Text(_formatPercent(returnPct), style: TextStyle(color: _getValueColor(returnPct), fontSize: 16, fontWeight: FontWeight.bold))]), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text("Profit", style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), Text((profit != null && profit > 0) ? "+${_formatCurrency(profit)}" : _formatCurrency(profit), style: TextStyle(color: _getValueColor(profit), fontSize: 15, fontWeight: FontWeight.bold))])]),
    ])));
  }

  Widget _buildFundCard(Map<String, dynamic> fund) {
    final fundName = fund['scheme_name']?.toString() ?? 'Unknown Fund';
    final openingVal = (fund['opening_market_value'] as num?)?.toDouble();
    final freshInvestments = (fund['statement_investments'] as num?)?.toDouble();
    final redemptions = (fund['statement_redemptions'] as num?)?.toDouble();
    final currentVal = (fund['ending_market_value'] as num?)?.toDouble();
    final profit = (fund['net_wealth_gain'] as num?)?.toDouble();
    final statementReturn = (fund['statement_return_pct'] as num?)?.toDouble();
    final annualizedReturn = (fund['statement_annualized_return'] as num?)?.toDouble();
    final stampDuty = (fund['stamp_duty_costs'] as num?)?.toDouble() ?? 0.0;
    final note = fund['return_calculation_note']?.toString();

    return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)), color: Colors.white, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(fundName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Text(_formatCurrency(currentVal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildMetric("Opening Value", _formatCurrency(openingVal), Colors.black87), _buildMetric("Fresh Investment", _formatCurrency(freshInvestments), Colors.black87), _buildMetric("Redemptions", _formatCurrency(redemptions), Colors.black87, crossAxisAlignment: CrossAxisAlignment.end)]),
      if (stampDuty > 0) ...[const SizedBox(height: 8), Text("Stamp Duty Cost: ${_formatCurrency(stampDuty)}", style: TextStyle(color: Colors.grey[600], fontSize: 11))],
      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildMetric("Fresh Investment", _formatCurrency(freshInvestments), Colors.black87), _buildMetric("Profit", (profit != null && profit > 0) ? "+${_formatCurrency(profit)}" : _formatCurrency(profit), _getValueColor(profit)), _buildMetric("Statement Return", _formatPercent(statementReturn), _getValueColor(statementReturn), crossAxisAlignment: CrossAxisAlignment.end)]),
      if (annualizedReturn != null) Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: Alignment.centerRight, child: Text("Annualized: ${_formatPercent(annualizedReturn)}", style: TextStyle(color: Colors.grey[600], fontSize: 11)))),
      if (note != null && note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, size: 14, color: Colors.grey[600]), const SizedBox(width: 6), Expanded(child: Text(note, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic)))])),
    ])));
  }

  Widget _buildMetric(String label, String value, Color valueColor, {CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start}) => Column(crossAxisAlignment: crossAxisAlignment, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height: 4), Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold))]);
}
