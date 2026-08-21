import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RedemptionHelperScreen extends StatelessWidget {
  final Map<String, dynamic> parsedData;
  final List<dynamic> transactions;

  const RedemptionHelperScreen({
    Key? key,
    required this.parsedData,
    required this.transactions,
  }) : super(key: key);

  String _currency(double value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(value);

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  bool _isInternalIn(Map<String, dynamic> tx) {
    final type = tx['normalized_type']?.toString().toUpperCase() ?? '';
    return type == 'SWITCH_IN';
  }

  bool _isInternalOut(Map<String, dynamic> tx) {
    final type = tx['normalized_type']?.toString().toUpperCase() ?? '';
    return type == 'SWITCH_OUT';
  }

  bool _isAcquisition(Map<String, dynamic> tx) {
    final type = tx['normalized_type']?.toString().toUpperCase() ?? '';
    return type == 'PURCHASE' || type == 'SIP' || _isInternalIn(tx);
  }

  @override
  Widget build(BuildContext context) {
    final funds = (parsedData['funds_breakdown'] as List?)
            ?.map((e) => Map<String, dynamic>.from((e as Map).cast<String, dynamic>()))
            .where((f) => _num(f['units']) > 0 && _num(f['ending_market_value']) > 0)
            .toList() ??
        <Map<String, dynamic>>[];

    final period = Map<String, dynamic>.from(
      ((parsedData['portfolio_summary'] as Map?) ?? const {}).cast<String, dynamic>(),
    );

    double ltcgValue = 0;
    double stcgValue = 0;
    double totalValue = 0;
    double ltcgUnits = 0;
    double stcgUnits = 0;

    final fundResults = <Map<String, dynamic>>[];

    for (final fund in funds) {
      final scheme = fund['scheme_name']?.toString() ?? 'Unknown Fund';
      final currentUnits = _num(fund['units']);
      final nav = _num(fund['latest_nav']);
      final fundValue = _num(fund['ending_market_value']);
      final fundTxs = transactions
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .where((tx) => tx['scheme_name']?.toString() == scheme && _isAcquisition(tx))
          .toList()
        ..sort((a, b) => (_date(a['date']) ?? DateTime(1900)).compareTo(_date(b['date']) ?? DateTime(1900)));

      // Approximate lot classification from transaction quantities. Current CAS parser
      // supplies units and NAV for acquisition rows. Redemptions are not silently ignored;
      // they are applied FIFO against acquisition lots for eligibility analysis.
      final lots = <Map<String, dynamic>>[];
      for (final tx in fundTxs) {
        final units = _num(tx['units']);
        if (units <= 0) continue;
        lots.add({
          'date': _date(tx['date']),
          'units': units,
          'remaining': units,
          'source': tx['normalized_type'],
          'amount': _num(tx['amount']),
        });
      }

      final exits = transactions
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .where((tx) => tx['scheme_name']?.toString() == scheme && (_isInternalOut(tx) || tx['normalized_type'] == 'REDEMPTION' || tx['normalized_type'] == 'SWP'))
          .toList()
        ..sort((a, b) => (_date(a['date']) ?? DateTime(1900)).compareTo(_date(b['date']) ?? DateTime(1900)));

      for (final exit in exits) {
        var remainingExit = _num(exit['units']);
        if (remainingExit <= 0) continue;
        for (final lot in lots) {
          if (remainingExit <= 0) break;
          final available = _num(lot['remaining']);
          final use = available < remainingExit ? available : remainingExit;
          lot['remaining'] = available - use;
          remainingExit -= use;
        }
      }

      DateTime? cutoff(DateTime? d) => d == null ? null : DateTime(d.year, d.month, d.day).add(const Duration(days: 365));
      final today = _date(period['to']) ?? DateTime.now();
      double eligibleUnits = 0;
      double shortUnits = 0;

      for (final lot in lots) {
        final remaining = _num(lot['remaining']);
        final acquired = lot['date'] as DateTime?;
        if (remaining <= 0 || acquired == null) continue;
        final isLong = !today.isBefore(cutoff(acquired)!);
        if (isLong) {
          eligibleUnits += remaining;
        } else {
          shortUnits += remaining;
        }
      }

      // Reconcile lot totals with current units when parser transaction-unit fields are incomplete.
      final lotTotal = eligibleUnits + shortUnits;
      if (lotTotal > 0 && (lotTotal - currentUnits).abs() > 0.01) {
        final scale = currentUnits / lotTotal;
        eligibleUnits *= scale;
        shortUnits *= scale;
      }

      final eligibleValue = eligibleUnits * nav;
      final shortValue = shortUnits * nav;
      ltcgUnits += eligibleUnits;
      stcgUnits += shortUnits;
      ltcgValue += eligibleValue;
      stcgValue += shortValue;
      totalValue += fundValue;

      fundResults.add({
        'scheme': scheme,
        'units': currentUnits,
        'value': fundValue,
        'ltcgUnits': eligibleUnits,
        'ltcgValue': eligibleValue,
        'stcgUnits': shortUnits,
        'stcgValue': shortValue,
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Redemption Helper', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: fundResults.isEmpty
          ? const Center(child: Text('Upload and analyse a CAS statement first.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Card(
                  elevation: 0,
                  color: const Color(0xFFF3EEFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Portfolio redemption view', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        Text('Current Value  ${_currency(totalValue)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _summaryMetric('12+ months', _currency(ltcgValue), '${ltcgUnits.toStringAsFixed(3)} units', Colors.teal)),
                            const SizedBox(width: 10),
                            Expanded(child: _summaryMetric('Under 12 months', _currency(stcgValue), '${stcgUnits.toStringAsFixed(3)} units', Colors.orange)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Fund-wise redemption eligibility', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...fundResults.map((f) => _fundCard(f)),
              ],
            ),
    );
  }

  Widget _summaryMetric(String title, String value, String units, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(units, style: const TextStyle(color: Colors.grey)),
      ]),
    );
  }

  Widget _fundCard(Map<String, dynamic> f) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f['scheme']?.toString() ?? 'Unknown Fund', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          Text('Total holding  ${_currency(_num(f['value']))}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Divider(height: 22),
          Row(children: [
            Expanded(child: _summaryMetric('LTCG eligible', _currency(_num(f['ltcgValue'])), '${_num(f['ltcgUnits']).toStringAsFixed(3)} units', Colors.teal)),
            const SizedBox(width: 10),
            Expanded(child: _summaryMetric('STCG', _currency(_num(f['stcgValue'])), '${_num(f['stcgUnits']).toStringAsFixed(3)} units', Colors.orange)),
          ]),
        ]),
      ),
    );
  }
}
