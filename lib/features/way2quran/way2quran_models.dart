class Way2QuranRecitation {
 final String slug, nameAr, nameEn;
 const Way2QuranRecitation({required this.slug,required this.nameAr,required this.nameEn});
 String name(bool ar)=>ar?nameAr:nameEn;
 factory Way2QuranRecitation.fromJson(Map<String,dynamic> j)=>Way2QuranRecitation(slug:'${j['slug']??''}',nameAr:'${j['arabicName']??j['nameAr']??j['name']??''}',nameEn:'${j['englishName']??j['nameEn']??j['name']??''}');
}
class Way2QuranReciter {
 final String slug,nameAr,nameEn,photo; final int totalViews; final List<Way2QuranRecitationAudio> recitations;
 const Way2QuranReciter({required this.slug,required this.nameAr,required this.nameEn,required this.photo,required this.totalViews,required this.recitations});
 String name(bool ar)=>ar?nameAr:nameEn;
 factory Way2QuranReciter.fromJson(Map<String,dynamic> j){
  String s(dynamic v)=>v==null?'':v.toString();
  final recs=(j['recitations'] as List? ?? const []).whereType<Map>().map((e){
   final m=Map<String,dynamic>.from(e); final info=m['recitationInfo'] is Map?Map<String,dynamic>.from(m['recitationInfo']):<String,dynamic>{};
   return Way2QuranRecitationAudio(slug:s(info['slug']??m['slug']),nameAr:s(info['arabicName']??info['nameAr']??info['name']),nameEn:s(info['englishName']??info['nameEn']??info['name']),downloadUrl:s(m['downloadURL']??m['downloadUrl']),audioFiles:(m['audioFiles'] as List? ?? const []).whereType<Map>().map(Way2QuranAudioFile.fromJson).toList());
  }).toList();
  return Way2QuranReciter(slug:s(j['slug']),nameAr:s(j['arabicName']??j['nameAr']??j['name']),nameEn:s(j['englishName']??j['nameEn']??j['name']),photo:s(j['photo']??j['image']),totalViews:int.tryParse(s(j['totalViewers']??j['totalViews']))??0,recitations:recs);
 }
}
class Way2QuranRecitationAudio {
 final String slug,nameAr,nameEn,downloadUrl; final List<Way2QuranAudioFile> audioFiles;
 const Way2QuranRecitationAudio({required this.slug,required this.nameAr,required this.nameEn,required this.audioFiles,required this.downloadUrl});
 String name(bool ar)=>ar?nameAr:nameEn;
}
class Way2QuranAudioFile {
 final String url,downloadUrl,surahName; final int surahNumber;
 const Way2QuranAudioFile({required this.url,required this.downloadUrl,required this.surahNumber,required this.surahName});
 factory Way2QuranAudioFile.fromJson(Map j){ final info=j['surahInfo'] is Map?Map<String,dynamic>.from(j['surahInfo']):<String,dynamic>{}; return Way2QuranAudioFile(url:'${j['url']??''}',downloadUrl:'${j['downloadURL']??j['downloadUrl']??j['download_url']??j['url']??''}',surahNumber:int.tryParse('${j['surahNumber']??info['number']??0}')??0,surahName:'${info['arabicName']??info['englishName']??info['name']??j['surahName']??''}'); }
}

class Way2QuranRecitersPage {
  final List<Way2QuranReciter> reciters;
  final int totalCount, page, pages;
  const Way2QuranRecitersPage({required this.reciters, required this.totalCount, required this.page, required this.pages});
  bool get hasNext => page < pages;
}
