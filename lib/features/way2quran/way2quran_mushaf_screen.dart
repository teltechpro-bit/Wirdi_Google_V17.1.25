import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'way2quran_models.dart';
import 'way2quran_repository.dart';

class Way2QuranMushafScreen extends StatefulWidget {
  const Way2QuranMushafScreen({super.key});
  @override State<Way2QuranMushafScreen> createState()=>_Way2QuranMushafScreenState();
}
class _Way2QuranMushafScreenState extends State<Way2QuranMushafScreen>{
  final repo=Way2QuranRepository();
  late Future<List<Way2QuranMushaf>> future;
  final downloading=<String>{};
  @override void initState(){super.initState();future=repo.getMushafs();}
  Future<void> _download(Way2QuranMushaf m,bool ar) async {
    if(m.downloadUrl.isEmpty)return;
    setState(()=>downloading.add(m.slug));
    try {
      final bytes=await repo.downloadBytes(m.downloadUrl);
      final dir=await getApplicationDocumentsDirectory();
      final folder=Directory('${dir.path}/way2quran/mushaf'); await folder.create(recursive:true);
      final file=File('${folder.path}/${m.slug}.pdf'); await file.writeAsBytes(bytes,flush:true);
      await repo.incrementMushafDownload(m.slug);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ar?'تم تنزيل المصحف داخل Wirdi':'Mushaf downloaded inside Wirdi')));
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(ar?'تعذر تنزيل المصحف':'Could not download the Mushaf')));
    } finally { if(mounted)setState(()=>downloading.remove(m.slug)); }
  }
  @override Widget build(BuildContext context){
    final ar=Localizations.localeOf(context).languageCode=='ar';
    return Scaffold(appBar:AppBar(title:Text(ar?'المصاحف':'Mushaf')),body:FutureBuilder<List<Way2QuranMushaf>>(future:future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(s.hasError)return Center(child:FilledButton.icon(onPressed:()=>setState(()=>future=repo.getMushafs()),icon:const Icon(Icons.refresh),label:Text(ar?'إعادة المحاولة':'Retry')));
      final items=s.data??const <Way2QuranMushaf>[];
      if(items.isEmpty)return Center(child:Text(ar?'لا توجد مصاحف متاحة':'No Mushaf available'));
      return ListView.separated(padding:const EdgeInsets.all(16),itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(height:12),itemBuilder:(context,i){
        final m=items[i]; final busy=downloading.contains(m.slug);
        return Card(child: ListTile(contentPadding: const EdgeInsets.all(14), leading:m.imageUrl.isEmpty?const CircleAvatar(child:Icon(Icons.menu_book_rounded)):ClipRRect(borderRadius:BorderRadius.circular(10),child:Image.network(m.imageUrl,width:52,height:64,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const CircleAvatar(child:Icon(Icons.menu_book_rounded)))),title:Text(m.name(ar),style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text((m.totalDownloads).toString()+' '+(ar?'تنزيل':'downloads')),trailing: busy ? const SizedBox(width:28,height:28,child:CircularProgressIndicator(strokeWidth:2.5)) : IconButton(onPressed:()=>_download(m,ar),icon:const Icon(Icons.download_rounded))));
      });
    }));
  }
}
