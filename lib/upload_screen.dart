import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'upload_service.dart';

class UploadScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> data, List<dynamic> transactions)? onParseSuccess;

  const UploadScreen({super.key, this.onParseSuccess});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> with SingleTickerProviderStateMixin {
  final StatementUploadService _uploadService = StatementUploadService();
  final TextEditingController _passwordController = TextEditingController();
  late final TabController _tabs;

  XFile? _selectedFile;
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectStatement() async {
    if (_isLoading) return;
    try {
      final file = await _uploadService.selectPDF();
      if (!mounted || file == null) return;
      setState(() {
        _selectedFile = file;
        _errorMessage = '';
      });
      _tabs.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to select the PDF: $e');
    }
  }

  Future<void> _analyzeStatement() async {
    if (_isLoading) return;
    if (_selectedFile == null) {
      setState(() {
        _errorMessage = 'Please upload/select a statement first.';
        _tabs.animateTo(0);
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _uploadService.analyzeSelectedPDF(
        password: _passwordController.text,
      );
      if (!mounted) return;
      final transactions = result['transactions'] is List
          ? List<dynamic>.from(result['transactions'] as List)
          : <dynamic>[];
      setState(() => _isLoading = false);
      widget.onParseSuccess?.call(result, transactions);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse Statement'),
        backgroundColor: const Color(0xFF5E35B1),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file_outlined), text: 'Upload'),
            Tab(icon: Icon(Icons.lock_outline), text: 'Password'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Analyse'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _uploadTab(),
          _passwordTab(),
          _analyseTab(),
        ],
      ),
    );
  }

  Widget _uploadTab() {
    return _page(
      icon: Icons.cloud_upload_outlined,
      title: 'Upload your Mutual Fund statement',
      subtitle: 'CAMS / KFintech password-protected PDFs are analysed on this device.',
      children: [
        if (_selectedFile != null) _fileCard() else const Text('No statement selected', textAlign: TextAlign.center),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: _selectStatement,
          icon: const Icon(Icons.folder_open),
          label: Text(_selectedFile == null ? 'Select Statement' : 'Change Statement'),
          style: _buttonStyle(),
        ),
        if (_selectedFile != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => _tabs.animateTo(1), child: const Text('Continue to Password')),
        ],
        if (_errorMessage.isNotEmpty) ...[const SizedBox(height: 16), _errorCard()],
      ],
    );
  }

  Widget _passwordTab() {
    return _page(
      icon: Icons.lock_outline,
      title: 'PDF Password',
      subtitle: 'Enter the password for the selected statement. It is used locally to open the PDF.',
      children: [
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'PDF Password (Optional)',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: () => _tabs.animateTo(2), child: const Text('Continue to Analyse')),
        if (_errorMessage.isNotEmpty) ...[const SizedBox(height: 16), _errorCard()],
      ],
    );
  }

  Widget _analyseTab() {
    return _page(
      icon: Icons.analytics_outlined,
      title: 'Ready to analyse',
      subtitle: _selectedFile?.name ?? 'Upload a statement first.',
      children: [
        ElevatedButton(
          onPressed: _selectedFile != null && !_isLoading ? _analyzeStatement : null,
          style: _buttonStyle(),
          child: _isLoading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('Analysing locally...', style: TextStyle(color: Colors.white)),
                  ],
                )
              : const Text('Analyse Statement', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        const Text(
          'If analysis fails, press Analyse again. The selected PDF and password remain available.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        if (_errorMessage.isNotEmpty) ...[const SizedBox(height: 18), _errorCard()],
      ],
    );
  }

  Widget _page({required IconData icon, required String title, required String subtitle, required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          Icon(icon, size: 78, color: const Color(0xFF5E35B1)),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 28),
          ...children,
        ],
      ),
    );
  }

  Widget _fileCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF5E35B1).withOpacity(.07),
          border: Border.all(color: const Color(0xFF5E35B1).withOpacity(.35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Color(0xFF5E35B1)),
            const SizedBox(width: 12),
            Expanded(child: Text(_selectedFile!.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );

  Widget _errorCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.08),
          border: Border.all(color: Colors.redAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 12),
            Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent))),
          ],
        ),
      );

  ButtonStyle _buttonStyle() => ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}
