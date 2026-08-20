import 'dart:io';
import 'dart:math' as math;

import 'package:pdf_text/pdf_text.dart';

import 'fund_nav_service.dart';

class LocalCasParser {
  final FundNavService _navService;

  LocalCasParser({FundNavService? navService}) : _navService = navService ?? FundNavService();

  Future<Map<String, dynamic>> parseFile({
    required String path,
    String password = '',
  }) async {
    final document = await PDFDoc.fromFile(File(path), password: password);
    final text = await document.text;
    if (text.trim().isEmpty) {
      throw Exception('The PDF contains no readable text.');
    }

    final lines = text.replaceAll('\r', '').split('\n');
    final periodMatch = RegExp(
      r'(\d{2}-[A-Za-z]{3}-\d{4})\s+To\s+(\d{2}-[A-Za-z]{3}-\d{4})',
    ).firstMatch(text);
    if (periodMatch == null) {
      throw Exception('Statement period could not be read from the CAS.');
    }
    final start = _parseDate(periodMatch.group(1)!);
    final end = _parseDate(periodMatch.group(2)!);

    final headers = _findSchemeHeaders(lines);
    if (headers.isEmpty) {
      throw Exception('No mutual-fund scheme sections were detected in the CAS.');
    }

    String currentFolio = '';
    final funds = <Map<String, dynamic>>[];
    final transactions = <Map<String, dynamic>>[];

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.startsWith('Folio No:')) {
        currentFolio = trimmed.substring('Folio No:'.length).trim();
      }
      final header = headers.firstWhereOrNull((h) => h.lineIndex == i);
      if (header == null) continue;

