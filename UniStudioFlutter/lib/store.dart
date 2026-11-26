import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

typedef Entry = Map<String,Object?>;
class Store {
  late Database db;
  late Directory files;
  Future<void> open() async {
    files = Directory(p.join((await getApplicationDocumentsDirectory()).path,'unistudio_files'));
    await files.create(recursive:true);
    db = await openDatabase(p.join(await getDatabasesPath(),'unistudio.sqlite'),version:1,
      onConfigure:(d)=>d.execute('PRAGMA foreign_keys=ON'),
      onCreate:(d,v) async {
        await d.execute("CREATE TABLE entries(id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', due TEXT NOT NULL DEFAULT '', done INTEGER NOT NULL DEFAULT 0, extra TEXT NOT NULL DEFAULT '{}')");
        await d.execute('CREATE INDEX entries_kind_due ON entries(kind,due)');
        await d.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      });
  }
  Future<List<Entry>> all()=>db.query('entries',orderBy:'id DESC');
  Future<int> add(String kind,String title,{String body='',String due='',Map<String,dynamic> extra=const {}})=>db.insert('entries',{'kind':kind,'title':title,'body':body,'due':due,'extra':jsonEncode(extra)});
  Future<void> update(int id,Entry values) async {await db.update('entries',values,where:'id=?',whereArgs:[id]);}
  Future<void> remove(int id) async {await db.delete('entries',where:'id=?',whereArgs:[id]);}
  Future<String?> get(String key) async {final r=await db.query('settings',where:'key=?',whereArgs:[key]);return r.isEmpty?null:r.first['value'] as String;}
  Future<void> set(String key,String value) async {await db.insert('settings',{'key':key,'value':value},conflictAlgorithm:ConflictAlgorithm.replace);}
  Map<String,dynamic> extra(Entry r)=>Map<String,dynamic>.from(jsonDecode(r['extra'] as String) as Map);
  String path(String name)=>p.join(files.path,p.basename(name));
  Future<String> attach(String source)async{
    final name=DateTime.now().microsecondsSinceEpoch.toString()+'_'+p.basename(source);
    await File(source).copy(path(name));return name;
  }
  Future<File> backup()async{
    final attachments=<String,String>{};var bytes=0;
    await for(final f in files.list(followLinks:false)){if(f is File){bytes+=await f.length();if(bytes>100*1024*1024)throw StateError('Archivio oltre 100 MB');attachments[p.basename(f.path)]=base64Encode(await f.readAsBytes());}}
    final file=File(p.join((await getTemporaryDirectory()).path,'UniStudio-'+DateTime.now().millisecondsSinceEpoch.toString()+'.json'));
    return file.writeAsString(jsonEncode({'schema':'UniStudioFlutter/1','entries':await all(),'settings':await db.query('settings'),'files':attachments}));
  }
  Future<int> import(File file)async{
    if(await file.length()>150*1024*1024)throw FormatException('Backup troppo grande');
    final data=jsonDecode(await file.readAsString()) as Map;
    if(data['schema']=='UniStudioFlutter/1'){
      final rows=(data['entries'] as List).cast<Map>();
      final attachments=Map<String,dynamic>.from(data['files'] as Map);
      final names=<String,String>{};
      final settings=(data['settings'] as List).cast<Map>();
      for(final e in attachments.entries){
        final n=DateTime.now().microsecondsSinceEpoch.toString()+'_'+p.basename(e.key);
        await File(path(n)).writeAsBytes(base64Decode(e.value as String));names[e.key]=n;
      }
      await db.transaction((t)async{
        for(final row in rows){
          final r=Map<String,Object?>.from(row)..remove('id');
          final ex=extra(r);if(names.containsKey(ex['file']))ex['file']=names[ex['file']];
          r['extra']=jsonEncode(ex);await t.insert('entries',r);
        }
        for(final row in settings){
          final r=Map<String,Object?>.from(row);
          if(r['key']=='avatar'&&names.containsKey(r['value']))r['value']=names[r['value']];
          await t.insert('settings',r,conflictAlgorithm:ConflictAlgorithm.replace);
        }
      });return rows.length;
    }
    if(!['courses','lessons','tasks','exams','notes'].every((k)=>data[k] is List))throw FormatException('Backup non riconosciuto');
    const mapping={'courses':'courses','lessons':'agenda','tasks':'tasks','exams':'exams','notes':'notes','sessions':'sessions','cardsV2':'cards','notebooksV5':'notebooks','mapsV10':'maps','plansV3':'planner','resourcesV3':'library'};
    var count=0;
    await db.transaction((t)async{
      for(final e in mapping.entries){
        if(data[e.key] is! List)continue;
        for(final item in data[e.key] as List){
          if(item is! Map)continue;
          final r=Map<String,dynamic>.from(item);
          await t.insert('entries',{'kind':e.value,'title':(r['title']??r['name']??r['question']??r['subject']??'Elemento importato').toString(),'body':(r['body']??r['text']??r['content']??r['answer']??'').toString(),'due':(r['date']??r['due']??'').toString(),'done':r['done']==true||r['done']==1?1:0,'extra':jsonEncode({'legacy':r})});count++;
        }
      }
      await t.insert('settings',{'key':'legacyArchive','value':jsonEncode(data)},conflictAlgorithm:ConflictAlgorithm.replace);
    });return count;
  }
}
