class ResultsOverviewTab extends StatefulWidget {
  const ResultsOverviewTab({Key? key}) : super(key: key);

  @override
  State<ResultsOverviewTab> createState() => _ResultsOverviewTabState();
}

class _ResultsOverviewTabState extends State<ResultsOverviewTab> {
  Map<String, dynamic>? _portfolioData;

  @override
  Widget build(BuildContext context) {
    final summary = _portfolioData?['summary'];
    
    final String xirr = summary != null ? summary['xirr'].toString() : '0.0';
    final String capitalInvested = summary != null ? summary['capital_invested'].toString() : '0.0';
    final String currentValue = summary != null ? summary['current_value'].toString() : '0.0';
    final String openingBalance = summary != null ? summary['opening_balance'].toString() : '0.0';
    final String startDate = summary != null ? summary['statement_start_date'].toString() : 'Start Date';
    final String absProfit = summary != null ? summary['absolute_profit'].toString() : '0.0';
    final String absReturn = summary != null ? summary['absolute_return_pct'].toString() : '0.0';
    final String benchmark = summary != null ? summary['benchmark_xirr'].toString() : '0.0';
    
    bool isOutperforming = true;
    if (summary != null) {
      isOutperforming = (summary['xirr'] ?? 0) >= (summary['benchmark_xirr'] ?? 0);
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
                  const Text('XIRR (Annualized)', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text('$xirr%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
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
                      const Text('Portfolio XIRR', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('$xirr%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00D289))),
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
            _buildMetricTile(Icons.account_balance_wallet_outlined, 'Period Capital Deployed', '₹$capitalInvested', Colors.black87),
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
                  
                  if (result != null && result['summary'] != null) {
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
