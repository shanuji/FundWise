import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatementUploadService {
  static const String apiEndpoint = "https://fundwise-backend-coow.onrender.com/api/v1/parse-cas";

  Future<Map<String, dynamic>?> uploadAndProcessPDF() async {
    const XTypeGroup pdfGroup = XTypeGroup(
      label: 'PDFs',
      extensions: <String>['pdf'],
    );
    
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[pdfGroup]);

    if (file == null || file.path.isEmpty) {
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final ltcg = prefs.getString('ltcg_rate') ?? '12.5';
    final stcg = prefs.getString('stcg_rate') ?? '20.0';
    final exemption = prefs.getString('exemption_limit') ?? '125000';
    String rawSlab = prefs.getString('income_slab') ?? '30%';
    final slab = rawSlab.replaceAll('%', '').trim();

    var request = http.MultipartRequest('POST', Uri.parse(apiEndpoint));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    request.fields['ltcg_rate'] = ltcg;
    request.fields['stcg_rate'] = stcg;
    request.fields['exemption_limit'] = exemption;
    request.fields['income_slab'] = slab;

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to process statement: ${response.statusCode}');
    }
  }
}
