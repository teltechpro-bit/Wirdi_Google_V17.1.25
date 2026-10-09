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
 final String url, downloadUrl, surahName;
 final String surahNameAr, surahNameEn;
 final int surahNumber;

 const Way2QuranAudioFile({
  required this.url,
  required this.downloadUrl,
  required this.surahNumber,
  required this.surahName,
  this.surahNameAr = '',
  this.surahNameEn = '',
 });

 /// Uses the requested language first, then a meaningful API fallback.
 String name(bool ar) {
  final preferred = ar ? surahNameAr : surahNameEn;
  if (preferred.trim().isNotEmpty) return preferred;
  if (surahName.trim().isNotEmpty) return surahName;
  return ar ? 'سورة $surahNumber' : 'Surah $surahNumber';
 }

 factory Way2QuranAudioFile.fromJson(Map j) {
  final info = j['surahInfo'] is Map
      ? Map<String, dynamic>.from(j['surahInfo'])
      : <String, dynamic>{};
  final arabic = '${info['arabicName'] ?? info['nameAr'] ?? j['surahNameAr'] ?? ''}'.trim();
  final english = '${info['englishName'] ?? info['nameEn'] ?? j['surahNameEn'] ?? ''}'.trim();
  final generic = '${info['name'] ?? j['surahName'] ?? ''}'.trim();
  return Way2QuranAudioFile(
   url: '${j['url'] ?? ''}',
   downloadUrl: '${j['downloadURL'] ?? j['downloadUrl'] ?? j['download_url'] ?? j['url'] ?? ''}',
   surahNumber: int.tryParse('${j['surahNumber'] ?? info['number'] ?? 0}') ?? 0,
   surahName: arabic.isNotEmpty ? arabic : (english.isNotEmpty ? english : generic),
   surahNameAr: arabic.isNotEmpty ? arabic : generic,
   surahNameEn: english.isNotEmpty ? english : generic,
  );
 }
}

class Way2QuranRecitersPage {
  final List<Way2QuranReciter> reciters;
  final int totalCount, page, pages;
  const Way2QuranRecitersPage({required this.reciters, required this.totalCount, required this.page, required this.pages});
  bool get hasNext => page < pages;
}

class Way2QuranSearchSurah {
  final String slug, arabicName, englishName;
  final int number, pageNumber;
  const Way2QuranSearchSurah({required this.slug,required this.arabicName,required this.englishName,required this.number,required this.pageNumber});
  factory Way2QuranSearchSurah.fromJson(Map<String,dynamic> j)=>Way2QuranSearchSurah(
    slug:'${j['slug']??''}',arabicName:'${j['arabicName']??j['nameAr']??j['name']??''}',
    englishName:'${j['englishName']??j['nameEn']??j['name']??''}',
    number:int.tryParse('${j['number']??0}')??0,pageNumber:int.tryParse('${j['pageNumber']??0}')??0);
}
class Way2QuranSearchResults {
  final List<Way2QuranReciter> reciters;
  final List<Way2QuranRecitation> recitations;
  final List<Way2QuranSearchSurah> surahs;
  const Way2QuranSearchResults({required this.reciters,required this.recitations,required this.surahs});
}

class Way2QuranMushaf {
  final String slug, arabicName, englishName, downloadUrl, imageUrl;
  final int totalDownloads;
  const Way2QuranMushaf({required this.slug, required this.arabicName, required this.englishName, required this.downloadUrl, required this.imageUrl, required this.totalDownloads});
  String name(bool ar) => ar ? arabicName : englishName;
  factory Way2QuranMushaf.fromJson(Map<String, dynamic> j) => Way2QuranMushaf(
    slug: j['slug']?.toString() ?? '',
    arabicName: j['arabicName']?.toString() ?? '',
    englishName: j['englishName']?.toString() ?? '',
    downloadUrl: (j['downloadURL'] ?? j['downloadUrl'])?.toString() ?? '',
    imageUrl: (j['imageURL'] ?? j['imageUrl'])?.toString() ?? '',
    totalDownloads: int.tryParse(j['totalDownloads']?.toString() ?? '0') ?? 0,
  );
}
