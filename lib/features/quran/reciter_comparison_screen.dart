import 'package:flutter/material.dart';

import '../../core/data/reciters.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Short, factual, well-known background info for each reciter in
/// [Reciters.all] -- country and recitation style, used so users can
/// pick a reciter based on real distinguishing characteristics rather
/// than name alone.
final Map<String, Map<String, String>> reciterInfo = {
  'ar.alafasy': {
    'ar': 'قارئ كويتي معاصر، إمام وخطيب، صوته من أكثر الأصوات انتشاراً عالمياً خاصة بين الشباب، تلاوته مرتلة واضحة ميسّرة الحفظ.',
    'en': 'Contemporary Kuwaiti reciter and imam; one of the most widely-heard voices worldwide, especially among younger listeners. Clear, measured Murattal style that is easy to follow for memorization.',
  },
  'ar.husary': {
    'ar': 'قارئ مصري راحل، اشتهر بأسلوب ''التحقيق'' البطيء الدقيق في تطبيق أحكام التجويد ومخارج الحروف، ومصحفه المرتل يُعد المرجع الأول لتعليم القراءة الصحيحة.',
    'en': 'Legendary Egyptian reciter, known for the slow, precise ''Tahqiq'' style that carefully applies every tajweed rule -- his Murattal recording is widely used as a teaching reference.',
  },
  'ar.husarymujawwad': {
    'ar': 'النسخة المجودة للشيخ محمود خليل الحصري، تمتاز بروعة الأداء وإتقان النغم ومخارج الحروف بدقة علمية متناهية.',
    'en': 'The Mujawwad recitation by Sheikh Mahmoud Khalil Al-Husary, featuring stunning melodic mastery alongside peerless tajweed precision.',
  },
  'ar.minshawi': {
    'ar': 'قارئ مصري راحل لُقب بـ ''الصوت الباكي''، تمتاز تلاوته بالخشوع العميق والحزن والشجن المؤثر الذي يلامس القلوب مباشرة.',
    'en': 'Renowned Egyptian reciter often called ''The Weeping Voice'', famous for his profound humility and emotionally moving recitation.',
  },
  'ar.minshawimujawwad': {
    'ar': 'النسخة المجودة للشيخ محمد صديق المنشاوي، من أروع التلاوات المجودة في تاريخ العالم الإسلامي، وتفيض بالخشوع والجمال النغمي.',
    'en': 'The Mujawwad recitation by Sheikh Mohamed Siddiq Al-Minshawi, widely regarded as one of the most majestic and moving recordings in Islamic history.',
  },
  'ar.abdulbasitmurattal': {
    'ar': 'قارئ مصري لُقب بـ ''صوت مكة''، أحد أشهر قراء العالم الإسلامي، تلاوته المرتلة واضحة عذبة وسلسة ومحبوبة في كافة الأقطار.',
    'en': 'Iconic Egyptian reciter known as ''The Voice of Makkah'', world-renowned for his clarity, melodic beauty, and breathtaking recitation.',
  },
  'ar.abdulbasitmujawwad': {
    'ar': 'النسخة المجودة الأسطورية للشيخ عبد الباسط عبد الصمد، اشتهر فيها بقوة النبرة وطول النَفَس الباهر وجمال المقامات الصوتية.',
    'en': 'The legendary Mujawwad recitation of Sheikh Abdul Basit, celebrated worldwide for his peerless breath control, power, and vocal range.',
  },
  'ar.abdurrahmaansudais': {
    'ar': 'إمام وخطيب المسجد الحرام بمكة المكرمة، صوته نبرته شجية مميزة ومعروفة في كل أنحاء العالم من خلال بث صلوات التراويح والفرائض.',
    'en': 'Imam and Khateeb of the Grand Mosque in Makkah; his voice is universally recognized through broadcasts of Taraweeh and congregational prayers.',
  },
  'ar.mahermuaiqly': {
    'ar': 'إمام المسجد الحرام بمكة المكرمة، يتميز بقراءة هادئة خاشعة مريحة للنفس وواضحة النبرات.',
    'en': 'Imam of the Grand Mosque in Makkah; known for his serene, tranquil, and deeply reverent recitation style.',
  },
  'ar.saoodshuraym': {
    'ar': 'إمام المسجد الحرام سابقاً، اشتهر بقراءته السريعة المتقنة (الحدر) مع انضباط تام في التجويد ونبرة حماسية مميزة.',
    'en': 'Former Imam of the Grand Mosque in Makkah, renowned for his fluent, rhythmic pace and disciplined recitation.',
  },
  'ar.hudhaify': {
    'ar': 'إمام وخطيب المسجد النبوي الشريف بالمدينة المنورة، شيخ عموم المقارئ، تلاوته متأنية رصينة ومتقنة لأحكام التجويد بأعلى درجات الضبط.',
    'en': 'Senior Imam of the Prophet''s Mosque in Madinah; his recitation is deliberate, sober, and serves as an authority on precise tajweed.',
  },
  'ar.ghamadi': {
    'ar': 'قارئ سعودي، إمام وخطيب، يتميز بصوت عذب نديّ وتلاوة محببة ساهمت في انتشار مصحفه على نطاق واسع في العالم الإسلامي.',
    'en': 'Saudi reciter and imam; celebrated for his sweet, melodious tone and smooth, engaging delivery.',
  },
  'ar.shaatree': {
    'ar': 'قارئ يمني سعودي، يتميز بأسلوب فريد في الترتيل يجمع بين الرقة والخشوع والتأني.',
    'en': 'Popular reciter known for a distinct, gentle, and reflective Murattal style with deep emotional resonance.',
  },
  'ar.ahmedajamy': {
    'ar': 'قارئ سعودي من كبار القراء المعاصرين، صوته قوي جهوري ونبرته دافئة ومؤثرة تترك أثراً كبيراً في السامع.',
    'en': 'Eminent Saudi reciter; recognized for his deep, resonant, and resonant vocal presence that captivates listeners.',
  },
  'ar.muhammadjibreel': {
    'ar': 'قارئ مصري اشتهر بإمامة صلاة التراويح بجامع عمرو بن العاص بالقاهرة ودعائه المؤثر، تلاوته شجية وخاشعة.',
    'en': 'Distinguished Egyptian reciter, widely famous for leading Taraweeh at the historic Amr ibn al-Aas Mosque in Cairo.',
  },
  'ar.yasseraddossari': {
    'ar': 'إمام وخطيب المسجد الحرام بمكة المكرمة، يمتلك صوتاً رخيماً شجياً وأداءً تصويرياً فريداً لآيات القرآن يجمع بين الجمال والخشوع.',
    'en': 'Imam and Khateeb of the Grand Mosque in Makkah; celebrated for his rich tone and evocative expression of the Quranic meanings.',
  },
  'ar.aymanswoid': {
    'ar': 'عالم بالقراءات والتجويد وأحد أبرز أساتذة الإقراء في العصر الحديث، تلاوته التعليمية تمثل الميزان الدقيق لكل حكم وحرف.',
    'en': 'World authority on tajweed and Quranic readings; his instructional recitation exemplifies the absolute standard of Quranic phonetics.',
  },
  'ar.hanirifai': {
    'ar': 'قارئ وإمام سعودي، صوته مفعم بالبكاء والخشوع، وقراءته تفيض بالتضرع والتأثر.',
    'en': 'Saudi reciter and imam, famous for his heartfelt, tearful, and intensely devout recitation.',
  },
  'ar.nasserqatami': {
    'ar': 'إمام وخطيب سعودي من أشهر قراء الرياض، يمتاز بصوت نديّ رقيق وقراءة عذبة عاطفية.',
    'en': 'Prominent Saudi reciter and imam in Riyadh, known for his melodious, warm, and uplifting recitation style.',
  },
};

