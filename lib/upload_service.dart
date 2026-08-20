import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'local_cas_parser.dart';

class StatementUploadService {
  final LocalCasParser _parser;
  XFile? _selectedFile;

  StatementUploadService({LocalCasParser? parser}) : _parser = parser ?? LocalCasParser();

  XFile? get selectedFile => _selectedFile;

  Future<XFile?> selectPDF() async {
    const pdfGroup = XTypeGroup(label: 'PDFs', extensions: <String>['pdf']);
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[pdfGroup]);
    if (file == null || file.path.isEmpty) return null;
    _selectedFile = file;
    return file;
  }

  void clearSelection() => _selectedFile = null;

  Future<Map<String, dynamic>> analyzeSelectedPDF({String password = ''}) async {
    final file = _selectedFile;
    if (file == null || file.path.isEmpty || !File(file.path).existsSync()) {
      throw Exception('Please upload a CAS PDF first.');
    }
    return _parser.parseFile(path: file.path, password: password);
  }
}
