import 'package:file_selector/file_selector.dart';
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

  XFile? _selectedFile;
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void dispose() {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to select the PDF: $e');
    }
  }

  Future<void> _analyzeStatement() async {
    final file = _selectedFile;
    if (_isLoading || file == null) {
      if (file == null) {
        setState(() => _errorMessage = 'Please upload/select a statement first.');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _uploadService.analyzeSelectedPDF(
        file: file,
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

  Widget _stepHeader({required String number, required String title, required bool active}) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF5E35B1) : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Text(number, style: TextStyle(color: active ? Colors.white : Colors.black54, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileSelected = _selectedFile != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Statement'),
        backgroundColor: const Color(0xFF5E35B1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cloud_upload_outlined, size: 80, color: Color(0xFF5E35B1)),
            const SizedBox(height: 16),
            const Text('Upload your Mutual Fund statement', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Supported formats: CAMS/KFintech PDF', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 28),

            // Step 1 — Upload. Selecting a file is independent from analysis,
            // so the same file can be analysed repeatedly without reopening the picker.
            _stepHeader(number: '1', title: 'Upload', active: true),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _selectStatement,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(fileSelected ? 'Change PDF' : 'Select PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5E35B1),
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: const BorderSide(color: Color(0xFF5E35B1)),
              ),
            ),
            if (fileSelected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(.08),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_selectedFile!.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            // Step 2 — Password remains editable between analysis attempts.
            _stepHeader(number: '2', title: 'Password', active: fileSelected),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PDF Password (Optional)',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),
            // Step 3 — Analyse. This button never opens the file picker, so it
            // can be pressed again after a failed/stuck analysis.
            _stepHeader(number: '3', title: 'Analyse', active: fileSelected),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: fileSelected && !_isLoading ? _analyzeStatement : null,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.analytics_outlined),
              label: Text(_isLoading ? 'Analysing…' : 'Analyse Statement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E35B1),
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.1),
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
              ),
            ],
          ],
        ),
      ),
    );
  }
}
