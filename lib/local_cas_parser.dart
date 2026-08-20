import 'dart:io';

import 'package:flutter_pdf_text/flutter_pdf_text.dart';

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

    final openingResolved = funds.where((f) => f['opening_value_resolved'] == true).length;
    final openingComplete = funds.isNotEmpty && funds.every((f) => f['opening_value_resolved'] == true);
    final opening = funds.fold<double>(0, (s, f) => s + _num(f['opening_market_value']));
    final ending = funds.fold<double>(0, (s, f) => s + _num(f['ending_market_value']));
    final investments = _sumTransactions(transactions, {'PURCHASE', 'SIP'});
    final redemptions = _sumTransactions(transactions, {'REDEMPTION', 'SWP'});
    final switchIns = _sumTransactions(transactions, {'SWITCH_IN'});
    final switchOuts = _sumTransactions(transactions, {'SWITCH_OUT'});
    final dividends = _sumTransactions(transactions, {'DIVIDEND_PAYOUT'});
    final costs = _sumTransactions(transactions, {'STAMP_DUTY', 'STT_PAID'});

    return {
      'portfolio_summary': {
        'statement_period': {'from': _dateString(start), 'to': _dateString(end)},
        'opening_portfolio_value': openingComplete ? opening : null,
        'total_statement_investments': investments,
        'total_statement_redemptions': redemptions,
        'total_switch_ins': switchIns,
        'total_switch_outs': switchOuts,
        'total_dividend_payouts': dividends,
        'total_stamp_duty_costs': costs,
        'ending_portfolio_value': ending,
        'portfolio_return_status': openingComplete ? 'Complete' : 'Partial (Opening values unresolved)',
        'benchmark_status': 'Pending client-side calculation',
        'data_quality': {
          'status': openingComplete ? 'complete' : openingResolved > 0 ? 'partial' : 'unresolved',
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
    final header = block.take(block.length < 8 ? block.length : 8).join(' ');
    final firstLine = block.firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    final codeMatch = RegExp(r'^([A-Z0-9]{2,12})-').firstMatch(firstLine.trim());
    final code = codeMatch?.group(1) ?? '';
    final joined = block.join('\n');
    final isin = RegExp(r'ISIN:\s*([A-Z0-9]+)', caseSensitive: false).firstMatch(joined)?.group(1) ?? '';
    final name = _schemeName(header, code);

    final openingUnits = _firstNumber(joined, r'Opening Unit Balance:?\s*([\d,]+\.\d+)') ?? 0;
    final closingUnits = _firstNumber(joined, r'Closing Unit Balance:?\s*([\d,]+\.\d+)') ?? 0;
    final navMatch = RegExp(r'NAV on\s+(\d{2}-[A-Za-z]{3}-\d{4})\s*:\s*(?:INR\s*)?([\d,]+\.\d+)', caseSensitive: false).firstMatch(joined);
    final latestNav = navMatch == null ? 0.0 : _parseNumber(navMatch.group(2)!);
    final valuationDate = navMatch == null ? end : _parseDate(navMatch.group(1)!);
    final valuationMatch = RegExp(r'(?:Valuation|Market Value) on\s+\d{2}-[A-Za-z]{3}-\d{4}\s*:\s*(?:INR\s*)?([\d,]+\.\d+)', caseSensitive: false).firstMatch(joined);
    final marketValue = valuationMatch == null ? 0.0 : _parseNumber(valuationMatch.group(1)!);
    final totalCost = _firstNumber(joined, r'Total Cost Value:?\s*([\d,]+\.\d+)', caseSensitive: false) ?? 0;
    final txs = _parseTransactions(block, name, folio, start, end);

    double? openingValue;
    String resolutionPath;
    bool openingResolved;
    if (openingUnits <= 0) {
      openingValue = 0;
      resolutionPath = 'Zero opening units';
      openingResolved = true;
    } else {
      final result = await _navService.resolveOpeningValue(
        isin: isin,
        schemeName: name,
        openingUnits: openingUnits,
        statementStart: start,
      );
      openingValue = result.value;
      resolutionPath = result.path;
      openingResolved = result.value != null;
    }

    return _ParsedScheme(
      fund: {
        'scheme_name': name,
        'scheme_code': code,
        'isin': isin,
        'folio': folio,
        'opening_market_value': openingValue,
        'opening_value_resolved': openingResolved,
        'opening_units': openingUnits,
        'statement_investments': _sumTransactions(txs, {'PURCHASE', 'SIP'}),
        'statement_redemptions': _sumTransactions(txs, {'REDEMPTION', 'SWP'}),
        'switch_ins': _sumTransactions(txs, {'SWITCH_IN'}),
        'switch_outs': _sumTransactions(txs, {'SWITCH_OUT'}),
        'dividend_payouts': _sumTransactions(txs, {'DIVIDEND_PAYOUT'}),
        'stamp_duty_costs': _sumTransactions(txs, {'STAMP_DUTY', 'STT_PAID'}),
        'ending_market_value': marketValue,
        'units': closingUnits,
        'latest_nav': latestNav,
        'resolution_path': resolutionPath,
        'is_fully_redeemed': closingUnits < 0.001,
        'diagnostic_info': {
          'valuation_date': _dateString(valuationDate),
          'opening_resolved': openingResolved,
          'total_cost_value': totalCost,
        },
      },
      transactions: txs,
    );
  }

  List<Map<String, dynamic>> _parseTransactions(List<String> block, String scheme, String folio, DateTime start, DateTime end) {
    final rows = <Map<String, dynamic>>[];
    final dateLine = RegExp(r'^(\d{2}-[A-Za-z]{3}-\d{4})(?:\s+(.*))?$');

    for (var i = 0; i < block.length; i++) {
      final first = block[i].trim();
      final m = dateLine.firstMatch(first);
      if (m == null) continue;
      final date = _parseDate(m.group(1)!);
      if (date.isBefore(start) || date.isAfter(end)) continue;

      var description = (m.group(2) ?? '').trim();
      var j = i + 1;
      while (j < block.length && !dateLine.hasMatch(block[j].trim())) {
        final next = block[j].trim();
        if (next.startsWith('Closing Unit Balance') || next.startsWith('NAV on ') || next.startsWith('Valuation on ')) break;
        if (next.isNotEmpty) description = '$description $next'.replaceAll(RegExp(r'\s+'), ' ').trim();
        j++;
      }
      i = j - 1;

      final type = _normalize(description);
      if (type == 'IGNORED') continue;
      final amount = _extractAmount(description);
      if (amount == null || amount <= 0) continue;

      final numericFields = _decimalFieldsAfterFirstAmount(description);
      rows.add({
        'date': _dateString(date),
        'scheme_name': scheme,
        'folio': folio,
        'description': description,
        'normalized_type': type,
        'amount': amount,
        'units': numericFields.isNotEmpty ? numericFields[0] : 0.0,
        'nav': numericFields.length > 1 ? numericFields[1] : 0.0,
      });
    }
    return rows;
  }

  String _normalize(String description) {
    final c = description.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (c.contains('INVALID SWITCH') || c.contains('STPREGISTERED') || c.contains('UPDATION OF KYC')) return 'IGNORED';
    if (c.contains('STAMP') && c.contains('DUTY')) return 'STAMP_DUTY';
    if (c.contains('STT') && c.contains('PAID')) return 'STT_PAID';
    if (c.contains('DIVIDEND') && (c.contains('PAYOUT') || c.contains('TRANSFER') || c.contains('ISSUED'))) return 'DIVIDEND_PAYOUT';
    if ((c.contains('LATERAL SHIFT') || c.contains('SWITCH')) && c.contains('IN')) return 'SWITCH_IN';
    if ((c.contains('LATERAL SHIFT') || c.contains('SWITCH')) && c.contains('OUT')) return 'SWITCH_OUT';
    if (c.contains('SWP') || c.contains('REDEMPTION') || c.contains('SELL')) return 'REDEMPTION';
    if (c.contains('SIP') || c.contains('SYS. INVESTMENT') || c.contains('SYSTEMATIC INVESTMENT')) return 'SIP';
    if (c.contains('PURCHASE') || c.contains('LUMPSUM') || c.contains('ADDITIONAL') || c.contains('INITIAL PURCHASE') || c.contains('NFO')) return 'PURCHASE';
    return 'IGNORED';
  }

  static double? _extractAmount(String text) {
    final m = RegExp(r'\(?[\d,]+\.\d{2}\)?').firstMatch(text);
    return m == null ? null : _parseNumber(m.group(0)!);
  }

  static List<double> _decimalFieldsAfterFirstAmount(String text) {
    final first = RegExp(r'\(?[\d,]+\.\d{2}\)?').firstMatch(text);
    if (first == null) return const [];
    final rest = text.substring(first.end);
    return RegExp(r'\b\d+(?:,\d{3})*\.\d+\b').allMatches(rest).map((m) => _parseNumber(m.group(0)!)).take(3).toList();
  }

  List<int> _findHeaders(List<String> lines) {
    final result = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!_isLikelySchemeHeader(line)) continue;

      final end = i + 8 < lines.length ? i + 8 : lines.length;
      final window = lines.sublist(i, end).join(' ');
      if (RegExp(r'ISIN:\s*[A-Z0-9]+', caseSensitive: false).hasMatch(window) || RegExp(r'Opening Unit Balance', caseSensitive: false).hasMatch(window)) {
        result.add(i);
      }
    }
    return result;
  }

  bool _isLikelySchemeHeader(String line) {
    if (!RegExp(r'^[A-Z0-9]{2,12}-.+').hasMatch(line)) return false;

    final upper = line.toUpperCase();

    // These are common CAS metadata/transaction lines which can look like
    // scheme-code headers. In particular, KFintech's EOP-0008 distributor
    // metadata previously split a real scheme block and created a fake fund
    // named "1 EOP-0008)" with the next scheme's valuation.
    if (upper.contains('EOP-')) return false;
    if (upper.contains('DIRECT-CAT')) return false;
    if (upper.contains('BROKER CODE')) return false;
    if (upper.contains('SUB BROKER')) return false;
    if (upper.contains('DISTRIBUTOR')) return false;
    if (upper.contains('STAMP DUTY')) return false;
    if (upper.contains('STT PAID')) return false;

    // Page/transaction-table headings such as "Nov-2025 ... NAV ..."
    // must never become scheme boundaries.
    if (RegExp(r'^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)-\d{4}\b', caseSensitive: false).hasMatch(line)) return false;
    if (RegExp(r'^(DATE|AMOUNT|PRICE|UNITS|TRANSACTION)\b', caseSensitive: false).hasMatch(line)) return false;

    return true;
  }

  static String _schemeName(String header, String code) {
    var value = header.replaceFirst(RegExp('^${RegExp.escape(code)}-', caseSensitive: false), '');
    value = value.replaceFirst(RegExp(r'\s+Registrar\s*:.*$', caseSensitive: false), '');
    value = value.replaceFirst(RegExp(r'\s+ISIN\s*:.*$', caseSensitive: false), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.isEmpty ? 'Unknown Fund' : value;
  }

  static DateTime _parseDate(String value) {
    final p = value.split('-');
    const months = {'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12};
    return DateTime(int.parse(p[2]), months[p[1].toUpperCase()]!, int.parse(p[0]));
  }

  static String _dateString(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static double _parseNumber(String v) => double.tryParse(v.replaceAll(',', '').replaceAll('(', '').replaceAll(')', '').trim()) ?? 0;
  static double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
  static double? _firstNumber(String text, String pattern, {bool caseSensitive = false}) {
    final match = RegExp(pattern, caseSensitive: caseSensitive).firstMatch(text);
    return match == null ? null : _parseNumber(match.group(1)!);
  }
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
