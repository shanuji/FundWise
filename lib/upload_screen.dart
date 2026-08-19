import 'package:flutter/material.dart';
import 'upload_service.dart';

class UploadScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> data, List<dynamic> transactions)? onParseSuccess;

  const UploadScreen({super.key, this.onParseSuccess});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final StatementUploadService _uploadService = StatementUploadService();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;
  String? _selectedFileName;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _analyzeStatement() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _errorMessage = ''; _selectedFileName = null; });
    try {
      final result = await _uploadService.uploadAndProcessPDF(password: _passwordController.text);
      if (!mounted) return;
      if (result == null) {
        setState(() { _isLoading = false; _errorMessage = 'No PDF was selected.'; });
        return;
      }
      final transactions = result['transactions'] is List ? List<dynamic>.from(result['transactions'] as List) : <dynamic>[];
      setState(() { _isLoading = false; _selectedFileName = 'CAS statement'; });
      widget.onParseSuccess?.call(result, transactions);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _errorMessage = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Statement'), backgroundColor: const Color(0xFF5E35B1)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.cloud_upload_outlined, size: 80, color: Color(0xFF5E35B1)),
          const SizedBox(height: 16),
          const Text('Upload your Mutual Fund statement', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Supported formats: CAMS/KFintech PDF', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 24),
          TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: 'PDF Password (Optional)', prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 24),
          if (_selectedFileName != null) Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.green.withOpacity(.1), border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 12), Expanded(child: Text('Analysis completed', style: TextStyle(fontWeight: FontWeight.bold)))])),
          if (_errorMessage.isNotEmpty) Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.red.withOpacity(.1), border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, color: Colors.redAccent), const SizedBox(width: 12), Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)))])),
          ElevatedButton(onPressed: _isLoading ? null : _analyzeStatement, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5E35B1), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Select & Analyze Statement', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
}
