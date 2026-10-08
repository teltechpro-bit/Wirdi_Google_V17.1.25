import 'dart:convert';
import 'package:http/http.dart' as http;
import 'way2quran_models.dart';

class Way2QuranRepository {
  static const baseUrl='https://way2quran.com/api';
  static const recitations=[
    Way2QuranRecitation(slug:'hafs-an-asim',nameAr:'حفص عن عاصم',nameEn:'Hafs an Asim'),
    Way2QuranRecitation(slug:'douri-abi-amr',nameAr:'الدوري عن أبي عمرو',nameEn:'Al-Duri an Abi Amr'),
    Way2QuranRecitation(slug:'warsh-an-nafi',nameAr:'ورش عن نافع',nameEn:'Warsh an Nafi'),
    Way2QuranRecitation(slug:'qalun-an-nafi',nameAr:'قالون عن نافع',nameEn:'Qalun an Nafi'),
    Way2QuranRecitation(slug:'shuba-an-asim',nameAr:'شعبة عن عاصم',nameEn:'Shu\\'bah an Asim'),
    Way2QuranRecitation(slug:'al-bazzi-an-ibn-kathir',nameAr:'البزي عن ابن كثير',nameEn:'Al-Bazzi an Ibn Kathir'),
    Way2QuranRecitation(slug:'qunbul-an-ibn-kathir',nameAr:'قنبل عن ابن كثير',nameEn:'Qunbul an Ibn Kathir'),
    Way2QuranRecitation(slug:'hisham-an-ibn-amir',nameAr:'هشام عن ابن عامر',nameEn:'Hisham an Ibn Amir'),
    Way2QuranRecitation(slug:'ibn-dhakwan-an-ibn-amir',nameAr:'ابن ذكوان عن ابن عامر',nameEn:'Ibn Dhakwan an Ibn Amir'),
    Way2QuranRecitation(slug:'khalaf-an-hamza',nameAr:'خلف عن حمزة',nameEn:'Khalaf an Hamza'),
    Way2QuranRecitation(slug:'khalad-an-hamza',nameAr:'خلاد عن حمزة',nameEn:'Khallad an Hamza'),
    Way2QuranRecitation(slug:'rawh-an-yaqub',nameAr:'روح عن يعقوب الحضرمي',nameEn:'Rawh an Yaqub'),
    Way2QuranRecitation(slug:'ruways-an-yaqub',nameAr:'رويس عن يعقوب الحضرمي',nameEn:'Ruways an Yaqub'),
    Way2QuranRecitation(slug:'ibn-wardan-an-abu-jafar',nameAr:'ابن وردان عن أبي جعفر',nameEn:'Ibn Wardan an Abu Jafar'),
    Way2QuranRecitation(slug:'ibn-jamaz-an-abu-jafar',nameAr:'ابن جماز عن أبي جعفر',nameEn:'Ibn Jamaz an Abu Jafar'),
  ];
  Future<List<Way2QuranReciter>> getReciters({String recitationSlug='',String search='',String sort='arabicName',int page=1}) async {
    final u=Uri.parse('$baseUrl/reciters').replace(queryParameters:{
      'recitationSlug':recitationSlug,'search':search,'currentPage':'$page','sort':sort,'pageSize':'50',
    });
    final r=await http.get(u).timeout(const Duration(seconds:20));
    if(r.statusCode<200||r.statusCode>=300)throw Exception('Way2Quran reciters HTTP ${r.statusCode}');
    final b=jsonDecode(r.body); final list=b is Map?(b['reciters']??b['data']?['reciters']??b['data']):b;
    return (list is List?list:const []).whereType<Map>().map((e)=>Way2QuranReciter.fromJson(Map<String,dynamic>.from(e))).toList();
  }
  Future<Way2QuranReciter> getReciter(String slug) async {
    final r=await http.get(Uri.parse('$baseUrl/reciters/reciter-profile/${Uri.encodeComponent(slug)}?increaseViews=true')).timeout(const Duration(seconds:20));
    if(r.statusCode<200||r.statusCode>=300)throw Exception('Way2Quran reciter HTTP ${r.statusCode}');
    final b=jsonDecode(r.body); final j=b is Map&&b['reciter'] is Map?b['reciter']:b;
    return Way2QuranReciter.fromJson(Map<String,dynamic>.from(j as Map));
  }
  Future<void> incrementDownload(String slug) async { await http.post(Uri.parse('$baseUrl/mushaf/increment/${Uri.encodeComponent(slug)}')); }
}