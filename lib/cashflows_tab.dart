import 'package:flutter/material.dart';

class CashflowsTab extends StatelessWidget {
  final List<dynamic> transactions;

  const CashflowsTab({
    Key? key,
    required this.transactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return _buildEmptyState();
    }

    final sortedTx = List.from(transactions)..sort((a, b) {
      final dateA = a['date']?.toString() ?? '';
      final dateB = b['date']?.toString() ?? '';
      return dateB.compareTo(dateA); 
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedTx.length,
      itemBuilder: (context, index) {
        return _buildTransactionCard(sortedTx[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No Transactions Found",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            "Your cashflow history will appear here.",
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final date = tx['date']?.toString() ?? 'Unknown Date';
    final fundName = tx['scheme_name']?.toString() ?? tx['fund_name']?.toString() ?? tx['scheme']?.toString() ?? 'Unknown Fund';
    final normalizedType = tx['normalized_type']?.toString() ?? tx['type']?.toString() ?? tx['description']?.toString() ?? 'Transaction';
    
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final units = (tx['units'] as num?)?.toDouble() ?? 0.0;
    final nav = (tx['nav'] as num?)?.toDouble() ?? (tx['price'] as num?)?.toDouble() ?? 0.0;

    final typeUpper = normalizedType.toUpperCase();
    final displayAmount = amount.abs();
    
    Color typeColor = const Color(0xFF00BFA5);
    IconData typeIcon = Icons.call_made;
    String badgeLabel = typeUpper;

    if (typeUpper == 'PURCHASE' || typeUpper == 'SIP') {
      badgeLabel = typeUpper == 'SIP' ? 'SIP' : 'INVESTMENT';
      typeColor = const Color(0xFF00BFA5);
      typeIcon = Icons.call_made;
    } else if (typeUpper == 'SWITCH_IN') {
      badgeLabel = 'SWITCH IN';
      typeColor = const Color(0xFF00BFA5);
      typeIcon = Icons.login;
    } else if (typeUpper == 'REDEMPTION') {
      badgeLabel = 'REDEMPTION';
      typeColor = Colors.redAccent;
      typeIcon = Icons.call_received;
    } else if (typeUpper == 'SWP') {
      badgeLabel = 'SWP';
      typeColor = Colors.redAccent;
      typeIcon = Icons.call_received;
    } else if (typeUpper == 'SWITCH_OUT') {
      badgeLabel = 'SWITCH OUT';
      typeColor = Colors.redAccent;
      typeIcon = Icons.logout;
    } else if (typeUpper == 'DIVIDEND_REINVESTMENT') {
      badgeLabel = 'DRIP';
      typeColor = Colors.blue;
      typeIcon = Icons.autorenew;
    } else if (typeUpper == 'DIVIDEND_PAYOUT') {
      badgeLabel = 'DIVIDEND';
      typeColor = Colors.purple;
      typeIcon = Icons.card_giftcard;
    } else if (typeUpper == 'STAMP_DUTY') {
      badgeLabel = 'STAMP DUTY';
      typeColor = Colors.orange;
      typeIcon = Icons.receipt;
    } else {
      // Explicit fallback for unknown types: display exact normalized type rather than guessing redemption
      badgeLabel = typeUpper;
      typeColor = Colors.grey[700]!;
      typeIcon = Icons.info_outline;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(typeIcon, size: 12, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        badgeLabel,
                        style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              fundName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              normalizedType,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetric("Amount", "₹${_formatCurrency(displayAmount)}", typeColor),
                _buildMetric("NAV", "₹${_formatCurrency(nav)}", Colors.black87),
                _buildMetric("Units", units.toStringAsFixed(3), Colors.black87, crossAxisAlignment: CrossAxisAlignment.end),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor, {CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
