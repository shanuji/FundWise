import 'dart:math' as math;

/// A cash-flow event used by the FundWise time-weighted return engine.
class FundCashFlow {
  final DateTime date;
  final double amount;
  final FundCashFlowType type;

  const FundCashFlow({
    required this.date,
    required this.amount,
    required this.type,
  });
}

enum FundCashFlowType {
  externalInvestment,
  externalRedemption,
  switchIn,
  switchOut,
  dividendPayout,
  dividendReinvestment,
  stampDuty,
}

class ReturnExposureSegment {
  final DateTime start;
  final DateTime end;
  final double exposure;

  const ReturnExposureSegment({
    required this.start,
    required this.end,
    required this.exposure,
  });

  int get days => end.difference(start).inDays;
}

class ReturnCalculation {
  final DateTime startDate;
  final DateTime endDate;
  final double weightedAverageCapital;
  final double absoluteGain;
  final double statementReturnPct;
  final double annualizedReturnPct;
  final List<ReturnExposureSegment> exposureSegments;
  final bool fullyRedeemed;

  const ReturnCalculation({
    required this.startDate,
    required this.endDate,
    required this.weightedAverageCapital,
    required this.absoluteGain,
    required this.statementReturnPct,
    required this.annualizedReturnPct,
    required this.exposureSegments,
    required this.fullyRedeemed,
  });
}

/// FundWise return methodology:
/// - Opening value is exposure from statement start.
/// - Investments increase exposure from their transaction date.
/// - Redemptions decrease exposure from their transaction date.
/// - Switches change exposure only at individual-fund level.
/// - Dividend payouts are wealth received, not fresh invested capital.
/// - Dividend reinvestments do not count as external capital.
/// - Stamp duty is a cost, not invested capital.
/// - A fully redeemed fund stops calculating on its full-redemption date.
class FundWiseReturnEngine {
  const FundWiseReturnEngine();

  ReturnCalculation calculate({
    required DateTime statementStart,
    required DateTime statementEnd,
    required double openingValue,
    required double closingValue,
    required List<FundCashFlow> cashFlows,
  }) {
    if (!statementEnd.isAfter(statementStart)) {
      throw ArgumentError('Statement end date must be after statement start date.');
    }
    if (openingValue < 0 || closingValue < 0) {
      throw ArgumentError('Opening and closing values cannot be negative.');
    }

    final sorted = [...cashFlows]
      ..sort((a, b) => a.date.compareTo(b.date));

    double exposure = openingValue;
    DateTime calculationEnd = statementEnd;
    bool fullyRedeemed = false;
    final effectiveFlows = <FundCashFlow>[];

    // First pass: identify the date on which the fund becomes fully redeemed.
    for (final flow in sorted) {
      if (flow.date.isBefore(statementStart) || flow.date.isAfter(statementEnd)) {
        continue;
      }

      switch (flow.type) {
        case FundCashFlowType.externalInvestment:
        case FundCashFlowType.switchIn:
        case FundCashFlowType.dividendReinvestment:
          exposure += flow.amount.abs();
          break;
        case FundCashFlowType.externalRedemption:
        case FundCashFlowType.switchOut:
          exposure -= flow.amount.abs();
          if (exposure <= 0.001) {
            calculationEnd = flow.date;
            fullyRedeemed = true;
            exposure = 0;
          }
          break;
        case FundCashFlowType.dividendPayout:
        case FundCashFlowType.stampDuty:
          break;
      }

      effectiveFlows.add(flow);
      if (fullyRedeemed) break;
    }

    final actualDays = calculationEnd.difference(statementStart).inDays;
    final denominatorDays = actualDays <= 0 ? 1 : actualDays;

    // Rebuild exposure segments only until the active end date.
    exposure = openingValue;
    DateTime segmentStart = statementStart;
    double weightedCapitalDays = 0;
    double externalInvestments = 0;
    double externalRedemptions = 0;
    double dividends = 0;
    double costs = 0;
    final segments = <ReturnExposureSegment>[];

    for (final flow in effectiveFlows) {
      if (flow.date.isBefore(statementStart) || flow.date.isAfter(calculationEnd)) {
        continue;
      }

      final eventDate = flow.date;
      if (eventDate.isAfter(segmentStart)) {
        weightedCapitalDays += exposure * eventDate.difference(segmentStart).inDays;
        segments.add(ReturnExposureSegment(
          start: segmentStart,
          end: eventDate,
          exposure: exposure,
        ));
        segmentStart = eventDate;
      }

      switch (flow.type) {
        case FundCashFlowType.externalInvestment:
          final amount = flow.amount.abs();
          externalInvestments += amount;
          exposure += amount;
          break;
        case FundCashFlowType.externalRedemption:
          final amount = flow.amount.abs();
          externalRedemptions += amount;
          exposure -= amount;
          if (exposure < 0) exposure = 0;
          break;
        case FundCashFlowType.switchIn:
          exposure += flow.amount.abs();
          break;
        case FundCashFlowType.switchOut:
          exposure -= flow.amount.abs();
          if (exposure < 0) exposure = 0;
          break;
        case FundCashFlowType.dividendPayout:
          dividends += flow.amount.abs();
          break;
        case FundCashFlowType.dividendReinvestment:
          // Reinvestment stays inside the fund and does not represent new
          // external capital. It therefore does not alter the denominator.
          break;
        case FundCashFlowType.stampDuty:
          costs += flow.amount.abs();
          break;
      }
    }

    if (calculationEnd.isAfter(segmentStart)) {
      weightedCapitalDays += exposure * calculationEnd.difference(segmentStart).inDays;
      segments.add(ReturnExposureSegment(
        start: segmentStart,
        end: calculationEnd,
        exposure: exposure,
      ));
    }

    final weightedAverageCapital = weightedCapitalDays / denominatorDays;
    final absoluteGain =
        closingValue + externalRedemptions + dividends -
        openingValue - externalInvestments - costs;

    final statementReturnPct = weightedAverageCapital > 0
        ? (absoluteGain / weightedAverageCapital) * 100
        : 0.0;

    final annualizationDays = calculationEnd.difference(statementStart).inDays;
    final safeDays = annualizationDays <= 0 ? 1 : annualizationDays;
    final base = 1 + statementReturnPct / 100;
    final annualizedReturnPct = base > 0
        ? (math.pow(base, 365 / safeDays) - 1) * 100
        : -100.0;

    return ReturnCalculation(
      startDate: statementStart,
      endDate: calculationEnd,
      weightedAverageCapital: weightedAverageCapital,
      absoluteGain: absoluteGain,
      statementReturnPct: statementReturnPct,
      annualizedReturnPct: annualizedReturnPct,
      exposureSegments: segments,
      fullyRedeemed: fullyRedeemed,
    );
  }
}
