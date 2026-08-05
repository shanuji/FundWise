import 'package:flutter/material.dart';
import 'upload_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final StatementUploadService _uploadService = StatementUploadService();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _handleUpload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Sends the password if typed, or an empty string if left blank
      final result = await _uploadService.uploadAndProcessPDF(
        password: _passwordController.text.trim(),
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statement processed successfully!')),
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Upload Statement', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF5D52D7).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload, size: 64, color: Color(0xFF5D52D7)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload your Mutual Fund statement',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supported formats: CAMS/KFintech PDF',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            
            // Password Field Option
            TextField(
              controller: _passwordController,
              obscureText: true, // Hides the password dots
              decoration: InputDecoration(
                labelText: 'PDF Password (Optional)',
                hintText: 'Leave blank if unprotected',
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF5D52D7)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tap to Upload Area
            GestureDetector(
              onTap: _isLoading ? null : _handleUpload,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF5D52D7).withOpacity(0.3), width: 1.5),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF5D52D7)))
                    : const Column(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 40, color: Color(0xFF5D52D7)),
                          SizedBox(height: 12),
                          Text('Tap to select PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 4),
                          Text('Max file size: 10MB', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
