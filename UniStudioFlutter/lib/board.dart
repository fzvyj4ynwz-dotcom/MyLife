import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'store.dart';
class BoardPage extends StatefulWidget{
 const BoardPage({super.key,required this.store,required this.row,required this.map});
 final Store store;final Entry row;final bool map;
 @override State<BoardPage> createState()=>_BoardPageState();
}
class _BoardPageState extends State<BoardPage>{
 List<Map<String,dynamic>> nodes=[],edges=[],strokes=[];String? selected;bool link=false,dirty=false,saving=false;int ink=0xff3478f6;double width=3;
 final boundary=GlobalKey();final undo=<String>[],redo=<String>[];
 @override void initState(){super.initState();restore(widget.store.extra(widget.row));if(widget.map&&nodes.isEmpty)nodes=[{'id':'root','text':widget.row['title'],'x':180.0,'y':100.0,'color':ink}];}
 Map<String,dynamic> snapshot()=>{'nodes':nodes,'edges':edges,'strokes':strokes};
 void restore(Map e){nodes=read(e['nodes']);edges=read(e['edges']);strokes=read(e['strokes']);}
 List<Map<String,dynamic>> read(dynamic v)=>(v is List?v:[]).map((x)=>Map<String,dynamic>.from(x as Map)).toList();
 void remember(){undo.add(jsonEncode(snapshot()));if(undo.length>40)undo.removeAt(0);redo.clear();dirty=true;}
 void history(bool back){final from=back?undo:redo,to=back?redo:undo;if(from.isEmpty)return;to.add(jsonEncode(snapshot()));setState((){restore(jsonDecode(from.removeLast()) as Map);selected=null;dirty=true;});}
 Future<void> save()async{if(saving)return;setState(()=>saving=true);try{final ex=widget.store.extra(widget.row)..addAll(snapshot());await widget.store.update(widget.row['id'] as int,{'extra':jsonEncode(ex)});if(mounted)setState(()=>dirty=false);}finally{if(mounted)setState(()=>saving=false);}}
 Future<void> rename(Map<String,dynamic> n)async{final ctrl=TextEditingController(text:n['text'] as String);final v=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('Concetto'),content:TextField(controller:ctrl,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Annulla')),FilledButton(onPressed:()=>Navigator.pop(c,ctrl.text),child:const Text('Salva'))]));if(v!=null&&v.trim().isNotEmpty){remember();setState(()=>n['text']=v.trim());}ctrl.dispose();}
 Map<String,dynamic>? node(dynamic id){for(final n in nodes){if(n['id']==id)return n;}return null;}
 void add(){remember();final parent=node(selected),id=DateTime.now().microsecondsSinceEpoch.toString();setState((){nodes.add({'id':id,'text':'Nuovo concetto','x':((parent?['x'] as num?)??100).toDouble()+40,'y':((parent?['y'] as num?)??100).toDouble()+80,'color':ink});if(parent!=null)edges.add({'a':parent['id'],'b':id});selected=id;});rename(nodes.last);}
 Future<void> outline()async{final ctrl=TextEditingController();final v=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('Da testo: una voce per riga'),content:TextField(controller:ctrl,maxLines:8),actions:[FilledButton(onPressed:()=>Navigator.pop(c,ctrl.text),child:const Text('Genera'))]));if(v!=null){remember();setState((){if(nodes.isEmpty)nodes.add({'id':'root','text':widget.row['title'],'x':20.0,'y':20.0,'color':ink});final lines=v.split('\n').where((x)=>x.trim().isNotEmpty).take(50).toList();for(var i=0;i<lines.length;i++){final id=DateTime.now().microsecondsSinceEpoch.toString()+'_$i';nodes.add({'id':id,'text':lines[i].trim(),'x':20.0+(i%6)*170,'y':120.0+(i~/6)*100,'color':0xff7568d9});edges.add({'a':nodes.first['id'],'b':id});}});}ctrl.dispose();}
 Future<void> export()async{final b=boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;final img=await b.toImage(pixelRatio:1.5);final data=await img.toByteData(format:ui.ImageByteFormat.png);img.dispose();if(data==null)return;final f=File(p.join((await getTemporaryDirectory()).path,'UniStudio-'+DateTime.now().millisecondsSinceEpoch.toString()+'.png'));await f.writeAsBytes(data.buffer.asUint8List());await Share.shareXFiles([XFile(f.path)],sharePositionOrigin:const Rect.fromLTWH(20,20,100,100));}
 void tap(Map n){if(link&&selected!=null&&selected!=n['id']){remember();edges.add({'a':selected,'b':n['id']});link=false;}setState(()=>selected=n['id'] as String);}
 Future<void> leave()async{if(saving)return;if(dirty)await save();if(mounted)Navigator.pop(context);}
 @override Widget build(BuildContext c){
  return PopScope(canPop:!dirty&&!saving,onPopInvokedWithResult:(didPop,result){if(!didPop)leave();},child:Scaffold(
  appBar:AppBar(title:Text(widget.row['title'] as String),actions:[IconButton(tooltip:'Annulla',onPressed:()=>history(true),icon:const Icon(Icons.undo)),IconButton(tooltip:'Ripeti',onPressed:()=>history(false),icon:const Icon(Icons.redo)),IconButton(tooltip:'Esporta PNG',onPressed:export,icon:const Icon(Icons.ios_share)),TextButton(onPressed:saving?null:save,child:const Text('Salva'))]),
  body:Column(children:[SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
   if(widget.map)...[TextButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Concetto')),TextButton(onPressed:()=>setState(()=>link=!link),child:Text(link?'Tocca destinazione':'Collega')),TextButton(onPressed:outline,child:const Text('Da testo')),TextButton(onPressed:(){remember();setState((){for(var i=0;i<nodes.length;i++){nodes[i]['x']=20.0+(i%6)*170;nodes[i]['y']=20.0+(i~/6)*100;}});},child:const Text('Ordina')),IconButton(onPressed:(){if(selected==null)return;remember();setState((){nodes.removeWhere((n)=>n['id']==selected);edges.removeWhere((e)=>e['a']==selected||e['b']==selected);selected=null;});},icon:const Icon(Icons.delete_outline))],
   for(final color in [0xff26354c,0xff3478f6,0xffd54a6c,0xff32a78d,0xff7568d9])IconButton(onPressed:(){final n=node(selected);if(widget.map&&n!=null)remember();setState((){ink=color;if(widget.map&&n!=null)n['color']=color;});},icon:Icon(Icons.circle,color:Color(color))),
   if(!widget.map)SizedBox(width:130,child:Slider(min:1,max:12,value:width,onChanged:(v)=>setState(()=>width=v)))
  ])),Expanded(child:InteractiveViewer(constrained:false,minScale:0.25,maxScale:4,panEnabled:widget.map,child:RepaintBoundary(key:boundary,child:SizedBox(width:1200,height:1600,child:ColoredBox(color:const Color(0xfff8f9fc),child:Stack(children:[
  Positioned.fill(child:CustomPaint(painter:BoardPainter(nodes,edges,strokes))),
  if(widget.map)for(final n in nodes)Positioned(left:(n['x'] as num).toDouble(),top:(n['y'] as num).toDouble(),child:GestureDetector(onTap:()=>tap(n),onDoubleTap:()=>rename(n),onPanStart:(_)=>remember(),onPanUpdate:(d)=>setState((){n['x']=((n['x'] as num)+d.delta.dx).clamp(0,1040).toDouble();n['y']=((n['y'] as num)+d.delta.dy).clamp(0,1530).toDouble();}),child:Container(width:150,height:58,padding:const EdgeInsets.all(7),alignment:Alignment.center,decoration:BoxDecoration(color:Color(n['color'] as int),borderRadius:BorderRadius.circular(14),border:Border.all(color:selected==n['id']?Colors.black:Colors.transparent,width:2)),child:Text(n['text'] as String,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600))))),
  if(!widget.map)Positioned.fill(child:GestureDetector(behavior:HitTestBehavior.opaque,onPanStart:(d){remember();setState(()=>strokes.add({'color':ink,'width':width,'points':[[d.localPosition.dx,d.localPosition.dy]]}));},onPanUpdate:(d)=>setState(()=>(strokes.last['points'] as List).add([d.localPosition.dx,d.localPosition.dy]))))
  ]))))))]),
  bottomNavigationBar:SafeArea(child:Padding(padding:const EdgeInsets.all(8),child:Text(widget.map?'Tocca un concetto, trascina o tocca due volte per modificare.':'Disegna con dito o penna.',textAlign:TextAlign.center)))));
 }
}
class BoardPainter extends CustomPainter{
 BoardPainter(this.nodes,this.edges,this.strokes);final List<Map<String,dynamic>> nodes,edges,strokes;
 Map<String,dynamic>? node(dynamic id){for(final n in nodes){if(n['id']==id)return n;}return null;}
 @override void paint(Canvas c,Size s){
  final dot=Paint()..color=const Color(0xffdce2ed);for(double x=20;x<s.width;x+=24){for(double y=20;y<s.height;y+=24){c.drawCircle(Offset(x,y),0.9,dot);}}
  final edge=Paint()..color=const Color(0xff8290aa)..strokeWidth=2..style=PaintingStyle.stroke;
  for(final e in edges){final a=node(e['a']),b=node(e['b']);if(a==null||b==null)continue;final x=(a['x'] as num).toDouble()+75,y=(a['y'] as num).toDouble()+29,xx=(b['x'] as num).toDouble()+75,yy=(b['y'] as num).toDouble()+29;final path=Path()..moveTo(x,y)..cubicTo((x+xx)/2,y,(x+xx)/2,yy,xx,yy);c.drawPath(path,edge);}
  for(final st in strokes){final pts=st['points'] as List;if(pts.isEmpty)continue;final pen=Paint()..color=Color(st['color'] as int)..strokeWidth=(st['width'] as num).toDouble()..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;final path=Path();for(var i=0;i<pts.length;i++){final p=pts[i] as List;final x=(p[0] as num).toDouble(),y=(p[1] as num).toDouble();if(i==0){path.moveTo(x,y);}else{path.lineTo(x,y);}}c.drawPath(path,pen);}
 }
 @override bool shouldRepaint(covariant BoardPainter oldDelegate)=>true;
}
