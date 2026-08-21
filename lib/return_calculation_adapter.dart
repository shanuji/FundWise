import 'dart:developer' as developer;

import 'return_engine.dart';

Map<String, dynamic> applyFundWiseReturns(
  Map<String, dynamic> parsedData,
  List<dynamic> transactions,
) {
  final portfolio = Map<String, dynamic>.from(
    (parsedData['portfolio_summary'] as Map?)?.cast<String, dynamic>() ?? {},
  );

  final parsedFunds = ((parsedData['funds_breakdown'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
      .toList();

  // Preserve the existing page-header / pseudo-fund fix.
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

  // Do not drop valid transactions merely because the UI/parser may have an
  // exact scheme-name representation. Only retain transactions belonging to
  // actual parsed funds.
  final txs = transactions
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .where((tx) => validSchemeNames.contains(tx['scheme_name']?.toString()))
      .toList();

  // Rebuild the displayed external/internal flow fields from transaction
  // classification. Internal switches affect fund performance but are never
  // displayed as fresh investment or redemption.
  final externalInvestmentsByFund = <String, double>{};
  final externalRedemptionsByFund = <String, double>{};
  final switchInsByFund = <String, double>{};
  final switchOutsByFund = <String, double>{};

  for (final tx in txs) {
    final name = tx['scheme_name']?.toString();
    if (name == null) continue;
    final type = tx['normalized_type']?.toString().toUpperCase();
    final amount = _number(tx['amount']).abs();
    if (amount == 0) continue;
    switch (type) {
      case 'PURCHASE':
      case 'SIP':
        externalInvestmentsByFund[name] =
            (externalInvestmentsByFund[name] ?? 0) + amount;
        break;
      case 'REDEMPTION':
      case 'SWP':
        externalRedemptionsByFund[name] =
            (externalRedemptionsByFund[name] ?? 0) + amount;
        break;
      case 'SWITCH_IN':
        switchInsByFund[name] = (switchInsByFund[name] ?? 0) + amount;
        break;
      case 'SWITCH_OUT':
        switchOutsByFund[name] = (switchOutsByFund[name] ?? 0) + amount;
        break;
    }
  }

  for (final fund in funds) {
    final name = fund['scheme_name']?.toString();
    if (name == null || name.isEmpty) continue;

    final openingRaw = fund['opening_market_value'];
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
          events.add(ReturnEvent(
            date: date,
            amount: amount,
            type: ReturnEventType.investment,
          ));
          break;
        case 'REDEMPTION':
        case 'SWP':
          events.add(ReturnEvent(
            date: date,
            amount: amount,
            type: ReturnEventType.redemption,
          ));
          break;
        case 'SWITCH_IN':
          events.add(ReturnEvent(
            date: date,
            amount: amount,
            type: ReturnEventType.switchIn,
          ));
          break;
        case 'SWITCH_OUT':
          events.add(ReturnEvent(
            date: date,
            amount: amount,
            type: ReturnEventType.switchOut,
          ));
          break;
        case 'DIVIDEND_PAYOUT':
          events.add(ReturnEvent(
            date: date,
            amount: amount,
            type: ReturnEventType.dividend,
          ));
          break;
        case 'STAMP_DUTY':
        case 'STT_PAID':
          // Intentionally ignored for the displayed accounting metrics.
          // FundWise is a tentative analysis app, not an accounting ledger.
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

    fund['statement_investments'] = externalInvestmentsByFund[name] ?? 0.0;
    fund['statement_redemptions'] = externalRedemptionsByFund[name] ?? 0.0;
    fund['switch_ins'] = switchInsByFund[name] ?? 0.0;
    fund['switch_outs'] = switchOutsByFund[name] ?? 0.0;
    fund['fund_investments'] = externalInvestmentsByFund[name] ?? 0.0;
    fund['fund_redemptions'] = externalRedemptionsByFund[name] ?? 0.0;

    // For a tentative analysis app, "capital deployed" represents the
    // capital currently attributable to this fund after internal transfers,
    // not simply external purchases.
    final effectiveCapital = _number(fund['opening_market_value']) +
        (externalInvestmentsByFund[name] ?? 0.0) +
        (switchInsByFund[name] ?? 0.0) -
        (switchOutsByFund[name] ?? 0.0) -
        (externalRedemptionsByFund[name] ?? 0.0);

    fund['capital_deployed'] = effectiveCapital;
    fund['absolute_profit'] = result.absoluteGain;
    fund['net_wealth_gain'] = result.absoluteGain;
    fund['statement_return_pct'] = result.statementReturnPct;
    fund['statement_annualized_return'] = result.annualizedReturnPct;
    fund['average_capital_exposure'] = result.averageExposure;
    fund['return_calculation_end'] = _dateString(result.calculationEnd);
    fund['current_value'] = _number(fund['ending_market_value']);
    fund['units'] = _number(fund['units']);
    fund['nav'] = _number(fund['latest_nav']);
    fund['return_status'] = 'Complete';
    fund['return_calculation_note'] = result.endedByFullRedemption
        ? 'Calculation period ends on ${_dateString(result.calculationEnd)} due to full redemption.'
        : null;

    developer.log(
      'Fund: $name | opening=${_number(fund['opening_market_value'])} | '
      'externalInvestments=${externalInvestmentsByFund[name] ?? 0.0} | '
      'switchIns=${switchInsByFund[name] ?? 0.0} | '
      'externalRedemptions=${externalRedemptionsByFund[name] ?? 0.0} | '
      'switchOuts=${switchOutsByFund[name] ?? 0.0} | '
      'ending=${_number(fund['ending_market_value'])} | '
      'profit=${result.absoluteGain} | status=${fund['return_status']}',
      name: 'FundWise.CAS',
    );
  }

  // Recalculate portfolio market value from actual parsed scheme valuations.
  // This prevents any fund from disappearing from the total because a
  // downstream return/status calculation failed.
  final aggregatedEnding = funds.fold<double>(
    0.0,
    (sum, fund) => sum + _number(fund['ending_market_value']),
  );
  portfolio['ending_portfolio_value'] = aggregatedEnding;
  portfolio['current_portfolio_value'] = aggregatedEnding;

  final externalPortfolioInvestments = txs.fold<double>(
    0.0,
    (sum, tx) {
      final type = tx['normalized_type']?.toString().toUpperCase();
      if (type == 'PURCHASE' || type == 'SIP') {
        return sum + _number(tx['amount']).abs();
      }
      return sum;
    },
  );
  final externalPortfolioRedemptions = txs.fold<double>(
    0.0,
    (sum, tx) {
      final type = tx['normalized_type']?.toString().toUpperCase();
      if (type == 'REDEMPTION' || type == 'SWP') {
        return sum + _number(tx['amount']).abs();
      }
      return sum;
    },
  );
  final totalSwitchIns = txs.fold<double>(
    0.0,
    (sum, tx) => tx['normalized_type']?.toString().toUpperCase() == 'SWITCH_IN'
        ? sum + _number(tx['amount']).abs()
        : sum,
  );
  final totalSwitchOuts = txs.fold<double>(
    0.0,
    (sum, tx) => tx['normalized_type']?.toString().toUpperCase() == 'SWITCH_OUT'
        ? sum + _number(tx['amount']).abs()
        : sum,
  );

  portfolio['total_statement_investments'] = externalPortfolioInvestments;
  portfolio['total_statement_redemptions'] = externalPortfolioRedemptions;
  portfolio['total_switch_ins'] = totalSwitchIns;
  portfolio['total_switch_outs'] = totalSwitchOuts;
  portfolio['total_capital_deployed'] = _number(portfolio['opening_portfolio_value']) +
      externalPortfolioInvestments -
      externalPortfolioRedemptions;

  final portfolioOpening = portfolio['opening_portfolio_value'];
  if (portfolioOpening == null) {
    portfolio['portfolio_return_status'] =
        'Unavailable — one or more opening values could not be resolved.';
    return {
      ...parsedData,
      'portfolio_summary': portfolio,
      'funds_breakdown': funds,
      'transactions': txs,
    };
  }

  final portfolioEvents = <ReturnEvent>[];
  for (final tx in txs) {
    final date = _parseDate(tx['date']);
    final amount = _number(tx['amount']).abs();
    if (date == null || amount == 0) continue;

    switch (tx['normalized_type']?.toString().toUpperCase()) {
      case 'PURCHASE':
      case 'SIP':
        portfolioEvents.add(ReturnEvent(
          date: date,
          amount: amount,
          type: ReturnEventType.investment,
        ));
        break;
      case 'REDEMPTION':
      case 'SWP':
        portfolioEvents.add(ReturnEvent(
          date: date,
          amount: amount,
          type: ReturnEventType.redemption,
        ));
        break;
      case 'SWITCH_IN':
        portfolioEvents.add(ReturnEvent(
          date: date,
          amount: amount,
          type: ReturnEventType.switchIn,
          internalTransfer: true,
        ));
        break;
      case 'SWITCH_OUT':
        portfolioEvents.add(ReturnEvent(
          date: date,
          amount: amount,
          type: ReturnEventType.switchOut,
          internalTransfer: true,
        ));
        break;
      case 'DIVIDEND_PAYOUT':
        portfolioEvents.add(ReturnEvent(
          date: date,
          amount: amount,
          type: ReturnEventType.dividend,
        ));
        break;
    }
  }

  final portfolioResult = FundWiseReturnEngine.calculate(
    statementStart: start,
    statementEnd: end,
    openingValue: _number(portfolioOpening),
    closingValue: aggregatedEnding,
    events: portfolioEvents,
    portfolioLevel: true,
  );

  portfolio['net_wealth_gain'] = portfolioResult.absoluteGain;
  portfolio['total_profit'] = portfolioResult.absoluteGain;
  portfolio['statement_return_pct'] = portfolioResult.statementReturnPct;
  portfolio['statement_annualized_return'] = portfolioResult.annualizedReturnPct;
  portfolio['benchmark_annualized_return'] = portfolioResult.annualizedReturnPct;
  portfolio['average_capital_exposure'] = portfolioResult.averageExposure;
  portfolio['return_calculation_end'] = _dateString(portfolioResult.calculationEnd);
  portfolio['portfolio_return_status'] = 'Complete';
  portfolio['benchmark_status'] = portfolio['benchmark_status'] ?? 'Unavailable';

  developer.log(
    'Portfolio | opening=${_number(portfolioOpening)} | '
    'externalInvestments=$externalPortfolioInvestments | '
    'externalRedemptions=$externalPortfolioRedemptions | '
    'switchIns=$totalSwitchIns | switchOuts=$totalSwitchOuts | '
    'ending=$aggregatedEnding | profit=${portfolioResult.absoluteGain}',
    name: 'FundWise.CAS',
  );

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

DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
