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
      drawer: const FundWiseDrawer(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. HOME TAB (Results Overview)
// ==========================================
class ResultsOverviewTab extends StatelessWidget {
  const ResultsOverviewTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black87),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Results Overview',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.black87),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading Performance Report (PDF)...')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Main XIRR Card
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
                  const Text('XIRR (Annualized)', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  const Text(
                    '18.64%',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D289).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Excellent',
                      style: TextStyle(color: Color(0xFF00D289), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStat('Absolute Profit', '24.75%'),
                      _buildMiniStat('Absolute Value', '₹2,47,580'),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Metrics List
            _buildMetricTile(Icons.account_balance_wallet_outlined, 'Capital Invested', '₹10,00,000', Colors.black87),
            _buildMetricTile(Icons.trending_up_outlined, 'Current Value', '₹12,47,580', Colors.black87),
            _buildMetricTile(Icons.auto_graph_outlined, 'Total Profit', '₹2,47,580', const Color(0xFF00D289)),
            _buildMetricTile(Icons.show_chart_outlined, 'Time Weighted Return (XIRR)', '18.64%', const Color(0xFF00D289)),
            
            const SizedBox(height: 16),
            
            // Upload New Statement Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF5D52D7), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF5D52D7)),
                label: const Text(
                  'Upload New Statement',
                  style: TextStyle(color: Color(0xFF5D52D7), fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UploadScreen()),
                  );
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F2FF),
              borderRadius: BorderRadius.circular(8),
            ),
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
// 2. INSIGHTS TAB (Detailed Breakdown)
// ==========================================
class InsightsTab extends StatelessWidget {
  const InsightsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
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
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Cashflows'),
              Tab(text: 'Holdings'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSummaryTab(),
            _buildCashflowsTab(),
            _buildHoldingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildDetailRow(Icons.account_balance_wallet_outlined, 'Capital Invested', '₹10,00,000'),
        _buildDetailRow(Icons.show_chart, 'Current Value', '₹12,47,580'),
        _buildDetailRow(Icons.trending_up, 'Absolute Profit', '₹2,47,580 (24.75%)', valueColor: const Color(0xFF00D289)),
        _buildDetailRow(Icons.auto_graph, 'XIRR (Annualized)', '18.64%', valueColor: const Color(0xFF00D289)),
        _buildDetailRow(Icons.calendar_today_outlined, 'First Investment', '15 Jan 2022'),
        _buildDetailRow(Icons.access_time_outlined, 'Last Valuation Date', '15 May 2024'),
        _buildDetailRow(Icons.swap_horiz_outlined, 'Total Investments (SIPs)', '24'),
        _buildDetailRow(Icons.outbox_outlined, 'Total Withdrawals', '3'),
      ],
    );
  }

  Widget _buildCashflowsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: const [
        ListTile(
          leading: Icon(Icons.arrow_downward, color: Color(0xFF00D289)),
          title: Text('SIP Purchase - Quant Flexi Cap'),
          subtitle: Text('10 May 2024'),
          trailing: Text('₹10,000', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.arrow_downward, color: Color(0xFF00D289)),
          title: Text('SIP Purchase - Invesco Mid Cap'),
          subtitle: Text('05 May 2024'),
          trailing: Text('₹12,000', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.arrow_upward, color: Colors.red),
          title: Text('Partial Redemption - HDFC Flexi'),
          subtitle: Text('12 Apr 2024'),
          trailing: Text('-₹25,000', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildHoldingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: const [
        Card(
          child: ListTile(
            title: Text('Quant Flexi Cap Fund', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('XIRR: 22.4%  •  Units: 1,245.8'),
            trailing: Text('₹3,45,000', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D52D7))),
          ),
        ),
        Card(
          child: ListTile(
            title: Text('Invesco India Mid Cap Fund', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('XIRR: 19.1%  •  Units: 890.2'),
            trailing: Text('₹2,80,000', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5D52D7))),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value, {Color valueColor = Colors.black87}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5D52D7), size: 20),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.black54))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
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
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Card
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

          // Settings Section
          const Text('App Configuration', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          
          _buildSettingsTile(
            context,
            Icons.tune,
            'Tax Parameters',
            'Adjust LTCG, STCG, and exemption limits',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TaxSettingsScreen()),
              );
            },
          ),
          _buildSettingsTile(
            context,
            Icons.security_outlined,
            'Security & Privacy',
            'Biometric lock & local storage options',
            onTap: () {},
          ),
          _buildSettingsTile(
            context,
            Icons.help_outline,
            'Help & CAS FAQ',
            'How CAMS & KFintech statements work',
            onTap: () {},
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5D52D7), Color(0xFF3F379F)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('FundWise', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Mutual Fund Portfolio Analytics', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined, color: Color(0xFF5D52D7)),
            title: const Text('My Portfolio'),
            trailing: const Icon(Icons.check_circle, color: Color(0xFF00D289), size: 18),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.people_outline, color: Colors.grey),
            title: const Text("Father's Portfolio"),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Switched to Father's Portfolio")),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Capital Gains Tax Report'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TaxSettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
