import 'package:flutter/material.dart';

import 'upload_screen.dart';
import 'history_screen.dart';
import 'insights_screen.dart';
import 'settings_tab.dart';
import 'return_calculation_adapter.dart';

void main() {
  runApp(const FundWiseApp());
}

class FundWiseApp extends StatelessWidget {
  const FundWiseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FundWise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF5E35B1),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5E35B1)),
        useMaterial3: true,
      ),
      home: const MainDashboard(),
    );
  }
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  Map<String, dynamic> _parsedData = {};
  List<dynamic> _transactions = [];

  void _onDataParsed(Map<String, dynamic> data, List<dynamic> txs) {
    final recalculatedData = applyFundWiseReturns(data, txs);
    setState(() {
      _parsedData = recalculatedData;
      _transactions = txs;
      _currentIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      UploadScreen(onParseSuccess: _onDataParsed),
      HistoryScreen(),
      InsightsScreen(
        parsedData: _parsedData,
        transactions: _transactions,
      ),
      SettingsTab(
        parsedData: _parsedData,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF5E35B1).withOpacity(0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF5E35B1)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: Color(0xFF5E35B1)),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF5E35B1)),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Color(0xFF5E35B1)),
            label: 'Taxes',
          ),
        ],
      ),
    );
  }
}