      final nextHeader = headers.firstWhereOrNull((h) => h.lineIndex > i);
      final blockEnd = nextHeader?.lineIndex ?? lines.length;
      final block = lines.sublist(i, blockEnd);
      final scheme = await _parseSchemeBlock(
        block: block,
        folio: currentFolio,
        statementStart: start,
        statementEnd: end,
      );
      funds.add(scheme.fund);
      transactions.addAll(scheme.transactions);
    }

    final opening = funds.fold<double>(
      0,
      (sum, fund) => sum + _number(fund['opening_market_value']),
    );
    final ending = funds.fold<double>(
      0,
      (sum, fund) => sum + _number(fund['ending_market_value']),
    );
    final investments = transactions.fold<double>(0, (sum, tx) {
      final type = tx['normalized_type']?.toString();
      return sum + ((type == 'PURCHASE' || type == 'SIP' || type == 'SWITCH_IN')
          ? _number(tx['amount']).abs()
          : 0);
    });
    final redemptions = transactions.fold<double>(0, (sum, tx) {
      final type = tx['normalized_type']?.toString();
      return sum + ((type == 'REDEMPTION' || type == 'SWP' || type == 'SWITCH_OUT')
          ? _number(tx['amount']).abs()
          : 0);
    });
    final dividends = transactions.fold<double>(0, (sum, tx) {
      return sum + (tx['normalized_type'] == 'DIVIDEND_PAYOUT' ? _number(tx['amount']).abs() : 0);
    });
    final costs = transactions.fold<double>(0, (sum, tx) {
      final type = tx['normalized_type']?.toString();
      return sum + ((type == 'STAMP_DUTY' || type == 'STT_PAID') ? _number(tx['amount']).abs() : 0);
    });
    final resolved = funds.where((f) => f['opening_market_value'] != null).length;

    return {
      'portfolio_summary': {
        'statement_period': {'from': _dateString(start), 'to': _dateString(end)},
        'opening_portfolio_value': resolved == funds.length ? opening : null,
        'total_statement_investments': investments,
        'total_statement_redemptions': redemptions,
        'total_dividend_payouts': dividends,
        'total_stamp_duty_costs': costs,
        'ending_portfolio_value': ending,
        'portfolio_return_status': resolved == funds.length ? 'Complete' : 'Partial (Opening values unresolved)',
        'benchmark_status': 'Pending client-side calculation',
        'data_quality': {
          'status': resolved == funds.length ? 'complete' : resolved > 0 ? 'partial' : 'unresolved',
          'total_funds': funds.length,
          'resolved_funds': resolved,
          'coverage_percentage': funds.isEmpty ? 0.0 : (resolved / funds.length) * 100,
        },
      },
      'funds_breakdown': funds,
      'transactions': transactions,
    };
  }

  Future<_ParsedScheme> _parseSchemeBlock({
    required List<String> block,
    required String folio,
    required DateTime statementStart,
    required DateTime statementEnd,
  }) async {
    final headerText = block.take(math.min(4, block.length)).join(' ');
    final codeMatch = RegExp(r'^([A-Z0-9]{2,12})-').firstMatch(block.first.trim());
    final schemeCode = codeMatch?.group(1) ?? '';
    final isin = RegExp(r'ISIN:\s*([A-Z0-9]+)').firstMatch(headerText)?.group(1) ?? '';
    final name = _schemeName(headerText, schemeCode);

    final joined = block.join('\n');
    final openingUnits = _firstNumber(joined, r'Opening Unit Balance:\s*([\d,]+\.\d+)');
    final closingUnits = _firstNumber(joined, r'Closing Unit Balance:\s*([\d,]+\.\d+)') ?? 0.0;
    final navMatch = RegExp(r'NAV on\s+(\d{2}-[A-Za-z]{3}-\d{4}):\s*(?:INR\s*)?([\d,]+\.\d+)').firstMatch(joined);
    final latestNav = navMatch == null ? 0.0 : _parseNumber(navMatch.group(2)!);
    final valuationDate = navMatch == null ? statementEnd : _parseDate(navMatch.group(1)!);
    final marketValue = _firstNumber(joined, r'Market Value on[^:]*:\s*INR\s*([\d,]+\.\d+)') ?? 0.0;
    final totalCost = _firstNumber(joined, r'Total Cost Value:\s*([\d,]+\.\d+)') ?? 0.0;

    final txs = _parseTransactions(block, name, folio, statementStart, statementEnd);
    double? openingValue;
    String resolutionPath;
    if ((openingUnits ?? 0) <= 0.000001) {
      openingValue = 0.0;
      resolutionPath = 'Zero opening units';
    } else {
      final resolved = await _navService.resolveOpeningValue(
        isin: isin,
        schemeName: name,
        openingUnits: openingUnits!,
        statementStart: statementStart,
      );
      openingValue = resolved.value;
      resolutionPath = resolved.path;
    }

    return _ParsedScheme(
      fund: {
        'scheme_name': name,
        'scheme_code': schemeCode,
        'isin': isin,
        'folio': folio,
        'opening_market_value': openingValue,
        'statement_investments': txs.where((t) => _isInvestment(t['normalized_type'])).fold<double>(0, (s, t) => s + _number(t['amount']).abs()),
        'statement_redemptions': txs.where((t) => _isRedemption(t['normalized_type'])).fold<double>(0, (s, t) => s + _number(t['amount']).abs()),
        'dividend_payouts': txs.where((t) => t['normalized_type'] == 'DIVIDEND_PAYOUT').fold<double>(0, (s, t) => s + _number(t['amount']).abs()),
        'stamp_duty_costs': txs.where((t) => t['normalized_type'] == 'STAMP_DUTY' || t['normalized_type'] == 'STT_PAID').fold<double>(0, (s, t) => s + _number(t['amount']).abs()),
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

  List<Map<String, dynamic>> _parseTransactions(
    List<String> block,
    String schemeName,
    String folio,
    DateTime start,
    DateTime end,
  ) {
    final result = <Map<String, dynamic>>[];
    final dateLine = RegExp(r'^(\d{2}-[A-Za-z]{3}-\d{4})\s+(.*)$');
    final transactionStart = RegExp(
      r'^(Switch-In|Switch Out|Sys\. Investment|Systematic Investment|Lateral Shift (Out|In)|\*\*\*\s*(Stamp Duty|STT Paid|Invalid Switch|STPRegistered))',
      caseSensitive: false,
    );

    for (var i = 0; i < block.length; i++) {
      final match = dateLine.firstMatch(block[i].trim());
      if (match == null) continue;
      final date = _parseDate(match.group(1)!);
      if (date.isBefore(start) || date.isAfter(end)) continue;

      var description = match.group(2)!.trim();
      var j = i + 1;
      while (j < block.length && !dateLine.hasMatch(block[j].trim())) {
        final next = block[j].trim();
        if (next.startsWith('Closing Unit Balance:') || next.startsWith('NAV on ')) break;
        if (next.isNotEmpty) description = '$description $next'.replaceAll(RegExp(r'\s+'), ' ').trim();
        j++;
      }
      i = j - 1;

      if (!transactionStart.hasMatch(description)) continue;
      final type = _normalize(description);
      if (type == 'IGNORED') continue;
      final amount = _extractAmount(description);
      if (amount == null) continue;
      result.add({
        'date': _dateString(date),
        'scheme_name': schemeName,
        'folio': folio,
        'description': description,
        'normalized_type': type,
        'amount': amount,
        'units': 0.0,
        'nav': 0.0,
      });
    }

    // Some PDF text extractors return the transaction and numeric columns separately.
    // If no rows were recovered, use the safer columnar fallback rather than silently
    // returning an empty transaction set.
    if (result.isEmpty && block.any((line) => line.contains('*** No transactions during this statement period ***'))) {
      return result;
    }
    if (result.isEmpty) {
      return _parseColumnarFallback(block, schemeName, folio, start, end);
    }
    return result;
  }

  List<Map<String, dynamic>> _parseColumnarFallback(
    List<String> block,
    String schemeName,
    String folio,
    DateTime start,
    DateTime end,
  ) {
    final dates = <DateTime>[];
    final descriptions = <String>[];
    final amounts = <double>[];
    final dateOnly = RegExp(r'^\d{2}-[A-Za-z]{3}-\d{4}$');
    final money = RegExp(r'^\(?[\d,]+\.\d{2}\)?$');
    final startDescription = RegExp(r'^(Switch-In|Switch Out|Sys\. Investment|Systematic Investment|Lateral Shift (Out|In)|\*\*\*\s*(Stamp Duty|STT Paid|Invalid Switch|STPRegistered))', caseSensitive: false);

    for (final raw in block) {
      final line = raw.trim();
      if (dateOnly.hasMatch(line)) {
        final d = _parseDate(line);
        if (!d.isBefore(start) && !d.isAfter(end)) dates.add(d);
      } else if (startDescription.hasMatch(line)) {
        descriptions.add(line);
      } else if (money.hasMatch(line.replaceAll(' ', ''))) {
        final n = _parseNumber(line);
        if (n.isFinite) amounts.add(n.abs());
      }
    }

    final usable = <Map<String, dynamic>>[];
    var amountIndex = 0;
    final count = math.min(dates.length, descriptions.length);
    for (var i = 0; i < count; i++) {
      final type = _normalize(descriptions[i]);
      if (type == 'IGNORED') continue;
      if (amountIndex >= amounts.length) break;
      final amount = amounts[amountIndex++];
      usable.add({
        'date': _dateString(dates[i]),
        'scheme_name': schemeName,
        'folio': folio,
        'description': descriptions[i],
        'normalized_type': type,
        'amount': amount,
        'units': 0.0,
        'nav': 0.0,
      });
    }
    return usable;
  }

  String _normalize(String description) {
    final c = description.toUpperCase();
    if (c.contains('INVALID SWITCH') || c.contains('STPREGISTERED')) return 'IGNORED';
    if (c.contains('STAMP DUTY')) return 'STAMP_DUTY';
    if (c.contains('STT PAID')) return 'STT_PAID';
    if (c.contains('DIVIDEND') && (c.contains('PAYOUT') || c.contains('TRANSFER') || c.contains('ISSUED'))) return 'DIVIDEND_PAYOUT';
    if (c.startsWith('LATERAL SHIFT IN')) return 'SWITCH_IN';
    if (c.startsWith('LATERAL SHIFT OUT')) return 'SWITCH_OUT';
    if (c.startsWith('SWITCH-IN')) return 'SWITCH_IN';
    if (c.startsWith('SWITCH OUT')) return 'SWITCH_OUT';
    if (c.contains('SWP') || c.contains('REDEMPTION') || c.contains('SELL')) return 'REDEMPTION';
    if (c.contains('SIP') || c.contains('SYS. INVESTMENT') || c.contains('SYSTEMATIC INVESTMENT')) return 'SIP';
    if (c.contains('PURCHASE') || c.contains('LUMPSUM') || c.contains('ADDITIONAL')) return 'PURCHASE';
    return 'IGNORED';
  }

  static double? _extractAmount(String description) {
    final matches = RegExp(r'\(?[\d,]+\.\d{2}\)?').allMatches(description);
    if (matches.isEmpty) return null;
    return _parseNumber(matches.first.group(0)!);
  }

  static String _schemeName(String header, String code) {
    var value = header.replaceFirst(RegExp('^${RegExp.escape(code)}-'), '');
    final isinIndex = value.toUpperCase().indexOf('- ISIN:');
    if (isinIndex >= 0) value = value.substring(0, isinIndex);
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<_SchemeHeader> _findSchemeHeaders(List<String> lines) {
    final result = <_SchemeHeader>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final match = RegExp(r'^([A-Z0-9]{2,12})-(.+)$').firstMatch(line);
      if (match == null) continue;
      final window = lines.sublist(i, math.min(lines.length, i + 3)).join(' ');
      if (!window.contains('ISIN:')) continue;
      result.add(_SchemeHeader(i));
    }
    return result;
  }

  static DateTime _parseDate(String value) {
    final parts = value.split('-');
    final months = const {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
    };
    return DateTime(int.parse(parts[2]), months[parts[1].toUpperCase()]!, int.parse(parts[0]));
  }

  static String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static double _parseNumber(String value) =>
      double.tryParse(value.replaceAll(',', '').replaceAll('(', '').replaceAll(')', '').trim()) ?? 0.0;

  static double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0.0;

  static double? _firstNumber(String text, String pattern) {
    final m = RegExp(pattern, caseSensitive: false).firstMatch(text);
    return m == null ? null : _parseNumber(m.group(1)!);
  }

  static bool _isInvestment(dynamic type) => const {'PURCHASE', 'SIP', 'SWITCH_IN'}.contains(type);
  static bool _isRedemption(dynamic type) => const {'REDEMPTION', 'SWP', 'SWITCH_OUT'}.contains(type);
}

class _SchemeHeader {
  final int lineIndex;
  const _SchemeHeader(this.lineIndex);
}

class _ParsedScheme {
  final Map<String, dynamic> fund;
  final List<Map<String, dynamic>> transactions;
  const _ParsedScheme({required this.fund, required this.transactions});
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
