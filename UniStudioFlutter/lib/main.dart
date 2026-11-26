import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'store.dart';
import 'board.dart';

void main() async{
 WidgetsFlutterBinding.ensureInitialized();
 final s=Store();await s.open();runApp(UniStudio(store:s));
}
const sections=<String,(String,IconData)>{
 'home':('Panoramica',Icons.home_outlined),'agenda':('Agenda',Icons.calendar_today),'planner':('Planner',Icons.event_note),
 'tasks':('Promemoria',Icons.check_circle_outline),'courses':('Materie',Icons.school_outlined),'exams':('Esami',Icons.assignment_outlined),
 'notes':('Appunti',Icons.notes),'notebooks':('Quaderni',Icons.draw_outlined),'maps':('Mappe concettuali',Icons.account_tree_outlined),
 'library':('Biblioteca',Icons.local_library_outlined),'cards':('Flashcard',Icons.style_outlined),'focus':('Focus',Icons.timer_outlined),
 'tutor':('Alessandro',Icons.favorite_outline),'stats':('Progressi',Icons.bar_chart),'settings':('Impostazioni',Icons.settings_outlined)
};
String day(DateTime d)=>d.toIso8601String().substring(0,10);
class UniStudio extends StatefulWidget{
 const UniStudio({super.key,required this.store});final Store store;
 @override State<UniStudio> createState()=>_UniStudioState();
}
class _UniStudioState extends State<UniStudio>{
 Store get s=>widget.store;
 String page='home',theme='Sistema',name='Sara',query='',avatar='';
 List<Entry> rows=[];List<String> widgets=['tasks','exams','agenda','stats','notes','focus'];
 bool ready=false,busy=false;Timer? timer;DateTime? deadline;int seconds=1500;
 @override void initState(){super.initState();load();}
 @override void dispose(){timer?.cancel();super.dispose();}
 Future<void> load()async{
  final data=await s.all();final n=await s.get('name'),t=await s.get('theme'),w=await s.get('widgets'),a=await s.get('avatar');
  if(!mounted)return;setState((){rows=data;name=n??'Sara';theme=t??'Sistema';avatar=a??'';if(w!=null)widgets=(jsonDecode(w) as List).cast<String>().where(sections.containsKey).toList();ready=true;});
 }
 List<Entry> of(String k)=>rows.where((r)=>r['kind']==k).toList();
 String title(String k)=>sections[k]?.$1??k;
 void go(String k)=>setState((){page=k;query='';});
 void toast(BuildContext c,String msg){if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(msg)));}
 Future<void> guard(BuildContext c,Future<void> Function() action)async{
  if(busy)return;setState(()=>busy=true);try{await action();}catch(e){toast(c,e.toString());}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> edit(BuildContext c,String kind,[Entry? row])async{
  final t=TextEditingController(text:row?['title'] as String?),b=TextEditingController(text:row?['body'] as String?),d=TextEditingController(text:row?['due'] as String?);
  final ok=await showDialog<bool>(context:c,builder:(ctx)=>AlertDialog(title:Text(row==null?'Nuovo elemento':'Modifica'),content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
  TextField(controller:t,autofocus:true,decoration:InputDecoration(labelText:kind=='cards'?'Domanda':'Titolo')),
  TextField(controller:b,maxLines:5,decoration:InputDecoration(labelText:kind=='cards'?'Risposta':'Descrizione')),
  if(['agenda','planner','tasks','exams'].contains(kind))TextField(controller:d,readOnly:true,decoration:const InputDecoration(labelText:'Data'),onTap:()async{final picked=await showDatePicker(context:ctx,firstDate:DateTime(2000),lastDate:DateTime(2100),initialDate:DateTime.tryParse(d.text)??DateTime.now());if(picked!=null)d.text=day(picked);})
  ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Annulla')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Salva'))]));
  if(ok==true&&t.text.trim().isNotEmpty){if(row==null){await s.add(kind,t.text.trim(),body:b.text,due:d.text);}else{await s.update(row['id'] as int,{'title':t.text.trim(),'body':b.text,'due':d.text});}await load();}
  t.dispose();b.dispose();d.dispose();
 }
 Future<void> openRow(BuildContext c,Entry r)async{
  final k=r['kind'] as String;final ex=s.extra(r);
  if(k=='maps'||k=='notebooks'){await Navigator.of(c).push(MaterialPageRoute(builder:(_)=>BoardPage(store:s,row:r,map:k=='maps')));await load();return;}
  if(k=='library'&&ex['file'] is String){await guard(c,()async{await Share.shareXFiles([XFile(s.path(ex['file'] as String))],sharePositionOrigin:const Rect.fromLTWH(20,20,100,100));});return;}
  if(k=='cards'){
   final v=await showDialog<int>(context:c,builder:(ctx)=>AlertDialog(title:Text(r['title'] as String),content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('Prova a rispondere.'),ExpansionTile(title:const Text('Mostra risposta'),children:[Text(r['body'] as String)])]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,1),child:const Text('Difficile')),TextButton(onPressed:()=>Navigator.pop(ctx,3),child:const Text('Buona')),FilledButton(onPressed:()=>Navigator.pop(ctx,7),child:const Text('Facile'))]));
   if(v!=null){await s.update(r['id'] as int,{'due':day(DateTime.now().add(Duration(days:v)))});await load();}return;
  }
  await edit(c,k,r);
 }
 Future<void> delete(BuildContext c,Entry r)async{
  final ok=await showDialog<bool>(context:c,builder:(ctx)=>AlertDialog(title:const Text('Eliminare questo elemento?'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Annulla')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Elimina'))]));
  if(ok==true){await s.remove(r['id'] as int);await load();}
 }
 Widget tile(BuildContext c,Entry r)=>Card(child:ListTile(
  leading:['tasks','exams','planner'].contains(r['kind'])?Checkbox(value:r['done']==1,onChanged:(v)async{await s.update(r['id'] as int,{'done':v==true?1:0});await load();}):Icon(sections[r['kind']]?.$2??Icons.description),
  title:Text(r['title'] as String),subtitle:Text([r['due'],r['body']].where((v)=>v!=null&&v.toString().isNotEmpty).join(' · '),maxLines:2,overflow:TextOverflow.ellipsis),
  onTap:()=>openRow(c,r),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit'){edit(c,r['kind'] as String,r);}else{delete(c,r);}},itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Modifica')),PopupMenuItem(value:'delete',child:Text('Elimina'))])));
 Widget card(String label,Widget child)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w600)),const SizedBox(height:12),child])));
 Widget home(BuildContext c){
  final h=DateTime.now().hour,g=h<12?'Buongiorno':h<18?'Buon pomeriggio':'Buonasera';
  return ListView(padding:const EdgeInsets.all(20),children:[Text(g+' '+name,style:Theme.of(c).textTheme.headlineLarge),Text(day(DateTime.now())),const SizedBox(height:16),
   LayoutBuilder(builder:(ctx,b)=>Wrap(spacing:12,runSpacing:12,children:widgets.map((k)=>SizedBox(width:b.maxWidth>650?(b.maxWidth-12)/2:b.maxWidth,child:card(title(k),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     if(k=='stats')Text(of('sessions').length.toString()+' sessioni concluse')else if(k=='focus')const Text('25 minuti di concentrazione')else if(of(k).where((r)=>r['done']==0).isEmpty)const Text('Nessun elemento')else ...of(k).where((r)=>r['done']==0).take(3).map((r)=>Text(r['title'] as String,maxLines:1,overflow:TextOverflow.ellipsis)),
     TextButton(onPressed:()=>go(k),child:const Text('Apri'))
   ])))).toList())),
   TextButton.icon(onPressed:()=>go('settings'),icon:const Icon(Icons.tune),label:const Text('Personalizza Home'))]);
 }
 void start(){
  if(timer!=null)return;deadline=DateTime.now().add(Duration(seconds:seconds));
  timer=Timer.periodic(const Duration(seconds:1),(_)async{
   final left=deadline!.difference(DateTime.now()).inSeconds.clamp(0,1500).toInt();
   if(!mounted)return;setState(()=>seconds=left);
   if(left==0){timer?.cancel();timer=null;await s.add('sessions','Focus',body:'25 minuti',due:day(DateTime.now()));await load();if(mounted)setState(()=>seconds=1500);}
  });setState((){});
 }
 Widget focus()=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Text('Una cosa alla volta'),Text((seconds~/60).toString().padLeft(2,'0')+':'+(seconds%60).toString().padLeft(2,'0'),style:const TextStyle(fontSize:76,fontWeight:FontWeight.w300)),Wrap(spacing:12,children:[FilledButton(onPressed:timer==null?start:null,child:const Text('Inizia')),OutlinedButton(onPressed:(){timer?.cancel();timer=null;setState(()=>seconds=1500);},child:const Text('Azzera'))])]));
 Widget stats()=>ListView(padding:const EdgeInsets.all(20),children:[card('Sessioni negli ultimi 7 giorni',Column(children:List.generate(7,(i){final d=day(DateTime.now().subtract(Duration(days:6-i)));final n=of('sessions').where((r)=>r['due']==d).length;return Padding(padding:const EdgeInsets.all(6),child:Row(children:[SizedBox(width:90,child:Text(d.substring(5))),Expanded(child:LinearProgressIndicator(value:(n/8).clamp(0,1).toDouble())),const SizedBox(width:12),Text('$n')]));}))),card('Esami completati',Text(of('exams').where((r)=>r['done']==1).length.toString()))]);
 Future<void> plan(BuildContext c)async{
  final exams=of('exams').where((r)=>r['done']==0&&(r['due'] as String).isNotEmpty).toList()..sort((a,b)=>(a['due'] as String).compareTo(b['due'] as String));
  final occupied=rows.where((r)=>['agenda','planner'].contains(r['kind'])).map((r)=>r['due']).toSet();
  var count=0;for(final e in exams){for(var i=0;i<14;i++){final d=day(DateTime.now().add(Duration(days:i)));if(d.compareTo(e['due'] as String)>=0)break;if(occupied.add(d)){await s.add('planner','Ripasso: '+(e['title'] as String),body:'25 minuti',due:d);count++;break;}}}await load();toast(c,'Sessioni proposte: $count');
 }
 Future<void> pick(BuildContext c,bool isAvatar)async{await guard(c,()async{final f=await FilePicker.platform.pickFiles(type:isAvatar?FileType.image:FileType.any);final path=f?.files.single.path;if(path==null)return;final n=await s.attach(path);if(isAvatar){await s.set('avatar',n);}else{await s.add('library',f!.files.single.name,extra:{'file':n});}await load();});}
 Widget tutor(BuildContext c)=>ListView(padding:const EdgeInsets.all(20),children:[Center(child:CircleAvatar(radius:50,foregroundImage:avatar.isEmpty?null:FileImage(File(s.path(avatar))),child:const Icon(Icons.favorite_outline,size:40))),card('Alessandro • offline',const Text('Un passo alla volta. Ogni piccolo progresso conta.')),card('Dediche',Column(children:[...of('tutor').map((r)=>tile(c,r)),TextButton(onPressed:()=>edit(c,'tutor'),child:const Text('Aggiungi dedica'))])),card('Ripasso',TextButton(onPressed:()=>go('cards'),child:const Text('Apri le flashcard')))]);
 Widget settings(BuildContext c)=>ListView(padding:const EdgeInsets.all(20),children:[
 card('Profilo',Column(children:[ListTile(title:Text(name),trailing:const Icon(Icons.edit),onTap:()async{final ctrl=TextEditingController(text:name);final n=await showDialog<String>(context:c,builder:(ctx)=>AlertDialog(title:const Text('Nome'),content:TextField(controller:ctrl),actions:[FilledButton(onPressed:()=>Navigator.pop(ctx,ctrl.text),child:const Text('Salva'))]));if(n!=null&&n.trim().isNotEmpty){await s.set('name',n.trim());await load();}ctrl.dispose();}),ListTile(title:const Text('Avatar Alessandro'),onTap:()=>pick(c,true))])),
 card('Aspetto',DropdownButton<String>(value:theme,items:['Sistema','Chiaro','Scuro'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)async{if(v!=null){await s.set('theme',v);await load();}})),
 card('Widget Home',Column(children:[for(final k in ['tasks','exams','agenda','stats','notes','focus'])SwitchListTile(title:Text(title(k)),value:widgets.contains(k),onChanged:(v)async{final next=[...widgets];if(v){next.add(k);}else{next.remove(k);}await s.set('widgets',jsonEncode(next));await load();}),for(var i=0;i<widgets.length;i++)ListTile(title:Text(title(widgets[i])),trailing:IconButton(icon:const Icon(Icons.arrow_upward),onPressed:i==0?null:()async{final next=[...widgets];final k=next.removeAt(i);next.insert(i-1,k);await s.set('widgets',jsonEncode(next));await load();}))])),
 card('Archivio SQLite',Column(children:[const Text('Dati locali • nessun account'),ListTile(title:const Text('Esporta backup'),enabled:!busy,onTap:()=>guard(c,()async{final f=await s.backup();await Share.shareXFiles([XFile(f.path)],sharePositionOrigin:const Rect.fromLTWH(20,20,100,100));})),ListTile(title:const Text('Importa backup (aggiunge elementi)'),enabled:!busy,onTap:()=>guard(c,()async{final f=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json']);final path=f?.files.single.path;if(path==null)return;final n=await s.import(File(path));await load();toast(c,'Importati $n elementi');}))])),
 const Text('UniStudio Flutter 1.0 • anteprima sviluppo')]);
 Widget content(BuildContext c){
  if(!ready)return const Center(child:CircularProgressIndicator());
  if(query.isNotEmpty){final found=rows.where((r)=>(r['title'].toString()+' '+r['body'].toString()).toLowerCase().contains(query.toLowerCase()));return ListView(padding:const EdgeInsets.all(16),children:[for(final r in found)tile(c,r),if(found.isEmpty)const Text('Nessun risultato')]);}
  if(page=='home')return home(c);if(page=='focus')return focus();if(page=='stats')return stats();if(page=='tutor')return tutor(c);if(page=='settings')return settings(c);
  final data=of(page);return ListView(padding:const EdgeInsets.all(16),children:[
   if(page=='planner')FilledButton.icon(onPressed:()=>guard(c,()=>plan(c)),icon:const Icon(Icons.auto_awesome),label:const Text('Proponi piano di ripasso')),
   if(page=='library')OutlinedButton.icon(onPressed:()=>pick(c,false),icon:const Icon(Icons.file_open),label:const Text('Importa documento locale')),
   if(page=='cards')Text('Da ripassare: '+data.where((r)=>(r['due'] as String).compareTo(day(DateTime.now()))<=0).length.toString()),
   if(data.isEmpty)const Padding(padding:EdgeInsets.all(32),child:Center(child:Text('Nessun elemento. Premi + per iniziare.'))),...data.map((r)=>tile(c,r))]);
 }
 Widget shell(BuildContext c){
  final wide=MediaQuery.sizeOf(c).width>=780;final canAdd=ready&&!['home','focus','stats','tutor','settings'].contains(page);
  Widget menu()=>ListView(padding:const EdgeInsets.all(12),children:[const Padding(padding:EdgeInsets.all(16),child:Text('UniStudio',style:TextStyle(fontSize:24,fontWeight:FontWeight.w700))),for(final e in sections.entries)ListTile(selected:page==e.key,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),leading:Icon(e.value.$2),title:Text(e.value.$1),onTap:(){if(!wide)Navigator.pop(c);go(e.key);})]);
  return Scaffold(drawer:wide?null:Drawer(child:SafeArea(child:menu())),appBar:AppBar(title:Text(title(page)),actions:[IconButton(tooltip:'Ricerca universale',icon:const Icon(Icons.search),onPressed:()async{final ctrl=TextEditingController();final q=await showDialog<String>(context:c,builder:(ctx)=>AlertDialog(title:const Text('Spotlight'),content:TextField(controller:ctrl,autofocus:true,onSubmitted:(v)=>Navigator.pop(ctx,v)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,ctrl.text),child:const Text('Cerca'))]));if(q!=null)setState(()=>query=q.trim());ctrl.dispose();}),if(query.isNotEmpty)IconButton(onPressed:()=>setState(()=>query=''),icon:const Icon(Icons.close))]),floatingActionButton:canAdd?FloatingActionButton(onPressed:()=>edit(c,page),child:const Icon(Icons.add)):null,body:Row(children:[if(wide)SizedBox(width:240,child:SafeArea(child:menu())),if(wide)const VerticalDivider(width:1),Expanded(child:content(c))]));
 }
 @override Widget build(BuildContext c)=>MaterialApp(title:'UniStudio',debugShowCheckedModeBanner:false,themeMode:theme=='Scuro'?ThemeMode.dark:theme=='Chiaro'?ThemeMode.light:ThemeMode.system,theme:ThemeData(useMaterial3:true,colorSchemeSeed:const Color(0xff3478f6)),darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:const Color(0xff3478f6)),home:Builder(builder:shell));
}
