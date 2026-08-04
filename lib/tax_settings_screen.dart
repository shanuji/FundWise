import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({Key? key}) : super(key: key);

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  final TextEditingController _ltcgController = TextEditingController();
  final TextEditingController _stcgController = TextEditingController();
  final TextEditingController _exemptionController = TextEditingController();
  String _selectedSlab = '30%';

  final List<String> _slabOptions = ['10%', '15%', '20%', '30%'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved preferences or inject smart defaults
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ltcgController.text = prefs.getString('ltcg_rate') ?? '12.5';
      _stcgController.text = prefs.getString('stcg_rate') ?? '20.0';
      _exemptionController.text = prefs.getString('exemption_limit') ?? '125000';
      _selectedSlab = prefs.getString('income_slab') ?? '30%';
    });
  }

  // Save customized inputs locally to the device
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ltcg_rate', _ltcgController.text);
    await prefs.setString('stcg_rate', _stcgController.text);
    await prefs.setString('exemption_limit', _exemptionController.text);
    await prefs.setString('income_slab', _selectedSlab);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tax parameters saved successfully!'),
          backgroundColor: Color(0xFF00D289),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tax Parameters',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customize your tax engine. The app defaults to current FY rates but can be adjusted for historical or future scenarios.',
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Equity Mutual Funds'),
            _buildInputField('LTCG Rate (%)', _ltcgController, 'e.g., 12.5'),
            _buildInputField('STCG Rate (%)', _stcgController, 'e.g., 20.0'),
            _buildInputField('Annual Exemption Limit (₹)', _exemptionController, 'e.g., 125000'),
            
            const SizedBox(height: 24),
            
            _buildSectionHeader('Debt Mutual Funds'),
            const Text(
              'Post-April 2023 debt funds are taxed at your applicable slab rate.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _buildDropdownField(),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A44D8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF4A44D8).withOpacity(0.4),
                ),
                onPressed: _saveSettings,
                child: const Text(
                  'Save Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF29247A)),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          hintText: hint,
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSlab,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF5D52D7)),
          items: _slabOptions.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text('Income Slab: $value', style: const TextStyle(fontSize: 16)),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedSlab = newValue!;
            });
          },
        ),
      ),
    );
  }
}