class ReciterComparisonScreen extends StatefulWidget {
  const ReciterComparisonScreen({super.key});

  @override
  State<ReciterComparisonScreen> createState() => _ReciterComparisonScreenState();
}

class _ReciterComparisonScreenState extends State<ReciterComparisonScreen> {
  late ReciterOption _a = Reciters.all[0];
  late ReciterOption _b = Reciters.all.length > 1 ? Reciters.all[1] : Reciters.all[0];

  Widget _card(ReciterOption option, bool isAr, String languageCode) {
    final info = reciterInfo[option.id];
    return Expanded(
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: option.id,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: Reciters.all
                .map((r) => DropdownMenuItem(value: r.id, child: Text(r.displayNameFor(languageCode), overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (id) => setState(() {
              final selected = Reciters.byId(id!);
              if (option.id == _a.id) {
                _a = selected;
              } else {
                _b = selected;
              }
            }),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(option.displayNameFor(languageCode), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryEmerald)),
                  const Divider(height: 20),
                  Text(
                    info?[isAr ? 'ar' : 'en'] ?? '',
                    textAlign: TextAlign.start,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.localeName == 'ar';
    final languageCode = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(isAr ? 'معلومات عن القراء' : 'Reciter Info'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _card(_a, isAr, languageCode),
            const SizedBox(width: 12),
            _card(_b, isAr, languageCode),
          ],
        ),
      ),
    );
  }
}
