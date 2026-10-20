import 'package:flutter_test/flutter_test.dart';
import 'package:equity_basket/main.dart';

Trade makeTrade({
  required String id,
  required String basket,
  required String symbol,
  required String side,
  required double quantity,
  required DateTime date,
}) => Trade(id, basket, symbol, side, quantity, 100, 0, date);

void main() {
  test('accepts partial sells followed by a later buy', () {
    final ledger = [
      makeTrade(id: '1', basket: 'core', symbol: 'ABC', side: 'BUY', quantity: 10, date: DateTime(2026, 1, 1)),
      makeTrade(id: '2', basket: 'core', symbol: 'ABC', side: 'SELL', quantity: 4, date: DateTime(2026, 1, 2)),
      makeTrade(id: '3', basket: 'core', symbol: 'ABC', side: 'BUY', quantity: 2, date: DateTime(2026, 1, 3)),
      makeTrade(id: '4', basket: 'core', symbol: 'ABC', side: 'SELL', quantity: 8, date: DateTime(2026, 1, 4)),
    ];
    expect(hasValidTransactionSequence(ledger), isTrue);
  });

  test('rejects a historical sale made before enough shares were bought', () {
    final ledger = [
      makeTrade(id: 'buy', basket: 'core', symbol: 'ABC', side: 'BUY', quantity: 5, date: DateTime(2026, 2, 2)),
      makeTrade(id: 'sell', basket: 'core', symbol: 'ABC', side: 'SELL', quantity: 4, date: DateTime(2026, 2, 1)),
    ];
    expect(hasValidTransactionSequence(ledger), isFalse);
  });

  test('keeps each basket inventory independent', () {
    final ledger = [
      makeTrade(id: 'buy-a', basket: 'basket-a', symbol: 'ABC', side: 'BUY', quantity: 5, date: DateTime(2026, 3, 1)),
      makeTrade(id: 'sell-b', basket: 'basket-b', symbol: 'ABC', side: 'SELL', quantity: 1, date: DateTime(2026, 3, 2)),
    ];
    expect(hasValidTransactionSequence(ledger), isFalse);
  });

  test('does not impose a 20-symbol cap on a basket', () {
    final ledger = List.generate(25, (i) => makeTrade(
      id: 'buy-$i',
      basket: 'core',
      symbol: 'SYM$i',
      side: 'BUY',
      quantity: 1,
      date: DateTime(2026, 4, 1).add(Duration(seconds: i)),
    ));
    expect(hasValidTransactionSequence(ledger), isTrue);
  });

  test('same-day rows preserve input order where dates contain no time', () {
    final d = DateTime(2026, 5, 1);
    final valid = [
      makeTrade(id: 'buy', basket: 'core', symbol: 'ABC', side: 'BUY', quantity: 2, date: d),
      makeTrade(id: 'sell', basket: 'core', symbol: 'ABC', side: 'SELL', quantity: 2, date: d),
    ];
    expect(hasValidTransactionSequence(valid), isTrue);
    expect(hasValidTransactionSequence(valid.reversed.toList()), isFalse);
  });
}
