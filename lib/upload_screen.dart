import 'package:flutter/material.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.menu, color: Colors.black87),
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
          children: [
            const SizedBox(height: 20),
            // Cloud Icon Placeholder
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
              'Supported formats: PDF, Excel, CSV',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 40),
            
            // Upload Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF5D52D7).withOpacity(0.3), style: BorderStyle.solid),
                // Note: For true dashed lines, use the dotted_border package
              ),
              child: const Column(
                children: [
                  Icon(Icons.upload_file, color: Color(0xFF5D52D7), size: 32),
                  SizedBox(height: 12),
                  Text('Tap to upload or drag & drop', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Max file size: 25MB', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your data is secure', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('We never store your files on our servers.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
