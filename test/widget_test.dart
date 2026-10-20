import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equity_basket/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('EquityBasket dashboard and five navigation tabs render', (tester) async {
    await tester.pumpWidget(const EquityBasketApp());
    await tester.pumpAndSettle();

    expect(find.text('TOTAL PORTFOLIO VALUE'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Baskets'), findsOneWidget);
    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
