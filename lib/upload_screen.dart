import 'package:flutter/material.dart';
import 'upload_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isProcessing = false;
  final StatementUploadService _uploadService = StatementUploadService();

  Future<void> _handleUpload() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final responseData = await _uploadService.uploadAndProcessPDF();
      
      if (!mounted) return;

      if (responseData != null) {
        // Success! In a full app, you would pass this data back to main.dart 
        // to update the Results Overview screen.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statement processed successfully!'),
            backgroundColor: Color(0xFF00D289),
          ),
        );
        Navigator.pop(context, responseData);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
        title: const Text('Upload Statement', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: const [
          Icon(Icons.shield_outlined, color: Colors.black87),
          SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cloud Icon
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF5D52D7).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_outlined, size: 60, color: Color(0xFF5D52D7)),
            ),
            const SizedBox(height: 32),
            const Text(
              'Upload your Mutual Fund\nstatement',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supported formats: CAMS/KFintech PDF',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 40),
            
            // Upload Box / Loading Indicator
            _isProcessing 
                ? const Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF5D52D7)),
                      SizedBox(height: 16),
                      Text('Processing your statement...', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Calculating exact XIRR & Capital Gains', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  )
                : InkWell(
                    onTap: _handleUpload,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF5D52D7).withOpacity(0.3), style: BorderStyle.solid),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.upload_file, color: Color(0xFF5D52D7), size: 32),
                          SizedBox(height: 12),
                          Text('Tap to upload PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Max file size: 10MB', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
            
            const Spacer(),
            
            // Security Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.grey.shade400),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your data is secure', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('We process the math and instantly discard the file.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
