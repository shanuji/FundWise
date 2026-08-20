import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatementUploadService {
  static const String apiEndpoint = "https://fundwise-backend-coow.onrender.com/api/v1/parse-cas";
  static const String healthEndpoint = "https://fundwise-backend-coow.onrender.com/health";
  static const Duration requestTimeout = Duration(seconds: 120);
  static const Duration healthTimeout = Duration(seconds: 12);

  Future<bool> checkBackendHealth() async {
    try {
      final response = await http.get(Uri.parse(healthEndpoint)).timeout(healthTimeout);
      return response.statusCode == 200 && response.body.contains('"status":"ok"');
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    }
  }

  Future<Map<String, dynamic>?> uploadAndProcessPDF({String password = ""}) async {
    const XTypeGroup pdfGroup = XTypeGroup(label: 'PDFs', extensions: <String>['pdf']);
    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[pdfGroup]);
    if (file == null || file.path.isEmpty) return null;

    final healthy = await checkBackendHealth();
    if (!healthy) {
      throw Exception('FundWise analysis server is not responding. Please try again in a moment.');
    }

    final prefs = await SharedPreferences.getInstance();
    String cleanData(String? val, String fallback) {
      if (val == null || val.isEmpty) return fallback;
      final cleaned = val.replaceAll(RegExp(r'[^0-9.]'), '');
      return cleaned.isEmpty ? fallback : cleaned;
    }

    final request = http.MultipartRequest('POST', Uri.parse(apiEndpoint));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['password'] = password;
    request.fields['ltcg_rate'] = cleanData(prefs.getString('ltcg_rate'), '12.5');
    request.fields['stcg_rate'] = cleanData(prefs.getString('stcg_rate'), '20.0');
    request.fields['exemption_limit'] = cleanData(prefs.getString('exemption_limit'), '125000');
    request.fields['income_slab'] = cleanData(prefs.getString('income_slab'), '30');

    try {
      final streamedResponse = await request.send().timeout(requestTimeout);
      final response = await http.Response.fromStream(streamedResponse).timeout(requestTimeout);
      final body = response.body.trim();
      if (body.isEmpty) throw Exception('The analysis server returned an empty response.');
      if (!body.startsWith('{')) throw Exception('The analysis server returned an invalid response (HTTP ${response.statusCode}).');
      final responseData = jsonDecode(body);
      if (response.statusCode == 200 && responseData is Map<String, dynamic>) return responseData;
      final detail = responseData is Map ? (responseData['detail'] ?? responseData['message']) : null;
      throw Exception(detail?.toString() ?? 'Unknown processing error');
    } on TimeoutException {
      throw Exception('The server was reached, but CAS analysis did not finish within 120 seconds.');
    } on FormatException {
      throw Exception('The analysis server returned an invalid response.');
    } on SocketException catch (e) {
      throw Exception('Network error while contacting the analysis server: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Unable to contact the analysis server: ${e.message}');
    }
  }
}
