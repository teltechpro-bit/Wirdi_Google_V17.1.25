import 'dart:convert';

import 'package:http/http.dart' as http;

import 'way2quran_models.dart';

class Way2QuranRepository {
  Way2QuranRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
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
    List<dynamic>? find(dynamic value, int depth) {
      if (value is List) return value;
      if (depth >= 5 || value is! Map) return null;
      final direct = value[key];
      if (direct is List) return direct;
      for (final nestedKey in const ['data', 'result', 'results', 'payload', 'items']) {
        final nested = value[nestedKey];
        if (nested is Map || nested is List) {
          final found = find(nested, depth + 1);
          if (found != null) return found;
        }
      }
      return null;
    }

    return find(payload, 0) ??
        (identical(payload, fallback) ? null : find(fallback, 0)) ??
        const <dynamic>[];
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
      'q': search,
      'query': search,
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
      'q': search,
      'query': search,
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
    var parsed = raw.whereType<Map>().map((e) =>
        Way2QuranReciter.fromJson(Map<String, dynamic>.from(e))).toList();

    // Some API deployments ignore the search query parameter. If that
    // happens, fetch the first broad page and filter names locally instead
    // of showing an empty result set for a valid search term.
    if (search.trim().isNotEmpty && parsed.isEmpty) {
      final fallbackUri = Uri.parse('$baseUrl/reciters').replace(
        queryParameters: {
          'recitationSlug': recitationSlug,
          'isTopReciter': isTopReciter,
          'currentPage': '1',
          'sort': _apiSort(sort),
          'pageSize': '100',
        },
      );
      final fallbackResponse = await _getJson(fallbackUri);
      final fallbackPayload = unwrapApiData(fallbackResponse);
      final fallbackRaw = _listPayload(fallbackPayload, 'reciters', fallback: fallbackResponse);
      final needle = search.trim().toLowerCase();
      parsed = fallbackRaw.whereType<Map>()
          .map((e) => Way2QuranReciter.fromJson(Map<String, dynamic>.from(e)))
          .where((reciter) {
            final fields = <String>[
              reciter.slug, reciter.nameAr, reciter.nameEn,
              ...reciter.recitations.expand((r) => [r.slug, r.nameAr, r.nameEn]),
            ];
            return fields.any((field) => field.toLowerCase().contains(needle));
          }).toList();
      if (parsed.isNotEmpty) {
        return Way2QuranRecitersPage(
          reciters: parsed,
          totalCount: parsed.length,
          page: 1,
          pages: 1,
        );
      }
    }

    return Way2QuranRecitersPage(
      reciters: parsed,
      totalCount: int.tryParse('${p['totalCount'] ?? p['total'] ?? 0}') ?? parsed.length,
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

    try {
      final response = await _getJson(
        Uri.parse('$baseUrl/search').replace(
          queryParameters: {'q': q, 'query': q, 'search': q},
        ),
      );
      final payload = unwrapApiData(response);
      List<dynamic> list(String key) =>
          _listPayload(payload, key, fallback: response);
      final results = Way2QuranSearchResults(
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
      if (results.reciters.isNotEmpty ||
          results.recitations.isNotEmpty ||
          results.surahs.isNotEmpty) {
        return results;
      }
    } catch (_) {
      // Continue to the native fallback below when the global endpoint is
      // unavailable or returns an unrecognized response shape.
    }

    // The global search endpoint is not consistently enabled on every API
    // deployment. Fall back to the reciter listing endpoint and the public
    // recitation catalog so searches still produce useful native results.
    List<Way2QuranReciter> reciters = const [];
    try {
      reciters = (await getRecitersPage(search: q, pageSize: 100)).reciters;
    } catch (_) {
      // Keep any recitation matches even if reciter search is unavailable.
    }
    List<Way2QuranRecitation> recitations = const [];
    try {
      final needle = q.toLowerCase();
      recitations = (await getRecitations()).where((item) =>
        item.slug.toLowerCase().contains(needle) ||
        item.nameAr.toLowerCase().contains(needle) ||
        item.nameEn.toLowerCase().contains(needle)
      ).toList();
    } catch (_) {
      // The API may be offline; return whichever result group succeeded.
    }
    return Way2QuranSearchResults(
      reciters: reciters,
      recitations: recitations,
      surahs: const [],
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

  /// Checks that a response is actually a PDF, not an HTML error page.
  static bool isPdfPayload(List<int> bytes) =>
      bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';

  Future<List<int>> downloadBytes(String url) async {
    if (url.isEmpty) throw Exception('Empty download URL');
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
      throw FormatException('Invalid audio download URL');
    }
    final response = await _client
        .get(uri)
        .timeout(const Duration(minutes: 2));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Download failed: ${response.statusCode}');
    }
    if (response.bodyBytes.isEmpty) {
      throw const FormatException('Download returned an empty response');
    }
    return response.bodyBytes;
  }

  Future<dynamic> _getJson(Uri uri) async =>
      jsonDecode((await _request('GET', uri)).body);

  Future<http.Response> _request(String method, Uri uri) async {
    final response = method == 'POST'
        ? await _client.post(uri).timeout(const Duration(seconds: 30))
        : await _client.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Way2Quran API ${response.statusCode}: ${uri.path}');
    }
    return response;
  }
}
