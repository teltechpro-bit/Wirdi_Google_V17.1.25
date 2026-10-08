import 'dart:convert';
import 'package:http/http.dart' as http;
import 'way2quran_models.dart';

/// Native client following the original Way2Quran source project's API contract.
class Way2QuranRepository {
  static const baseUrl = 'https://way2quran.com/api';
  static const recitations = <Way2QuranRecitation>[
    Way2QuranRecitation(slug: 'hafs-an-asim', nameAr: 'حفص عن عاصم', nameEn: 'Hafs an Asim'),
    Way2QuranRecitation(slug: 'warsh-an-nafi', nameAr: 'ورش عن نافع', nameEn: 'Warsh an Nafi'),
    Way2QuranRecitation(slug: 'qalun-an-nafi', nameAr: 'قالون عن نافع', nameEn: 'Qalun an Nafi'),
  ];

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
      'sort': sort,
      'pageSize': '$pageSize',
    });
    final data = await _getJson(uri);
    final raw = data is Map && data['reciters'] is List ? data['reciters'] as List : const [];
    return raw.whereType<Map>().map((e) => Way2QuranReciter.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Way2QuranReciter> getReciter(String slug, {bool increaseViews = true}) async {
    final uri = Uri.parse('$baseUrl/reciters/reciter-profile/${Uri.encodeComponent(slug)}').replace(
      queryParameters: {'increaseViews': '$increaseViews'},
    );
    final data = await _getJson(uri);
    final value = data is Map && data['reciter'] is Map ? data['reciter'] : data;
    return Way2QuranReciter.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<Way2QuranReciter> getReciterInfo(String slug) async {
    final data = await _getJson(Uri.parse('$baseUrl/reciters/${Uri.encodeComponent(slug)}'));
    final value = data is Map && data['reciter'] is Map ? data['reciter'] : data;
    return Way2QuranReciter.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<List<Way2QuranRecitation>> getRecitations() async {
    final data = await _getJson(Uri.parse('$baseUrl/recitations'));
    final raw = data is Map && data['recitations'] is List ? data['recitations'] as List : data is List ? data : const [];
    return raw.whereType<Map>().map((e) => Way2QuranRecitation.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Way2QuranRecitation> getRecitation(String slug) async {
    final data = await _getJson(Uri.parse('$baseUrl/recitations/${Uri.encodeComponent(slug)}'));
    final value = data is Map && data['recitation'] is Map ? data['recitation'] : data;
    return Way2QuranRecitation.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<dynamic> getSurah(String slug, {String select = ''}) => _getJson(
    Uri.parse('$baseUrl/surah/${Uri.encodeComponent(slug)}').replace(queryParameters: {'selectField': select}),
  );

  Future<dynamic> getSurahs() => _getJson(Uri.parse('$baseUrl/surah'));
  Future<dynamic> getMushafs() => _getJson(Uri.parse('$baseUrl/mushaf'));

  Future<void> incrementDownload(String slug) async {
    await _request('POST', Uri.parse('$baseUrl/recitations/increment-download/${Uri.encodeComponent(slug)}'));
  }

  Future<void> incrementDownload(String slug) async { await _request('POST', Uri.parse('$baseUrl/recitations/increment-download/${Uri.encodeComponent(slug)}')); }

  Future<void> incrementMushafDownload(String slug) async {
    await _request('POST', Uri.parse('$baseUrl/mushaf/increment/${Uri.encodeComponent(slug)}'));
  }

  Future<dynamic> _getJson(Uri uri) async {
    final response = await _request('GET', uri);
    return jsonDecode(response.body);
  }

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