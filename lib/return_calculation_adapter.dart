import 'return_engine.dart';

Map<String, dynamic> applyFundWiseReturns(
  Map<String, dynamic> parsedData,
  List<dynamic> transactions,
) {
  final portfolio = Map<String, dynamic>.from(
    (parsedData['portfolio_summary'] as Map?)?.cast<String, dynamic>() ?? {},
  );
  final parsedFunds = ((parsedData['funds_breakdown'] as List?) ?? const [])
      .map((e) => Map<String, dynamic>.from((e as Map).cast<String, dynamic>()))
      .toList();

  // CAS PDF extraction can turn page/table headings into apparent scheme headers.
  // Never let those pseudo-funds reach the UI or return engine.
  final funds = parsedFunds.where((fund) {
    final name = fund['scheme_name']?.toString().trim() ?? '';
    return name.isNotEmpty && !_isSyntheticCasScheme(name);
  }).toList();

  final validSchemeNames = funds
      .map((f) => f['scheme_name']?.toString())
      .whereType<String>()
      .toSet();

  final period = Map<String, dynamic>.from(
    (portfolio['statement_period'] as Map?)?.cast<String, dynamic>() ?? {},
  );
  final start = _parseDate(period['from']);
  final end = _parseDate(period['to']);
  if (start == null || end == null) return parsedData;

  final txs = transactions.whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .where((tx) => validSchemeNames.contains(tx['scheme_name']?.toString()))
      .toList();

  for (final fund in funds) {
    final name = fund['scheme_name']?.toString();
    final openingRaw = fund['opening_market_value'];
    if (name == null || name.isEmpty) continue;

    if (openingRaw == null) {
      final openingUnits = _number(fund['opening_units']);
      if (openingUnits == 0) {
        fund['opening_market_value'] = 0.0;
      } else {
        fund['return_status'] = 'Unavailable — opening value could not be resolved.';
        continue;
      }
    }

    final events = <ReturnEvent>[];
    double costs = 0;

    for (final tx in txs) {
      if (tx['scheme_name']?.toString() != name) continue;
      final date = _parseDate(tx['date']);
      final amount = _number(tx['amount']).abs();
      if (date == null || amount == 0) continue;

      switch (tx['normalized_type']?.toString().toUpperCase()) {
        case 'PURCHASE':
        case 'SIP':
          events.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.investment));
          break;
        case 'REDEMPTION':
        case 'SWP':
          events.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.redemption));
          break;
        case 'SWITCH_IN':
          events.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.switchIn));
          break;
        case 'SWITCH_OUT':
          events.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.switchOut));
          break;
        case 'DIVIDEND_PAYOUT':
          events.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.dividend));
          break;
        case 'STAMP_DUTY':
        case 'STT_PAID':
          costs += amount;
          break;
      }
    }

    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: _number(fund['opening_market_value']),
      closingValue: _number(fund['ending_market_value']),
      events: events,
      costs: costs,
    );

    fund['net_wealth_gain'] = result.absoluteGain;
    fund['statement_return_pct'] = result.statementReturnPct;
    fund['statement_annualized_return'] = result.annualizedReturnPct;
    fund['average_capital_exposure'] = result.averageExposure;
    fund['return_calculation_end'] = _dateString(result.calculationEnd);
    fund['return_status'] = 'Complete';
    fund['return_calculation_note'] = result.endedByFullRedemption
        ? 'Calculation period ends on ${_dateString(result.calculationEnd)} due to full redemption.'
        : null;
  }

  final portfolioOpening = portfolio['opening_portfolio_value'];
  if (portfolioOpening == null) {
    portfolio['portfolio_return_status'] = 'Unavailable — one or more opening values could not be resolved.';
    return {
      ...parsedData,
      'portfolio_summary': portfolio,
      'funds_breakdown': funds,
    };
  }

  final portfolioEvents = <ReturnEvent>[];
  double portfolioCosts = 0;

  for (final tx in txs) {
    final date = _parseDate(tx['date']);
    final amount = _number(tx['amount']).abs();
    if (date == null || amount == 0) continue;

    switch (tx['normalized_type']?.toString().toUpperCase()) {
      case 'PURCHASE':
      case 'SIP':
        portfolioEvents.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.investment));
        break;
      case 'REDEMPTION':
      case 'SWP':
        portfolioEvents.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.redemption));
        break;
      case 'SWITCH_IN':
        portfolioEvents.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.switchIn, internalTransfer: true));
        break;
      case 'SWITCH_OUT':
        portfolioEvents.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.switchOut, internalTransfer: true));
        break;
      case 'DIVIDEND_PAYOUT':
        portfolioEvents.add(ReturnEvent(date: date, amount: amount, type: ReturnEventType.dividend));
        break;
      case 'STAMP_DUTY':
      case 'STT_PAID':
        portfolioCosts += amount;
        break;
    }
  }

  final portfolioResult = FundWiseReturnEngine.calculate(
    statementStart: start,
    statementEnd: end,
    openingValue: _number(portfolioOpening),
    closingValue: _number(portfolio['ending_portfolio_value']),
    events: portfolioEvents,
    costs: portfolioCosts,
    portfolioLevel: true,
  );

  portfolio['net_wealth_gain'] = portfolioResult.absoluteGain;
  portfolio['statement_return_pct'] = portfolioResult.statementReturnPct;
  portfolio['statement_annualized_return'] = portfolioResult.annualizedReturnPct;
  portfolio['average_capital_exposure'] = portfolioResult.averageExposure;
  portfolio['return_calculation_end'] = _dateString(portfolioResult.calculationEnd);
  portfolio['portfolio_return_status'] = 'Complete';

  return {
    ...parsedData,
    'portfolio_summary': portfolio,
    'funds_breakdown': funds,
    'transactions': txs,
  };
}

bool _isSyntheticCasScheme(String name) {
  final n = name.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (RegExp(r'^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)-\d{4}\b').hasMatch(n)) return true;
  if (RegExp(r'^\d+\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)-\d{4}\b').hasMatch(n)) return true;
  if (n.contains('PAGE ') && n.contains(' OF ') && n.contains('DATE') && n.contains('AMOUNT')) return true;
  if (n.contains('DATE AMOUNT') && n.contains('TRANSACTION')) return true;
  if (n.contains('PRICEUNITS') || n.contains('PRICE UNITS')) return true;
  return false;
}

DateTime? _parseDate(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
