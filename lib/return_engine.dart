import 'dart:math' as math;

/// FundWise statement-period return engine.
///
/// Returns are based on average capital exposure (capital-days), not XIRR.
/// Opening value is exposed from the statement start. Investments increase
/// exposure from their transaction date; redemptions reduce exposure from
/// their transaction date. Internal switches are ignored at portfolio level.
class ReturnEvent {
  final DateTime date;
  final double amount;
  final ReturnEventType type;
  final bool internalTransfer;

  const ReturnEvent({
    required this.date,
    required this.amount,
    required this.type,
    this.internalTransfer = false,
  });
}

enum ReturnEventType { investment, redemption, dividend, switchIn, switchOut }

class ReturnResult {
  final double absoluteGain;
  final double averageExposure;
  final double statementReturnPct;
  final double annualizedReturnPct;
  final DateTime calculationEnd;
  final bool endedByFullRedemption;

  const ReturnResult({
    required this.absoluteGain,
    required this.averageExposure,
    required this.statementReturnPct,
    required this.annualizedReturnPct,
    required this.calculationEnd,
    required this.endedByFullRedemption,
  });
}

class FundWiseReturnEngine {
  static ReturnResult calculate({
    required DateTime statementStart,
    required DateTime statementEnd,
    required double openingValue,
    required double closingValue,
    required List<ReturnEvent> events,
    double costs = 0,
    bool portfolioLevel = false,
  }) {
    final sorted = [...events]..sort((a, b) => a.date.compareTo(b.date));
    DateTime end = statementEnd;
    double exposure = openingValue;
    double externalInvestments = 0;
    double externalWithdrawals = 0;
    double weightedCapitalDays = 0;
    double dividends = 0;
    bool fullyRedeemed = false;
    DateTime cursor = statementStart;

    for (final event in sorted) {
      if (event.date.isBefore(statementStart) || event.date.isAfter(statementEnd)) continue;

      final isInternalPortfolioTransfer = portfolioLevel && event.internalTransfer;
      final days = event.date.difference(cursor).inDays;
      if (days > 0) weightedCapitalDays += exposure * days;
      cursor = event.date;

      if (isInternalPortfolioTransfer) continue;

      switch (event.type) {
        case ReturnEventType.investment:
          exposure += event.amount;
          externalInvestments += event.amount;
          break;
        case ReturnEventType.redemption:
          exposure = math.max(0, exposure - event.amount);
          externalWithdrawals += event.amount;
          if (!portfolioLevel && exposure <= 0) {
            end = event.date;
            fullyRedeemed = true;
          }
          break;
        case ReturnEventType.dividend:
          dividends += event.amount;
          break;
        case ReturnEventType.switchIn:
          exposure += event.amount;
          if (!portfolioLevel) externalInvestments += event.amount;
          break;
        case ReturnEventType.switchOut:
          exposure = math.max(0, exposure - event.amount);
          if (!portfolioLevel) externalWithdrawals += event.amount;
          if (!portfolioLevel && exposure <= 0) {
            end = event.date;
            fullyRedeemed = true;
          }
          break;
      }

      if (fullyRedeemed) break;
    }

    final finalDays = end.difference(cursor).inDays;
    if (finalDays > 0) weightedCapitalDays += exposure * finalDays;

    final periodDays = math.max(1, end.difference(statementStart).inDays);
    final averageExposure = weightedCapitalDays / periodDays;
    final effectiveClosingValue = fullyRedeemed ? 0.0 : closingValue;

    final absoluteGain = effectiveClosingValue +
        externalWithdrawals +
        dividends -
        openingValue -
        externalInvestments -
        costs;

    final statementReturn = averageExposure == 0
        ? 0.0
        : absoluteGain / averageExposure;
    final annualized = statementReturn <= -1
        ? -1.0
        : math.pow(1 + statementReturn, 365 / periodDays) - 1;

    return ReturnResult(
      absoluteGain: absoluteGain,
      averageExposure: averageExposure,
      statementReturnPct: statementReturn * 100,
      annualizedReturnPct: annualized * 100,
      calculationEnd: end,
      endedByFullRedemption: fullyRedeemed,
    );
  }
}
