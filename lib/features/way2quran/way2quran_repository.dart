import 'dart:convert';
import 'package:http/http.dart' as http;
import 'way2quran_models.dart';

class Way2QuranRepository {
  static const baseUrl = 'https://way2quran.com/api';
  Future<List<Way2QuranReciter>> getReciters({String recitationSlug='', String isTopReciter='', String search='', String sort='arabicName', int page=1, int pageSize=50}) async {
    final uri=Uri.parse('$baseUrl/reciters').replace(queryParameters:{'recitationSlug':recitationSlug,'isTopReciter':isTopReciter,'search':search,'currentPage':'$page','sort':_apiSort(sort),'pageSize':'$pageSize'});
    final data=await _getJson(uri); final raw=data is Map&&data['reciters'] is List?data['reciters'] as List:const [];
    return raw.whereType<Map>().map((e)=>Way2QuranReciter.fromJson(Map<String,dynamic>.from(e))).toList();
  }
  Future<Way2QuranRecitersPage> getRecitersPage({String recitationSlug='',String isTopReciter='',String search='',String sort='arabicName',int page=1,int pageSize=50}) async {
    final uri=Uri.parse('$baseUrl/reciters').replace(queryParameters:{'recitationSlug':recitationSlug,'isTopReciter':isTopReciter,'search':search,'currentPage':'$page','sort':_apiSort(sort),'pageSize':'$pageSize'});
    final data=await _getJson(uri); final raw=data is Map&&data['reciters'] is List?data['reciters'] as List:const [];
    final p=data is Map&&data['pagination'] is Map?Map<String,dynamic>.from(data['pagination']):const <String,dynamic>{};
    return Way2QuranRecitersPage(reciters:raw.whereType<Map>().map((e)=>Way2QuranReciter.fromJson(Map<String,dynamic>.from(e))).toList(),totalCount:int.tryParse('${p['totalCount']??0}')??0,page:int.tryParse('${p['page']??page}')??page,pages:int.tryParse('${p['pages']??1}')??1);
  }
  Future<Way2QuranSearchResults> globalSearch(String query) async {
    final q=query.trim(); if(q.isEmpty)return const Way2QuranSearchResults(reciters:[],recitations:[],surahs:[]);
    final data=await _getJson(Uri.parse('$baseUrl/search').replace(queryParameters:{'q':q}));
    List<dynamic> list(String key)=>data is Map&&data[key] is List?data[key] as List:const [];
    return Way2QuranSearchResults(
      reciters:list('reciters').whereType<Map>().map((e)=>Way2QuranReciter.fromJson(Map<String,dynamic>.from(e))).toList(),
      recitations:list('recitations').whereType<Map>().map((e)=>Way2QuranRecitation.fromJson(Map<String,dynamic>.from(e))).toList(),
      surahs:list('surahs').whereType<Map>().map((e)=>Way2QuranSearchSurah.fromJson(Map<String,dynamic>.from(e))).toList());
  }
  Future<Way2QuranReciter> getReciter(String slug,{bool increaseViews=true}) async { final uri=Uri.parse('$baseUrl/reciters/reciter-profile/${Uri.encodeComponent(slug)}').replace(queryParameters:{'increaseViews':'$increaseViews'}); final data=await _getJson(uri); final value=data is Map&&data['reciter'] is Map?data['reciter']:data; return Way2QuranReciter.fromJson(Map<String,dynamic>.from(value as Map)); }
  Future<Way2QuranReciter> getReciterInfo(String slug) async { final data=await _getJson(Uri.parse('$baseUrl/reciters/${Uri.encodeComponent(slug)}')); final value=data is Map&&data['reciter'] is Map?data['reciter']:data; return Way2QuranReciter.fromJson(Map<String,dynamic>.from(value as Map)); }
  Future<List<Way2QuranRecitation>> getRecitations() async { final data=await _getJson(Uri.parse('$baseUrl/recitations')); final raw=data is Map&&data['recitations'] is List?data['recitations'] as List:data is List?data:const []; return raw.whereType<Map>().map((e)=>Way2QuranRecitation.fromJson(Map<String,dynamic>.from(e))).toList(); }
  Future<Way2QuranRecitation> getRecitation(String slug) async { final data=await _getJson(Uri.parse('$baseUrl/recitations/${Uri.encodeComponent(slug)}')); final value=data is Map&&data['recitation'] is Map?data['recitation']:data; return Way2QuranRecitation.fromJson(Map<String,dynamic>.from(value as Map)); }
  Future<dynamic> getSurah(String slug,{String select=''})=>_getJson(Uri.parse('$baseUrl/surah/${Uri.encodeComponent(slug)}').replace(queryParameters:{'selectField':select}));
  Future<dynamic> getSurahs()=>_getJson(Uri.parse('$baseUrl/surah'));
  Future<List<Way2QuranMushaf>> getMushafs() async { final data=await _getJson(Uri.parse('$baseUrl/mushaf')); final raw=data is Map&&data['data'] is List?data['data'] as List:data is Map&&data['mushafs'] is List?data['mushafs'] as List:data is List?data:const []; return raw.whereType<Map>().map((e)=>Way2QuranMushaf.fromJson(Map<String,dynamic>.from(e))).toList(); }
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

  Future<void> incrementMushafDownload(String slug) async=>_request('POST',Uri.parse('$baseUrl/mushaf/increment/${Uri.encodeComponent(slug)}'));
  Future<List<int>> downloadBytes(String url) async { if(url.isEmpty) throw Exception('Empty download URL'); final response=await http.get(Uri.parse(url)).timeout(const Duration(minutes:2)); if(response.statusCode<200||response.statusCode>=300) throw Exception('Download failed: ${response.statusCode}'); return response.bodyBytes; }
  Future<dynamic> _getJson(Uri uri) async=>jsonDecode((await _request('GET',uri)).body);
  Future<http.Response> _request(String method,Uri uri) async { final response=method=='POST'?await http.post(uri).timeout(const Duration(seconds:30)):await http.get(uri).timeout(const Duration(seconds:30)); if(response.statusCode<200||response.statusCode>=300)throw Exception('Way2Quran API ${response.statusCode}: ${uri.path}'); return response; }
}