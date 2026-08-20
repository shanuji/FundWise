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

    // Prefer a previously verified scheme/NAV mapping. This is the important
    // part of making repeated CAS analysis fast and independent of Render.
    if (isin.isNotEmpty) {
      for (var daysBack = 0; daysBack <= 7; daysBack++) {
        final date = statementStart.subtract(Duration(days: daysBack));
        final cached = await _cache.cachedNav(isin, date);
        if (cached != null && cached > 0) {
          return OpeningValueResolution(openingUnits * cached, 'Resolved from local NAV cache');
        }
      }
    }

    try {
      var schemeCode = isin.isEmpty ? null : await _cache.cachedSchemeCode(isin);
      if (schemeCode == null || schemeCode.isEmpty) {
        schemeCode = await _resolveSchemeCode(isin, schemeName);
      }
      if (schemeCode == null || schemeCode.isEmpty) {
        return const OpeningValueResolution(null, 'Scheme code unresolved');
      }

      final from = statementStart.subtract(const Duration(days: 7));
      final uri = Uri.parse('$_baseUrl/mf/$schemeCode?startDate=${_iso(from)}&endDate=${_iso(statementStart)}');
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
      if (isin.isNotEmpty) await _cache.cacheNav(isin, selectedDate, selectedNav);
      return OpeningValueResolution(openingUnits * selectedNav, 'Resolved via direct MFAPI historical NAV + local cache');
    } catch (e) {
      return OpeningValueResolution(null, 'NAV lookup unavailable: $e');
    }
  }

  Future<String?> _resolveSchemeCode(String isin, String schemeName) async {
    final queries = _searchQueries(schemeName);
    final candidates = <Map<String, dynamic>>[];

    for (final query in queries) {
      try {
        final uri = Uri.parse('$_baseUrl/mf/search?q=${Uri.encodeQueryComponent(query)}');
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final results = jsonDecode(response.body);
        if (results is List) {
          for (final item in results.whereType<Map>()) {
            final map = item.cast<String, dynamic>();
            final code = map['schemeCode']?.toString();
            if (code != null && code.isNotEmpty && !candidates.any((x) => x['schemeCode']?.toString() == code)) {
              candidates.add(map);
            }
          }
        }
      } catch (_) {
        // Try the next simplified query.
      }
      if (candidates.length >= 30) break;
    }

    final ordered = [...candidates]..sort((a, b) => _candidateScore(b, isin, schemeName).compareTo(_candidateScore(a, isin, schemeName)));

    for (final candidate in ordered.take(30)) {
      final code = candidate['schemeCode']?.toString();
      if (code == null || code.isEmpty) continue;
      try {
        final latest = await http.get(Uri.parse('$_baseUrl/mf/$code/latest')).timeout(const Duration(seconds: 8));
        if (latest.statusCode != 200) continue;
        final body = jsonDecode(latest.body);
        if (body is! Map) continue;
        final meta = (body['meta'] as Map?)?.cast<String, dynamic>();
        final metaIsins = <String>{
          meta?['isin_growth']?.toString() ?? '',
          meta?['isin_dividend']?.toString() ?? '',
          meta?['isin']?.toString() ?? '',
        }..remove('');
        final resolvedName = meta?['scheme_name']?.toString() ?? candidate['schemeName']?.toString() ?? '';

        if (isin.isNotEmpty && metaIsins.contains(isin)) {
          await _cache.cacheSchemeCode(isin, code, resolvedName);
          return code;
        }

        // Some older/legacy scheme metadata does not expose ISIN. Only accept
        // a strong name match in that case; never guess from a weak search hit.
        if (isin.isEmpty && _nameScore(resolvedName, schemeName) >= 0.78) {
          return code;
        }
      } catch (_) {
        // A failed candidate must not block the rest of the statement.
      }
    }
    return null;
  }

  List<String> _searchQueries(String name) {
    var value = name
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\b(ISIN|ADVISOR|ARN|NON-DEMAT)\b.*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(FORMERLY|OPTION|PLAN|GROWTH|DIRECT|REGULAR)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final parts = value.split(' ');
    final queries = <String>{};
    if (value.isNotEmpty) queries.add(value);
    if (parts.length > 4) queries.add(parts.take(6).join(' '));
    if (parts.length > 3) queries.add(parts.take(4).join(' '));
    return queries.where((q) => q.isNotEmpty).toList();
  }

  int _candidateScore(Map<String, dynamic> candidate, String isin, String wanted) {
    final name = candidate['schemeName']?.toString() ?? '';
    return (_nameScore(name, wanted) * 100).round() +
        (name.toUpperCase().contains('DIRECT') == wanted.toUpperCase().contains('DIRECT') ? 10 : 0) +
        (name.toUpperCase().contains('GROWTH') == wanted.toUpperCase().contains('GROWTH') ? 5 : 0);
  }

  double _nameScore(String a, String b) {
    final aa = _tokens(a);
    final bb = _tokens(b);
    if (aa.isEmpty || bb.isEmpty) return 0;
    final common = aa.intersection(bb).length;
    return common / bb.length;
  }

  Set<String> _tokens(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((x) => x.length > 2 && !{'DIRECT', 'REGULAR', 'PLAN', 'GROWTH', 'OPTION', 'FUND'}.contains(x))
      .toSet();

  static String _iso(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime? _apiDate(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 3) return null;
    return DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
  }
}
