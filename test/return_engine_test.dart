import 'package:flutter_test/flutter_test.dart';
import 'package:fundwise/return_engine.dart';

void main() {
  final engine = FundWiseReturnEngine();
  final start = DateTime(2026, 4, 1);
  final end = DateTime(2027, 1, 26); // 300 days after start.

  test('opening value only uses full statement exposure', () {
    final result = engine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 100000,
      closingValue: 105000,
      cashFlows: const [],
    );

    expect(result.weightedAverageCapital, closeTo(100000, 0.01));
    expect(result.absoluteGain, closeTo(5000, 0.01));
    expect(result.statementReturnPct, closeTo(5.0, 0.001));
  });

  test('large mid-period redemption reduces average exposure', () {
    final redemptionDate = start.add(const Duration(days: 100));
    final result = engine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 1000000,
      closingValue: 240000,
      cashFlows: [
        FundCashFlow(
          date: redemptionDate,
          amount: 800000,
          type: FundCashFlowType.externalRedemption,
        ),
      ],
    );

    expect(result.weightedAverageCapital, closeTo(466666.6667, 0.1));
    expect(result.absoluteGain, closeTo(40000, 0.01));
    expect(result.statementReturnPct, closeTo(8.5714286, 0.001));
    expect(result.fullyRedeemed, false);
  });

  test('full redemption stops calculation at redemption date', () {
    final redemptionDate = start.add(const Duration(days: 100));
    final result = engine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 1000000,
      closingValue: 0,
      cashFlows: [
        FundCashFlow(
          date: redemptionDate,
          amount: 1100000,
          type: FundCashFlowType.externalRedemption,
        ),
      ],
    );

    expect(result.fullyRedeemed, true);
    expect(result.endDate, redemptionDate);
    expect(result.weightedAverageCapital, closeTo(1000000, 0.01));
    expect(result.absoluteGain, closeTo(100000, 0.01));
    expect(result.statementReturnPct, closeTo(10.0, 0.001));
  });

  test('switch out and switch in preserve portfolio-level external capital concept', () {
    final fundA = engine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 100000,
      closingValue: 60000,
      cashFlows: [
        FundCashFlow(
          date: start.add(const Duration(days: 150)),
          amount: 40000,
          type: FundCashFlowType.switchOut,
        ),
      ],
    );

    final fundB = engine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 0,
      closingValue: 40000,
      cashFlows: [
        FundCashFlow(
          date: start.add(const Duration(days: 150)),
          amount: 40000,
          type: FundCashFlowType.switchIn,
        ),
      ],
    );

    expect(fundA.weightedAverageCapital, closeTo(80000, 0.01));
    expect(fundB.weightedAverageCapital, closeTo(20000, 0.01));
  });
}
