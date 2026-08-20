import 'dart:io';

import 'package:pdf_text/pdf_text.dart';

import 'fund_nav_service.dart';

class LocalCasParser {
  final FundNavService _navService;
  LocalCasParser({FundNavService? navService}) : _navService = navService ?? FundNavService();

  Future<Map<String, dynamic>> parseFile({required String path, String password = ''}) async {
    final document = await PDFDoc.fromFile(File(path), password: password);
    final text = await document.text;
    if (text.trim().isEmpty) throw Exception('The PDF contains no readable text.');

    final lines = text.replaceAll('\r', '').split('\n');
    final period = RegExp(r'(\d{2}-[A-Za-z]{3}-\d{4})\s+To\s+(\d{2}-[A-Za-z]{3}-\d{4})').firstMatch(text);
    if (period == null) throw Exception('Statement period could not be read from the CAS.');
    final start = _parseDate(period.group(1)!);
    final end = _parseDate(period.group(2)!);
    final headers = _findHeaders(lines);
    if (headers.isEmpty) throw Exception('No mutual-fund scheme sections were detected in the CAS.');

    var currentFolio = '';
    final funds = <Map<String, dynamic>>[];
    final transactions = <Map<String, dynamic>>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('Folio No:')) currentFolio = line.substring(9).trim();
      if (!headers.contains(i)) continue;
      final next = headers.firstWhereOrNull((v) => v > i);
      final block = lines.sublist(i, next ?? lines.length);
      final parsed = await _parseScheme(block, currentFolio, start, end);
      funds.add(parsed.fund);
      transactions.addAll(parsed.transactions);
    }

    final openingResolved = funds.where((f) => f['opening_market_value'] != null).length;
    final opening = funds.fold<double>(0, (s, f) => s + _num(f['opening_market_value']));
    final ending = funds.fold<double>(0, (s, f) => s + _num(f['ending_market_value']));
    final investments = _sumTransactions(transactions, {'PURCHASE', 'SIP', 'SWITCH_IN'});
    final redemptions = _sumTransactions(transactions, {'REDEMPTION', 'SWP', 'SWITCH_OUT'});
    final dividends = _sumTransactions(transactions, {'DIVIDEND_PAYOUT'});
    final costs = _sumTransactions(transactions, {'STAMP_DUTY', 'STT_PAID'});

    return {
      'portfolio_summary': {
        'statement_period': {'from': _dateString(start), 'to': _dateString(end)},
        'opening_portfolio_value': openingResolved == funds.length ? opening : null,
        'total_statement_investments': investments,
        'total_statement_redemptions': redemptions,
        'total_dividend_payouts': dividends,
        'total_stamp_duty_costs': costs,
        'ending_portfolio_value': ending,
        'portfolio_return_status': openingResolved == funds.length ? 'Complete' : 'Partial (Opening values unresolved)',
        'benchmark_status': 'Pending client-side calculation',
        'data_quality': {
          'status': openingResolved == funds.length ? 'complete' : openingResolved > 0 ? 'partial' : 'unresolved',
          'total_funds': funds.length,
          'resolved_funds': openingResolved,
          'coverage_percentage': funds.isEmpty ? 0.0 : openingResolved / funds.length * 100,
        },
      },
      'funds_breakdown': funds,
      'transactions': transactions,
    };
  }

  Future<_ParsedScheme> _parseScheme(List<String> block, String folio, DateTime start, DateTime end) async {
    final header = block.take(block.length < 3 ? block.length : 3).join(' ');
    final codeMatch = RegExp(r'^([A-Z0-9]{2,12})-').firstMatch(block.first.trim());
    final code = codeMatch?.group(1) ?? '';
    final isin = RegExp(r'ISIN:\s*([A-Z0-9]+)').firstMatch(header)?.group(1) ?? '';
    final name = _schemeName(header, code);
    final joined = block.join('\n');

    final openingUnits = _firstNumber(joined, r'Opening Unit Balance:\s*([\d,]+\.\d+)') ?? 0;
    final closingUnits = _firstNumber(joined, r'Closing Unit Balance:\s*([\d,]+\.\d+)') ?? 0;
    final navMatch = RegExp(r'NAV on\s+(\d{2}-[A-Za-z]{3}-\d{4}):\s*(?:INR\s*)?([\d,]+\.\d+)').firstMatch(joined);
    final latestNav = navMatch == null ? 0.0 : _parseNumber(navMatch.group(2)!);
    final valuationDate = navMatch == null ? end : _parseDate(navMatch.group(1)!);
    final marketValue = _firstNumber(joined, r'Market Value on[^:]*:\s*INR\s*([\d,]+\.\d+)') ?? 0;
    final totalCost = _firstNumber(joined, r'Total Cost Value:\s*([\d,]+\.\d+)') ?? 0;
    final txs = _parseTransactions(block, name, folio, start, end);

    double? openingValue;
    String resolutionPath;
    if (openingUnits == 0) {
      openingValue = 0;
      resolutionPath = 'Zero opening units';
    } else {
      final result = await _navService.resolveOpeningValue(
        isin: isin,
        schemeName: name,
        openingUnits: openingUnits,
        statementStart: start,
      );
      openingValue = result.value;
      resolutionPath = result.path;
    }

    return _ParsedScheme(
      fund: {
        'scheme_name': name,
        'scheme_code': code,
        'isin': isin,
        'folio': folio,
        'opening_market_value': openingValue,
        'statement_investments': _sumTransactions(txs, {'PURCHASE', 'SIP', 'SWITCH_IN'}),
        'statement_redemptions': _sumTransactions(txs, {'REDEMPTION', 'SWP', 'SWITCH_OUT'}),
        'dividend_payouts': _sumTransactions(txs, {'DIVIDEND_PAYOUT'}),
        'stamp_duty_costs': _sumTransactions(txs, {'STAMP_DUTY', 'STT_PAID'}),
        'ending_market_value': marketValue,
        'units': closingUnits,
        'latest_nav': latestNav,
        'resolution_path': resolutionPath,
        'is_fully_redeemed': closingUnits < 0.001,
        'diagnostic_info': {
          'valuation_date': _dateString(valuationDate),
          'opening_resolved': openingValue != null,
          'total_cost_value': totalCost,
        },
      },
      transactions: txs,
    );
  }

  List<Map<String, dynamic>> _parseTransactions(List<String> block, String scheme, String folio, DateTime start, DateTime end) {
    final rows = <Map<String, dynamic>>[];
    final dateLine = RegExp(r'^(\d{2}-[A-Za-z]{3}-\d{4})\s+(.*)$');
    final kind = RegExp(r'^(Switch-In|Switch Out|Sys\. Investment|Systematic Investment|Lateral Shift (Out|In)|\*\*\*\s*(Stamp Duty|STT Paid|Invalid Switch|STPRegistered))', caseSensitive: false);

    for (var i = 0; i < block.length; i++) {
      final m = dateLine.firstMatch(block[i].trim());
      if (m == null) continue;
      final date = _parseDate(m.group(1)!);
      if (date.isBefore(start) || date.isAfter(end)) continue;
      var description = m.group(2)!.trim();
      var j = i + 1;
      while (j < block.length && !dateLine.hasMatch(block[j].trim())) {
        final next = block[j].trim();
        if (next.startsWith('Closing Unit Balance:') || next.startsWith('NAV on ')) break;
        if (next.isNotEmpty) description = '$description $next'.replaceAll(RegExp(r'\s+'), ' ').trim();
        j++;
      }
      i = j - 1;
      if (!kind.hasMatch(description)) continue;
      final type = _normalize(description);
      if (type == 'IGNORED') continue;
      final amount = _extractAmount(description);
      if (amount == null) continue;
      rows.add({
        'date': _dateString(date),
        'scheme_name': scheme,
        'folio': folio,
        'description': description,
        'normalized_type': type,
        'amount': amount,
        'units': 0.0,
        'nav': 0.0,
      });
    }

    if (rows.isNotEmpty) return rows;
    return _columnarFallback(block, scheme, folio, start, end);
  }

  List<Map<String, dynamic>> _columnarFallback(List<String> block, String scheme, String folio, DateTime start, DateTime end) {
    final dates = <DateTime>[];
    final descriptions = <String>[];
    final amounts = <double>[];
    final dateOnly = RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}$');
    final money = RegExp(r'^\(?[\d,]+\.\d{2}\)?$');
    final kind = RegExp(r'^(Switch-In|Switch Out|Sys\. Investment|Systematic Investment|Lateral Shift (Out|In)|\*\*\*\s*(Stamp Duty|STT Paid|Invalid Switch|STPRegistered))', caseSensitive: false);

    for (final raw in block) {
      final line = raw.trim();
      if (dateOnly.hasMatch(line)) {
        final date = _parseDate(line);
        if (!date.isBefore(start) && !date.isAfter(end)) dates.add(date);
      } else if (kind.hasMatch(line)) {
        descriptions.add(line);
      } else if (money.hasMatch(line.replaceAll(' ', ''))) {
        amounts.add(_parseNumber(line).abs());
      }
    }

    final result = <Map<String, dynamic>>[];
    final count = dates.length < descriptions.length ? dates.length : descriptions.length;
    var amountIndex = 0;
    for (var i = 0; i < count; i++) {
      final type = _normalize(descriptions[i]);
      if (type == 'IGNORED' || amountIndex >= amounts.length) continue;
      result.add({
        'date': _dateString(dates[i]),
        'scheme_name': scheme,
        'folio': folio,
        'description': descriptions[i],
        'normalized_type': type,
        'amount': amounts[amountIndex++],
        'units': 0.0,
        'nav': 0.0,
      });
    }
    return result;
  }

  String _normalize(String description) {
    final c = description.toUpperCase();
    if (c.contains('INVALID SWITCH') || c.contains('STPREGISTERED')) return 'IGNORED';
    if (c.contains('STAMP DUTY')) return 'STAMP_DUTY';
    if (c.contains('STT PAID')) return 'STT_PAID';
    if (c.contains('DIVIDEND') && (c.contains('PAYOUT') || c.contains('TRANSFER') || c.contains('ISSUED'))) return 'DIVIDEND_PAYOUT';
    if (c.startsWith('LATERAL SHIFT IN') || c.startsWith('SWITCH-IN')) return 'SWITCH_IN';
    if (c.startsWith('LATERAL SHIFT OUT') || c.startsWith('SWITCH OUT')) return 'SWITCH_OUT';
    if (c.contains('SWP') || c.contains('REDEMPTION') || c.contains('SELL')) return 'REDEMPTION';
    if (c.contains('SIP') || c.contains('SYS. INVESTMENT') || c.contains('SYSTEMATIC INVESTMENT')) return 'SIP';
    if (c.contains('PURCHASE') || c.contains('LUMPSUM') || c.contains('ADDITIONAL')) return 'PURCHASE';
    return 'IGNORED';
  }

  static double? _extractAmount(String text) {
    final m = RegExp(r'\(?[\d,]+\.\d{2}\)?').firstMatch(text);
    return m == null ? null : _parseNumber(m.group(0)!);
  }

  List<int> _findHeaders(List<String> lines) {
    final result = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!RegExp(r'^[A-Z0-9]{2,12}-.+').hasMatch(line)) continue;
      final end = i + 3 < lines.length ? i + 3 : lines.length;
      if (lines.sublist(i, end).join(' ').contains('ISIN:')) result.add(i);
    }
    return result;
  }

  static String _schemeName(String header, String code) {
    var value = header.replaceFirst(RegExp('^${RegExp.escape(code)}-'), '');
    final index = value.toUpperCase().indexOf('- ISIN:');
    if (index >= 0) value = value.substring(0, index);
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static DateTime _parseDate(String value) {
    final p = value.split('-');
    const months = {'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12};
    return DateTime(int.parse(p[2]), months[p[1].toUpperCase()]!, int.parse(p[0]));
  }

  static String _dateString(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static double _parseNumber(String v) => double.tryParse(v.replaceAll(',', '').replaceAll('(', '').replaceAll(')', '').trim()) ?? 0;
  static double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  static double? _firstNumber(String text, String pattern) => RegExp(pattern, caseSensitive: false).firstMatch(text) == null ? null : _parseNumber(RegExp(pattern, caseSensitive: false).firstMatch(text)!.group(1)!);
  static double _sumTransactions(List<Map<String, dynamic>> txs, Set<String> types) => txs.where((t) => types.contains(t['normalized_type'])).fold<double>(0, (s, t) => s + _num(t['amount']).abs());
}

class _ParsedScheme {
  final Map<String, dynamic> fund;
  final List<Map<String, dynamic>> transactions;
  const _ParsedScheme({required this.fund, required this.transactions});
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
