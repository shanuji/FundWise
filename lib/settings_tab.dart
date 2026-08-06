import 'package:flutter/material.dart';

class SettingsTab extends StatefulWidget {
  final Map<String, dynamic> parsedData;

  const SettingsTab({
    Key? key,
    required this.parsedData,
  }) : super(key: key);

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final TextEditingController _ltcgController = TextEditingController(text: "12.5");
  final TextEditingController _stcgController = TextEditingController(text: "20.0");
  final TextEditingController _exemptionController = TextEditingController(text: "125000");

  @override
  void dispose() {
    _ltcgController.dispose();
    _stcgController.dispose();
    _exemptionController.dispose();
    super.dispose();
  }

  void _onSettingChanged(String value) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final portfolioSummary = widget.parsedData['portfolio_summary'] ?? {};
    final taxSummary = widget.parsedData['tax_summary'] ?? widget.parsedData['taxes'] ?? widget.parsedData['capital_gains'] ?? {};
    
    final double stcgProfit = (taxSummary['stcg'] ?? taxSummary['short_term'] ?? portfolioSummary['stcg'] ?? portfolioSummary['stcg_profit'] ?? portfolioSummary['short_term_capital_gains'] ?? portfolioSummary['short_term_taxable'] ?? 0.0).toDouble();
    final double ltcgProfit = (taxSummary['ltcg'] ?? taxSummary['long_term'] ?? portfolioSummary['ltcg'] ?? portfolioSummary['ltcg_profit'] ?? portfolioSummary['long_term_capital_gains'] ?? portfolioSummary['long_term_taxable'] ?? 0.0).toDouble();

    final double ltcgRate = double.tryParse(_ltcgController.text) ?? 12.5;
    final double stcgRate = double.tryParse(_stcgController.text) ?? 20.0;
    final double exemption = double.tryParse(_exemptionController.text) ?? 125000.0;

    final double stcgTax = stcgProfit > 0 ? (stcgProfit * (stcgRate / 100)) : 0.0;
    final double taxableLtcg = ltcgProfit > exemption ? (ltcgProfit - exemption) : 0.0;
    final double ltcgTax = taxableLtcg > 0 ? (taxableLtcg * (ltcgRate / 100)) : 0.0;
    final double totalTax = stcgTax + ltcgTax;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Tax Calculation",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeroTaxCard(totalTax),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTaxDetailCard("STCG Liability", stcgProfit, stcgTax, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildTaxDetailCard("LTCG Liability", ltcgProfit, ltcgTax, Colors.blue)),
            ],
          ),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.only(left: 4.0),
            child: Text(
              "Tax Parameters",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 4.0),
            child: Text(
              "Adjust the parameters below to instantly recalculate your tax liability.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsMenu(context),
        ],
      ),
    );
  }

  Widget _buildHeroTaxCard(double totalTax) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC62828).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Estimated Total Tax Liability", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            "₹${_formatCurrency(totalTax)}",
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxDetailCard(String title, double profit, double tax, MaterialColor color) {
    return Card(
      elevation: 0,
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
            Text(title, style: TextStyle(color: color[700], fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text("Taxable Profit", style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 2),
            Text("₹${_formatCurrency(profit)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            const Text("Tax Amount", style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              "₹${_formatCurrency(tax)}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsMenu(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInputField(
              context,
              controller: _stcgController,
              label: "STCG Rate (%)",
              icon: Icons.trending_flat,
            ),
            const SizedBox(height: 20),
            _buildInputField(
              context,
              controller: _ltcgController,
              label: "LTCG Rate (%)",
              icon: Icons.trending_up,
            ),
            const SizedBox(height: 20),
            _buildInputField(
              context,
              controller: _exemptionController,
              label: "LTCG Exemption Limit (₹)",
              icon: Icons.money_off,
              isCurrency: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isCurrency = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: _onSettingChanged, 
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
            suffixText: isCurrency ? "₹" : "%",
            suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
          ),
        ),
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
