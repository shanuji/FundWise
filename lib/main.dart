import 'package:flutter/material.dart';
import 'history_screen.dart';
import 'upload_screen.dart';
import 'tax_settings_screen.dart';

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
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        fontFamily: 'SF Pro',
        primaryColor: const Color(0xFF5D52D7),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF5D52D7),
          secondary: const Color(0xFF00D289),
        ),
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({Key? key}) : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ResultsOverviewTab(),
    HistoryScreen(),
    InsightsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF5D52D7),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ==========================================
// 1. HOME TAB
// ==========================================
class ResultsOverviewTab extends StatefulWidget {
  const ResultsOverviewTab({Key? key}) : super(key: key);

  @override
  State<ResultsOverviewTab> createState() => _ResultsOverviewTabState();
}

class _ResultsOverviewTabState extends State<ResultsOverviewTab> {
  Map<String, dynamic>? _portfolioData;

  @override
  Widget build(BuildContext context) {
    // Bind to the new 'portfolio_summary' object returned by custom engine backend
    final summary = _portfolioData?['portfolio_summary'];
    final periodInfo = _portfolioData?['statement_period'];
    
    final String annualizedReturn = summary != null ? summary['statement_annualized_return'].toString() : '0.0';
    final String capitalDeployed = summary != null ? summary['total_capital_deployed'].toString() : '0.0';
    final String currentValue = summary != null ? summary['current_portfolio_value'].toString() : '0.0';
    final String openingBalance = summary != null ? summary['opening_portfolio_value'].toString() : '0.0';
    final String startDate = periodInfo != null ? periodInfo['from'].toString() : 'Start Date';
    final String absProfit = summary != null ? summary['total_profit'].toString() : '0.0';
    final String absReturn = summary != null ? summary['absolute_return_pct'].toString() : '0.0';
    final String benchmark = summary != null ? summary['benchmark_annualized_return'].toString() : '0.0';
    
    bool isOutperforming = true;
    if (summary != null) {
      isOutperforming = (summary['statement_annualized_return'] ?? 0) >= (summary['benchmark_annualized_return'] ?? 0);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      drawer: const FundWiseDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Results Overview', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5D52D7), Color(0xFF3F379F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5D52D7).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Statement Annualized Return', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text('$annualizedReturn%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOutperforming ? const Color(0xFF00D289).withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOutperforming ? 'Outperforming Market' : 'Underperforming Market',
                      style: TextStyle(
                        color: isOutperforming ? const Color(0xFF00D289) : Colors.redAccent, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 12
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStat('Absolute Return', '$absReturn%'),
                      _buildMiniStat('Net Profit', '₹$absProfit'),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Statement Return', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('$annualizedReturn%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00D289))),
                    ],
                  ),
                  Container(height: 30, width: 1, color: Colors.grey.shade300),
                  Column(
                    children: [
                      const Text('Nifty 50 Benchmark', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('$benchmark%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF5D52D7))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricTile(Icons.account_balance_wallet_outlined, 'Total Capital Deployed', '₹$capitalDeployed', Colors.black87),
            _buildMetricTile(Icons.history_edu_outlined, 'Opening Balance as on $startDate', '₹$openingBalance', Colors.black87),
            _buildMetricTile(Icons.trending_up_outlined, 'Current Value', '₹$currentValue', Colors.black87),
            _buildMetricTile(Icons.auto_graph_outlined, 'Absolute Profit', '₹$absProfit ($absReturn%)', const Color(0xFF00D289)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF5D52D7), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF5D52D7)),
                label: const Text('Upload New Statement', style: TextStyle(color: Color(0xFF5D52D7), fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final result = await Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const UploadScreen())
                  );
                  
                  if (result != null && result['portfolio_summary'] != null) {
                    setState(() {
                      _portfolioData = result;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricTile(IconData icon, String title, String value, Color valueColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF3F2FF), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: const Color(0xFF5D52D7), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}

// ==========================================
// 2. INSIGHTS TAB
// ==========================================
class InsightsTab extends StatelessWidget {
  const InsightsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        drawer: const FundWiseDrawer(),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text('Detailed Breakdown', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Color(0xFF5D52D7),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF5D52D7),
            indicatorWeight: 3,
            tabs: [Tab(text: 'Summary'), Tab(text: 'Cashflows'), Tab(text: 'Holdings')],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Summary Tab')),
            Center(child: Text('Cashflows Tab')),
            Center(child: Text('Holdings Tab')),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. PROFILE TAB
// ==========================================
class ProfileTab extends StatelessWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        title: const Text('Profile & Settings', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), 
        centerTitle: true
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF5D52D7).withOpacity(0.1),
                  child: const Icon(Icons.person, color: Color(0xFF5D52D7), size: 32),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Investor Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('PAN: ABCDE****F', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('App Configuration', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          _buildSettingsTile(
            context,
            Icons.tune,
            'Tax Parameters',
            'Adjust LTCG, STCG, and exemption limits',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TaxSettingsScreen()));
            },
          ),
          _buildSettingsTile(
            context,
            Icons.security_outlined,
            'Security & Privacy',
            'Biometric lock & local storage options',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Security & Privacy settings coming soon!')),
              );
            },
          ),
          _buildSettingsTile(
            context,
            Icons.help_outline,
            'Help & CAS FAQ',
            'How CAMS & KFintech statements work',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('FAQ Section coming soon!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, String subtitle, {required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF5D52D7)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

// ==========================================
// 4. HAMBURGER DRAWER
// ==========================================
class FundWiseDrawer extends StatelessWidget {
  const FundWiseDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF5D52D7), Color(0xFF3F379F)])),
            child: Text('FundWise', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Capital Gains Tax Report'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TaxSettingsScreen()));
            },
          ),
        ],
      ),
    );
  }
}
