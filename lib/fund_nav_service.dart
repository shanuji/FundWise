import 'dart:convert';

import 'package:http/http.dart' as http;

import 'market_data_cache.dart';

class OpeningValueResolution {
  final double? value;
  final String path;
  const OpeningValueResolution(this.value, this.path);
}

class FundNavService {
  static const String _baseUrl = 'https://api.mfapi.in';
  final MarketDataCache _cache;

  FundNavService({MarketDataCache? cache}) : _cache = cache ?? MarketDataCache.instance;

  Future<OpeningValueResolution> resolveOpeningValue({
    required String isin,
    required String schemeName,
    required double openingUnits,
    required DateTime statementStart,
  }) async {
    if (openingUnits <= 0) return const OpeningValueResolution(0, 'Zero opening units');
    if (isin.isEmpty) return const OpeningValueResolution(null, 'Missing ISIN');

    // The cache stores the exact NAV date, so repeated analysis of the same CAS
    // does not hit the network again.
    for (var daysBack = 0; daysBack <= 7; daysBack++) {
      final date = statementStart.subtract(Duration(days: daysBack));
      final cached = await _cache.cachedNav(isin, date);
      if (cached != null) {
        return OpeningValueResolution(
          openingUnits * cached,
          'Resolved from local NAV cache',
        );
      }
    }

    try {
      var schemeCode = await _cache.cachedSchemeCode(isin);
      if (schemeCode == null || schemeCode.isEmpty) {
        schemeCode = await _resolveSchemeCode(isin, schemeName);
      }
      if (schemeCode == null || schemeCode.isEmpty) {
        return const OpeningValueResolution(null, 'Scheme code unresolved');
      }

      final from = statementStart.subtract(const Duration(days: 7));
      final uri = Uri.parse(
        '$_baseUrl/mf/$schemeCode'
        '?startDate=${_iso(from)}&endDate=${_iso(statementStart)}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return OpeningValueResolution(null, 'MFAPI historical NAV HTTP ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = (body['data'] as List?) ?? const [];
      DateTime? selectedDate;
      double? selectedNav;
      for (final raw in rows) {
        if (raw is! Map) continue;
        final date = _apiDate(raw['date']?.toString());
        final nav = double.tryParse(raw['nav']?.toString() ?? '');
        if (date == null || nav == null || nav <= 0 || date.isAfter(statementStart)) continue;
        if (selectedDate == null || date.isAfter(selectedDate)) {
          selectedDate = date;
          selectedNav = nav;
        }
      }
      if (selectedDate == null || selectedNav == null) {
        return const OpeningValueResolution(null, 'Opening NAV unavailable from MFAPI');
      }
      await _cache.cacheNav(isin, selectedDate, selectedNav);
      return OpeningValueResolution(
        openingUnits * selectedNav,
        'Resolved via direct MFAPI historical NAV + local cache',
      );
    } catch (e) {
      return OpeningValueResolution(null, 'NAV lookup unavailable: $e');
    }
  }

  Future<String?> _resolveSchemeCode(String isin, String schemeName) async {
    final query = Uri.encodeQueryComponent(_searchName(schemeName));
    final uri = Uri.parse('$_baseUrl/mf/search?q=$query');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final results = jsonDecode(response.body);
    if (results is! List) return null;

    final candidates = results.whereType<Map>().take(12).toList();
    final wantsDirect = schemeName.toUpperCase().contains('DIRECT');
    final wantsGrowth = schemeName.toUpperCase().contains('GROWTH');
    final ordered = [...candidates]..sort((a, b) {
      int score(Map x) {
        final name = x['schemeName']?.toString().toUpperCase() ?? '';
        var s = 0;
        if (wantsDirect && name.contains('DIRECT')) s += 20;
        if (!wantsDirect && name.contains('REGULAR')) s += 20;
        if (wantsGrowth && name.contains('GROWTH')) s += 10;
        if (name.contains(_compactName(schemeName))) s += 5;
        return -s;
      }
      return score(a).compareTo(score(b));
    });

    for (final candidate in ordered) {
      final code = candidate['schemeCode']?.toString();
      if (code == null || code.isEmpty) continue;
      try {
        final latest = await http
            .get(Uri.parse('$_baseUrl/mf/$code/latest'))
            .timeout(const Duration(seconds: 8));
        if (latest.statusCode != 200) continue;
        final body = jsonDecode(latest.body) as Map<String, dynamic>;
        final meta = body['meta'] as Map?;
        final growthIsin = meta?['isin_growth']?.toString();
        if (growthIsin == isin) {
          final resolvedName = meta?['scheme_name']?.toString() ?? candidate['schemeName']?.toString() ?? '';
          await _cache.cacheSchemeCode(isin, code, resolvedName);
          return code;
        }
      } catch (_) {
        // Continue with the next candidate. A single failed scheme lookup must
        // never block the entire statement analysis.
      }
    }
    return null;
  }

  String _searchName(String name) {
    var value = name
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\b(ISIN|ADVISOR|NON-DEMAT)\b.*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (value.length > 80) value = value.substring(0, 80);
    return value;
  }

  String _compactName(String name) => _searchName(name).toUpperCase();

  static String _iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime? _apiDate(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    return DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
  }
}
