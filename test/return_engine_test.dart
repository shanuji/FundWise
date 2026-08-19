import 'package:flutter_test/flutter_test.dart';
import 'package:fundwise/return_engine.dart';

void main() {
  final start = DateTime(2026, 4, 1);
  final end = DateTime(2027, 1, 26); // 300 days

  test('opening value only uses full statement exposure', () {
    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 100000,
      closingValue: 105000,
      events: const [],
    );

    expect(result.averageExposure, closeTo(100000, 0.01));
    expect(result.statementReturnPct, closeTo(5.0, 0.001));
  });

  test('large redemption reduces exposure from redemption date', () {
    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 1000000,
      closingValue: 850000,
      events: [
        ReturnEvent(
          date: DateTime(2026, 8, 28), // day 149/150 area
          amount: 200000,
          type: ReturnEventType.redemption,
        ),
      ],
    );

    expect(result.averageExposure, closeTo(900000, 5000));
    expect(result.absoluteGain, closeTo(50000, 0.01));
  });

  test('full redemption ends fund calculation at redemption date', () {
    final redemptionDate = DateTime(2026, 7, 10);
    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 1000000,
      closingValue: 0,
      events: [
        ReturnEvent(
          date: redemptionDate,
          amount: 1100000,
          type: ReturnEventType.redemption,
        ),
      ],
    );

    expect(result.endedByFullRedemption, isTrue);
    expect(result.calculationEnd, redemptionDate);
    expect(result.statementReturnPct, closeTo(10.0, 0.01));
  });

  test('portfolio switches do not change portfolio exposure', () {
    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 1000000,
      closingValue: 1050000,
      portfolioLevel: true,
      events: [
        ReturnEvent(
          date: DateTime(2026, 7, 1),
          amount: 400000,
          type: ReturnEventType.switchOut,
          internalTransfer: true,
        ),
        ReturnEvent(
          date: DateTime(2026, 7, 1),
          amount: 400000,
          type: ReturnEventType.switchIn,
          internalTransfer: true,
        ),
      ],
    );

    expect(result.averageExposure, closeTo(1000000, 0.01));
    expect(result.absoluteGain, closeTo(50000, 0.01));
  });
}
