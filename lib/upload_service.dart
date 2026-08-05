import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatementUploadService {
  static const String apiEndpoint = "https://fundwise-backend-coow.onrender.com/api/v1/parse-cas";

  Future<Map<String, dynamic>?> uploadAndProcessPDF({String password = ""}) async {
    const XTypeGroup pdfGroup = XTypeGroup(
      label: 'PDFs',
      extensions: <String>['pdf'],
    );
    
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[pdfGroup]);

    if (file == null || file.path.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    
    String cleanData(String? val, String fallback) {
      if (val == null || val.isEmpty) return fallback;
      String cleaned = val.replaceAll(RegExp(r'[^0-9.]'), '');
      return cleaned.isEmpty ? fallback : cleaned;
    }

    final ltcg = cleanData(prefs.getString('ltcg_rate'), '12.5');
    final stcg = cleanData(prefs.getString('stcg_rate'), '20.0');
    final exemption = cleanData(prefs.getString('exemption_limit'), '125000');
    final slab = cleanData(prefs.getString('income_slab'), '30');

    var request = http.MultipartRequest('POST', Uri.parse(apiEndpoint));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    request.fields['password'] = password;
    request.fields['ltcg_rate'] = ltcg;
    request.fields['stcg_rate'] = stcg;
    request.fields['exemption_limit'] = exemption;
    request.fields['income_slab'] = slab;

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    try {
      // NEW SAFETY CHECK: If the response is HTML (server crash), catch it cleanly.
      if (!response.body.trim().startsWith('{')) {
         throw Exception('Server crashed (Status ${response.statusCode}). Check Render logs.');
      }

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return responseData;
      } else {
        dynamic detail = responseData['detail'] ?? 'Unknown processing error';
        if (detail is List) {
          throw Exception('FastAPI Validation Error: Check form parameters');
        }
        throw Exception(detail.toString());
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Network error or server unavailable');
    }
  }
}
