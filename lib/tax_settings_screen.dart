import 'package:flutter/material.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({Key? key}) : super(key: key);

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  // Controllers with default values matching the current Indian tax regime
  final TextEditingController _ltcgController = TextEditingController(text: "12.5");
  final TextEditingController _stcgController = TextEditingController(text: "20.0");
  final TextEditingController _exemptionController = TextEditingController(text: "125000");
  final TextEditingController _slabController = TextEditingController(text: "30.0");

  bool _isSaving = false;

  @override
  void dispose() {
    _ltcgController.dispose();
    _stcgController.dispose();
    _exemptionController.dispose();
    _slabController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    // Simulate saving to SharedPreferences or local database
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Tax parameters saved successfully!"),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Tax Parameters",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text(
            "Configure your tax settings to ensure accurate profit and return calculations based on the latest financial regulations.",
            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),

          _buildInputField(
            context,
            controller: _ltcgController,
            label: "LTCG Rate (%)",
            hint: "e.g. 12.5",
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 20),

          _buildInputField(
            context,
            controller: _stcgController,
            label: "STCG Rate (%)",
            hint: "e.g. 20.0",
            icon: Icons.trending_flat,
          ),
          const SizedBox(height: 20),

          _buildInputField(
            context,
            controller: _exemptionController,
            label: "LTCG Exemption Limit (₹)",
            hint: "e.g. 125000",
            icon: Icons.money_off,
            isCurrency: true,
          ),
          const SizedBox(height: 20),

          _buildInputField(
            context,
            controller: _slabController,
            label: "Income Tax Slab (%)",
            hint: "e.g. 30.0",
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    )
                  : const Text(
                      "Save Parameters",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
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
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
            suffixText: isCurrency ? "₹" : "%",
            suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
