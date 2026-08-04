import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatementUploadService {
  // NOTE: Replace this URL once you host your Python backend on Render/Railway
  static const String apiEndpoint = "https://your-api-domain.com/api/v1/parse-cas";

  Future<Map<String, dynamic>?> uploadAndProcessPDF() async {
    // 1. Open Native File Picker
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) {
      return null; // User canceled the picker
    }

    // 2. Load custom tax parameters from device storage
    final prefs = await SharedPreferences.getInstance();
    final ltcg = prefs.getString('ltcg_rate') ?? '12.5';
    final stcg = prefs.getString('stcg_rate') ?? '20.0';
    final exemption = prefs.getString('exemption_limit') ?? '125000';
    
    // Strip the '%' sign from the saved slab (e.g., "30%" -> "30")
    String rawSlab = prefs.getString('income_slab') ?? '30%';
    final slab = rawSlab.replaceAll('%', '').trim();

    // 3. Build the Multipart Form Request
    var request = http.MultipartRequest('POST', Uri.parse(apiEndpoint));
    
    // Attach the PDF
    request.files.add(
      await http.MultipartFile.fromPath('file', result.files.single.path!),
    );

    // Attach the Tax Rules
    request.fields['ltcg_rate'] = ltcg;
    request.fields['stcg_rate'] = stcg;
    request.fields['exemption_limit'] = exemption;
    request.fields['income_slab'] = slab;

    // 4. Send to Backend
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      // Returns the full JSON dict including {"summary": {...}, "taxes": {...}}
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to process statement: ${response.statusCode}');
    }
  }
}
