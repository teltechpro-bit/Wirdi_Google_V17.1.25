import 'dart:convert';

import 'package:http/http.dart' as http;

import 'way2quran_models.dart';

class Way2QuranRepository {
  static const baseUrl = 'https://way2quran.com/api';

  /// Current Way2Quran endpoints wrap successful payloads in {status, data}.
  /// Some older endpoints return the payload directly, so support both shapes.
  static dynamic unwrapApiData(dynamic response) {
    if (response is Map) {
      final status = response['status']?.toString().trim().toLowerCase();
      if (status == 'error' || status == 'failed' || status == 'failure') {
        final message = response['message'] ?? response['error'] ?? 'Unknown API error';
        throw FormatException('Way2Quran API error: $message');
      }
      if (response['data'] != null) return response['data'];
    }
    return response;
  }

  List<dynamic> _listPayload(dynamic payload, String key, {dynamic fallback}) {
    if (payload is List) return payload;
    if (payload is Map && payload[key] is List) return payload[key] as List;
    if (fallback is Map && fallback[key] is List) return fallback[key] as List;
    return const <dynamic>[];
  }

  Future<List<Way2QuranReciter>> getReciters({
    String recitationSlug = '',
    String isTopReciter = '',
    String search = '',
    String sort = 'arabicName',
    int page = 1,
    int pageSize = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/reciters').replace(queryParameters: {
      'recitationSlug': recitationSlug,
      'isTopReciter': isTopReciter,
      'search': search,
      'currentPage': '$page',
      'sort': _apiSort(sort),
      'pageSize': '$pageSize',
    });
    final response = await _getJson(uri);
    final payload = unwrapApiData(response);
    final raw = _listPayload(payload, 'reciters', fallback: response);
    return raw.whereType<Map>().map((e) =>
        Way2QuranReciter.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Way2QuranRecitersPage> getRecitersPage({
    String recitationSlug = '',
    String isTopReciter = '',
    String search = '',
    String sort = 'arabicName',
    int page = 1,
    int pageSize = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/reciters').replace(queryParameters: {
      'recitationSlug': recitationSlug,
      'isTopReciter': isTopReciter,
      'search': search,
      'currentPage': '$page',
      'sort': _apiSort(sort),
      'pageSize': '$pageSize',
    });
    final response = await _getJson(uri);
    final payload = unwrapApiData(response);
    final raw = _listPayload(payload, 'reciters', fallback: response);
    final pagination = response is Map && response['pagination'] is Map
        ? response['pagination']
        : payload is Map && payload['pagination'] is Map
            ? payload['pagination']
            : const <String, dynamic>{};
    final p = Map<String, dynamic>.from(pagination as Map);
    return Way2QuranRecitersPage(
      reciters: raw.whereType<Map>().map((e) =>
          Way2QuranReciter.fromJson(Map<String, dynamic>.from(e))).toList(),
      totalCount: int.tryParse('${p['totalCount'] ?? p['total'] ?? 0}') ?? 0,
      page: int.tryParse('${p['page'] ?? page}') ?? page,
      pages: int.tryParse('${p['pages'] ?? p['totalPages'] ?? 1}') ?? 1,
    );
  }

  Future<Way2QuranSearchResults> globalSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const Way2QuranSearchResults(
          reciters: [], recitations: [], surahs: []);
    }
    final response =
        await _getJson(Uri.parse('$baseUrl/search').replace(queryParameters: {'q': q}));
    final payload = unwrapApiData(response);
    List<dynamic> list(String key) =>
        _listPayload(payload, key, fallback: response);
    return Way2QuranSearchResults(
      reciters: list('reciters')
          .whereType<Map>()
          .map((e) => Way2QuranReciter.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      recitations: list('recitations')
          .whereType<Map>()
          .map((e) => Way2QuranRecitation.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      surahs: list('surahs')
          .whereType<Map>()
          .map((e) => Way2QuranSearchSurah.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Future<Way2QuranReciter> getReciter(String slug,
      {bool increaseViews = true}) async {
    final uri = Uri.parse(
            '$baseUrl/reciters/reciter-profile/${Uri.encodeComponent(slug)}')
        .replace(queryParameters: {'increaseViews': '$increaseViews'});
    final response = await _getJson(uri);
    final payload = unwrapApiData(response);
    final value = payload is Map && payload['reciter'] is Map
        ? payload['reciter']
        : payload;
    return Way2QuranReciter.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<Way2QuranReciter> getReciterInfo(String slug) async {
    final response = await _getJson(
        Uri.parse('$baseUrl/reciters/${Uri.encodeComponent(slug)}'));
    final payload = unwrapApiData(response);
    final value = payload is Map && payload['reciter'] is Map
        ? payload['reciter']
        : payload;
    return Way2QuranReciter.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<List<Way2QuranRecitation>> getRecitations() async {
    final response = await _getJson(Uri.parse('$baseUrl/recitations'));
    final payload = unwrapApiData(response);
    final raw = _listPayload(payload, 'recitations', fallback: response);
    return raw.whereType<Map>().map((e) =>
        Way2QuranRecitation.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Way2QuranRecitation> getRecitation(String slug) async {
    final response = await _getJson(
        Uri.parse('$baseUrl/recitations/${Uri.encodeComponent(slug)}'));
    final payload = unwrapApiData(response);
    final value = payload is Map && payload['recitation'] is Map
        ? payload['recitation']
        : payload;
    return Way2QuranRecitation.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<dynamic> getSurah(String slug, {String select = ''}) async {
    final response = await _getJson(
        Uri.parse('$baseUrl/surah/${Uri.encodeComponent(slug)}')
            .replace(queryParameters: {'selectField': select}));
    return unwrapApiData(response);
  }

  Future<dynamic> getSurahs() async =>
      unwrapApiData(await _getJson(Uri.parse('$baseUrl/surah')));

  Future<List<Way2QuranMushaf>> getMushafs() async {
    final response = await _getJson(Uri.parse('$baseUrl/mushaf'));
    final payload = unwrapApiData(response);
    final raw = _listPayload(payload, 'mushafs', fallback: response);
    return raw.whereType<Map>().map((e) =>
        Way2QuranMushaf.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  String _apiSort(String sort) {
    switch (sort) {
      case 'mostListened':
        return '-number';
      case 'views':
        return '-totalViewers';
      case '-number':
      case '-totalViewers':
      case 'arabicName':
        return sort;
      default:
        return 'arabicName';
    }
  }

  Future<void> incrementMushafDownload(String slug) async =>
      _request('GET', Uri.parse(
          '$baseUrl/mushaf/increment/${Uri.encodeComponent(slug)}'));

  Future<List<int>> downloadBytes(String url) async {
    if (url.isEmpty) throw Exception('Empty download URL');
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 2));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download failed: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  Future<dynamic> _getJson(Uri uri) async =>
      jsonDecode((await _request('GET', uri)).body);

  Future<http.Response> _request(String method, Uri uri) async {
    final response = method == 'POST'
        ? await http.post(uri).timeout(const Duration(seconds: 30))
        : await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Way2Quran API ${response.statusCode}: ${uri.path}');
    }
    return response;
  }
}
