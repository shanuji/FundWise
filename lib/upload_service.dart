import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StatementUploadService {
  static const String apiEndpoint = "https://fundwise-backend-coow.onrender.com/api/v1/parse-cas";
  static const Duration requestTimeout = Duration(seconds: 120);

  Future<Map<String, dynamic>?> uploadAndProcessPDF({String password = ""}) async {
    const XTypeGroup pdfGroup = XTypeGroup(
      label: 'PDFs',
      extensions: <String>['pdf'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[pdfGroup]);
    if (file == null || file.path.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();

    String cleanData(String? val, String fallback) {
      if (val == null || val.isEmpty) return fallback;
      final cleaned = val.replaceAll(RegExp(r'[^0-9.]'), '');
      return cleaned.isEmpty ? fallback : cleaned;
    }

    final ltcg = cleanData(prefs.getString('ltcg_rate'), '12.5');
    final stcg = cleanData(prefs.getString('stcg_rate'), '20.0');
    final exemption = cleanData(prefs.getString('exemption_limit'), '125000');
    final slab = cleanData(prefs.getString('income_slab'), '30');

    final request = http.MultipartRequest('POST', Uri.parse(apiEndpoint));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    request.fields['password'] = password;
    request.fields['ltcg_rate'] = ltcg;
    request.fields['stcg_rate'] = stcg;
    request.fields['exemption_limit'] = exemption;
    request.fields['income_slab'] = slab;

    try {
      final streamedResponse = await request.send().timeout(requestTimeout);
      final response = await http.Response.fromStream(streamedResponse).timeout(
        requestTimeout,
      );

      final body = response.body.trim();
      if (body.isEmpty) {
        throw Exception('The server returned an empty response. Please try again.');
      }

      if (!body.startsWith('{')) {
        throw Exception(
          'The analysis server returned an invalid response (HTTP ${response.statusCode}). Please try again.',
        );
      }

      final responseData = jsonDecode(body);

      if (response.statusCode == 200) {
        if (responseData is! Map<String, dynamic>) {
          throw Exception('The analysis server returned an invalid result.');
        }
        return responseData;
      }

      dynamic detail = responseData is Map ? responseData['detail'] : null;
      dynamic message = responseData is Map ? responseData['message'] : null;
      final errorText = detail ?? message ?? 'Unknown processing error';
      throw Exception(errorText.toString());
    } on TimeoutException {
      throw Exception(
        'Statement analysis timed out after 120 seconds. The server may be busy; please try again.',
      );
    } on FormatException {
      throw Exception('The analysis server returned an invalid response. Please try again.');
    } on SocketException catch (e) {
      throw Exception('Network error while contacting the analysis server: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('Unable to contact the analysis server: ${e.message}');
    }
  }
}
