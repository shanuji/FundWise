import 'package:flutter/material.dart';

class CashflowsTab extends StatefulWidget {
  final List<dynamic> transactions;

  const CashflowsTab({
    Key? key,
    required this.transactions,
  }) : super(key: key);

  @override
  State<CashflowsTab> createState() => _CashflowsTabState();
}

class _CashflowsTabState extends State<CashflowsTab> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Purchases', 'Redemptions', 'SIP', 'Lumpsum'];

  // Helper to parse dates like "2026-04-05"
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  // Helper to format month header (e.g., "APR 2026")
  String _getMonthYear(DateTime date) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return "${months[date.month - 1]} ${date.year}";
  }

  // Helper to format day and month for timeline (e.g., "05 Apr")
  String _getDayMonth(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    return "$day ${months[date.month - 1]}";
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Summaries (Always based on ALL transactions)
    double totalInvested = 0.0;
    double totalRedeemed = 0.0;

    for (var tx in widget.transactions) {
      double amount = (tx['amount'] ?? 0.0).toDouble();
      if (amount > 0) {
        totalInvested += amount;
      } else {
        totalRedeemed += amount.abs();
      }
    }
    double netInvestment = totalInvested - totalRedeemed;

    // 2. Apply Filters
    List<dynamic> filteredTx = widget.transactions.where((tx) {
      double amount = (tx['amount'] ?? 0.0).toDouble();
      bool isPurchase = amount > 0;
      String type = (tx['type'] ?? '').toString().toLowerCase();

      if (_selectedFilter == 'Purchases') return isPurchase;
      if (_selectedFilter == 'Redemptions') return !isPurchase;
      if (_selectedFilter == 'SIP') return type.contains('sip');
      if (_selectedFilter == 'Lumpsum') return type.contains('lumpsum') || type.contains('fresh');
      return true; // 'All'
    }).toList();

    // 3. Sort by Date Descending
    filteredTx.sort((a, b) {
      DateTime dateA = _parseDate(a['date']) ?? DateTime.now();
      DateTime dateB = _parseDate(b['date']) ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    // 4. Group by Month-Year
    Map<String, List<dynamic>> groupedTx = {};
    for (var tx in filteredTx) {
      DateTime? date = _parseDate(tx['date']);
      if (date != null) {
        String monthYear = _getMonthYear(date);
        if (!groupedTx.containsKey(monthYear)) {
          groupedTx[monthYear] = [];
        }
        groupedTx[monthYear]!.add(tx);
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: "Total Invested",
                    amount: totalInvested,
                    icon: Icons.arrow_upward,
                    iconColor: Colors.green,
                    bgColor: Colors.green.withOpacity(0.1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    title: "Total Redeemed",
                    amount: totalRedeemed,
                    icon: Icons.arrow_downward,
                    iconColor: Colors.red,
                    bgColor: Colors.red.withOpacity(0.1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    title: "Net Investment",
                    amount: netInvestment,
                    icon: Icons.bar_chart,
                    iconColor: Theme.of(context).primaryColor,
                    bgColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),

          // Filter Pills
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return FilterChip(
                  label: Text(filter, style: TextStyle(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13
                  )),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                  backgroundColor: Colors.white,
                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Timeline List
          Expanded(
            child: groupedTx.isEmpty
                ? const Center(child: Text("No transactions found for this filter."))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: groupedTx.length,
                    itemBuilder: (context, index) {
                      String monthYear = groupedTx.keys.elementAt(index);
                      List<dynamic> monthTxs = groupedTx[monthYear]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              monthYear,
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          ...monthTxs.map((tx) => _buildTimelineItem(tx)).toList(),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              "₹${_formatCurrency(amount)}",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(dynamic tx) {
    DateTime? date = _parseDate(tx['date']);
    double amount = (tx['amount'] ?? 0.0).toDouble();
    bool isPurchase = amount > 0;
    String schemeName = tx['scheme_name'] ?? 'Unknown Fund';
    String type = tx['type'] ?? (isPurchase ? 'Purchase' : 'Redemption');
    
    Color typeColor = isPurchase ? Colors.green : Colors.red;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Date & Timeline Line
        SizedBox(
          width: 50,
          child: Column(
            children: [
              Text(
                date != null ? _getDayMonth(date) : "",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
              ),
              Container(
                width: 2,
                height: 50, // Line connecting to the next item
                color: Colors.grey[300],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Right Column: Transaction Card
        Expanded(
          child: Card(
            elevation: 0.5,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schemeName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${isPurchase ? '' : '-'}₹${_formatCurrency(amount.abs())}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: typeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
