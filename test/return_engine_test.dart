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

  test('later investment gets only remaining time weight', () {
    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 100000,
      closingValue: 107000,
      events: [
        ReturnEvent(date: DateTime(2026, 5, 1), amount: 1000, type: ReturnEventType.investment),
        ReturnEvent(date: DateTime(2026, 6, 1), amount: 1000, type: ReturnEventType.investment),
        ReturnEvent(date: DateTime(2026, 7, 1), amount: 1000, type: ReturnEventType.investment),
      ],
    );
    expect(result.averageExposure, closeTo(102400, 1.0));
    expect(result.absoluteGain, closeTo(4000, 0.01));
    expect(result.statementReturnPct, closeTo(4000 / 102400 * 100, 0.01));
  });

  test('large redemption reduces exposure from redemption date', () {
    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 1000000,
      closingValue: 850000,
      events: [
        ReturnEvent(date: DateTime(2026, 8, 28), amount: 200000, type: ReturnEventType.redemption),
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
        ReturnEvent(date: redemptionDate, amount: 1100000, type: ReturnEventType.redemption),
      ],
    );
    expect(result.endedByFullRedemption, isTrue);
    expect(result.calculationEnd, redemptionDate);
    expect(result.statementReturnPct, closeTo(10.0, 0.01));
  });

  test('fund-level switch changes exposure but creates no external gain/loss', () {
    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 1000000,
      closingValue: 1050000,
      events: [
        ReturnEvent(date: DateTime(2026, 7, 1), amount: 400000, type: ReturnEventType.switchOut),
        ReturnEvent(date: DateTime(2026, 7, 1), amount: 400000, type: ReturnEventType.switchIn),
      ],
    );
    expect(result.averageExposure, closeTo(1000000, 0.01));
    expect(result.absoluteGain, closeTo(50000, 0.01));
  });

  test('portfolio switches do not change portfolio exposure', () {
    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 1000000,
      closingValue: 1050000,
      portfolioLevel: true,
      events: [
        ReturnEvent(date: DateTime(2026, 7, 1), amount: 400000, type: ReturnEventType.switchOut, internalTransfer: true),
        ReturnEvent(date: DateTime(2026, 7, 1), amount: 400000, type: ReturnEventType.switchIn, internalTransfer: true),
      ],
    );
    expect(result.averageExposure, closeTo(1000000, 0.01));
    expect(result.absoluteGain, closeTo(50000, 0.01));
  });

  test('partial portfolio redemption lowers exposure for the remainder', () {
    final result = FundWiseReturnEngine.calculate(
      statementStart: start,
      statementEnd: end,
      openingValue: 1000000,
      closingValue: 850000,
      portfolioLevel: true,
      events: [
        ReturnEvent(date: DateTime(2026, 8, 28), amount: 200000, type: ReturnEventType.redemption),
      ],
    );
    expect(result.averageExposure, closeTo(900000, 5000));
    expect(result.absoluteGain, closeTo(50000, 0.01));
  });
}
