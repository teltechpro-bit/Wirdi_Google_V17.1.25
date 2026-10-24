import 'package:flutter_test/flutter_test.dart';
import 'package:wirdi/core/services/voice_search_resolver.dart';
import 'package:wirdi/core/services/wirdi_browse_text.dart';

const _surahs = [
  VoiceSurahEntry(1, 'الفاتحة', 'Al-Fatihah'),
  VoiceSurahEntry(2, 'البقرة', 'Al-Baqarah'),
  VoiceSurahEntry(3, 'آل عمران', "Ali 'Imran"),
  VoiceSurahEntry(18, 'الكهف', 'Al-Kahf'),
  VoiceSurahEntry(19, 'مريم', 'Maryam'),
  VoiceSurahEntry(20, 'طه', 'Ta-Ha'),
  VoiceSurahEntry(36, 'يس', 'Ya-Sin'),
  VoiceSurahEntry(55, 'الرحمن', 'Ar-Rahman'),
  VoiceSurahEntry(67, 'الملك', 'Al-Mulk'),
  VoiceSurahEntry(112, 'الإخلاص', 'Al-Ikhlas'),
  VoiceSurahEntry(114, 'الناس', 'An-Nas'),
];

const _stations = [
  VoiceStationEntry('w2q_radio_egypt', 'إذاعة القرآن الكريم من مصر', 'Egypt Holy Quran Radio', 'Egypt'),
  VoiceStationEntry('w2q_radio_kuwait', 'إذاعة القرآن الكريم من الكويت', 'Kuwait Quran Radio', 'Kuwait'),
  VoiceStationEntry('external_radio_jordan', 'إذاعة القرآن الكريم من الأردن', 'Jordan Holy Quran Radio', 'Jordan'),
];

VoiceSearchResult _r(String q) => VoiceSearchResolver.resolve(q, surahs: _surahs, stations: _stations);

void expectSurah(String q, int number) {
  final r = _r(q);
  expect(r.target, VoiceTarget.surah, reason: q);
  expect(r.surah, number, reason: q);
}

void expectStation(String q, String id) {
  final r = _r(q);
  expect(r.target, VoiceTarget.station, reason: q);
  expect(r.stationId, id, reason: q);
}

void main() {
  group('VoiceSearchResolver surahs', () {
    test('Arabic requests, with tashkeel and filler words', () {
      expectSurah('شغّل سورة البقرة', 2);
      expectSurah('سورة الاخلاص', 112);
      expectSurah('شغل سورة آل عمران', 3);
    });
    test('English requests and transliteration variants', () {
      expectSurah('play Surah Al-Baqarah', 2);
      expectSurah('play surah baqara', 2);
      expectSurah('play Ar-Rahman', 55);
      expectSurah('play surah an nas', 114);
      expectSurah('play surah Yasin', 36);
      expectSurah('play surah Taha', 20);
      expectSurah('play Surah Maryam', 19);
    });
    test('surah number, including Arabic-Indic digits', () {
      expectSurah('surah 36', 36);
      expectSurah('شغل سورة ٣٦', 36);
    });
    test('out-of-range numbers and unknown requests match nothing', () {
      expect(_r('surah 200').target, VoiceTarget.none);
      expect(_r('hello world').target, VoiceTarget.none);
    });
    test('only command words do not resolve', () {
      expect(_r('play surah').target, VoiceTarget.none);
      expect(_r('').target, VoiceTarget.none);
    });
  });

  group('VoiceSearchResolver radio', () {
    test('Arabic and English station requests', () {
      expectStation('شغل اذاعة الكويت', 'w2q_radio_kuwait');
      expectStation('play Kuwait radio', 'w2q_radio_kuwait');
      expectStation('play Egypt Quran radio', 'w2q_radio_egypt');
    });
  });

  group('VoiceSearchResolver.normalize', () {
    test('removes tashkeel/tatweel and unifies letter forms', () {
      expect(VoiceSearchResolver.normalize('الْبَقَرَةِ'), 'البقره');
      expect(VoiceSearchResolver.normalize('آل  عِمْرَان'), 'ال عمران');
    });
    test('converts Arabic-Indic digits and strips punctuation', () {
      expect(VoiceSearchResolver.normalize('سورة ٣٦!'), 'سوره 36');
      expect(VoiceSearchResolver.normalize("Al-Ma'idah"), 'al maidah');
    });
  });

  group('WirdiBrowseText', () {
    test('Arabic UI shows Arabic titles with English subtitle', () {
      const t = WirdiBrowseText(arabic: true);
      expect(t.surahTitle('البقرة', 'Al-Baqarah'), 'البقرة');
      expect(t.surahSubtitle('البقرة', 'Al-Baqarah'), 'Al-Baqarah');
      expect(t.surahsFolder, 'سور القرآن الكريم');
    });
    test('English UI shows English titles with Arabic subtitle', () {
      const t = WirdiBrowseText(arabic: false);
      expect(t.surahTitle('البقرة', 'Al-Baqarah'), 'Al-Baqarah');
      expect(t.surahSubtitle('البقرة', 'Al-Baqarah'), 'البقرة');
      expect(t.surahsFolder, 'Quran Surahs');
      expect(t.radioFolder, 'Quran Radio');
    });
    test('falls back to the other language when a name is missing', () {
      const t = WirdiBrowseText(arabic: false);
      expect(t.surahTitle('البقرة', ''), 'البقرة');
      expect(t.stationTitle('إذاعة', ''), 'إذاعة');
    });
  });
}