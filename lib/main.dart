import 'package:flutter/material.dart';

// Import all your screens
import 'upload_screen.dart'; // Assuming this is your "Home" page for parsing
import 'history_screen.dart';
import 'insights_screen.dart';
import 'settings_tab.dart';

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
        primaryColor: const Color(0xFF5E35B1), // Deep Purple
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

  // Placeholder for the parsed data. 
  // Once the user uploads a statement on the Home (Upload) tab, 
  // you will update this state and it will feed into the Insights tab.
  Map<String, dynamic> _parsedData = {};
  List<dynamic> _transactions = [];

  // This function allows the UploadScreen to pass data back to the Dashboard
  void _onDataParsed(Map<String, dynamic> data, List<dynamic> txs) {
    setState(() {
      _parsedData = data;
      _transactions = txs;
      _currentIndex = 2; // Automatically switch to the Insights tab!
    });
  }

  @override
  Widget build(BuildContext context) {
    // Define the 4 main screens for the bottom navigation
    final List<Widget> screens = [
      // 0: Home / Upload
      // Replace UploadScreen with your actual home widget name if different.
      // Pass the callback so it can update the dashboard when parsing finishes.
      UploadScreen(onParseSuccess: _onDataParsed), 
      
      // 1: History
      HistoryScreen(),
      
      // 2: Insights (Passes the data we hold in state)
      InsightsScreen(
        parsedData: _parsedData,
        transactions: _transactions,
      ),
      
      // 3: Settings (Profile)
      const SettingsTab(),
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
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF5E35B1)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
