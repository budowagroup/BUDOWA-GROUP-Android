import 'dart:math';
import 'package:flutter/material.dart';

class TestField {
  final int column;
  final String name;
  final String kind;
  final bool required;
  const TestField(this.column, this.name, {this.kind='text', this.required=false});
}

List<TestField> testFields(String book, String tab) {
  if (book == 'hours') {
    switch (tab) {
      case 'Робочі години': return const [
        TestField(0,'Дата',kind:'date',required:true),
        TestField(1,'Працівник',required:true),
        TestField(2,'Об’єкт',required:true),
        TestField(3,'Початок',kind:'time',required:true),
        TestField(4,'Кінець',kind:'time',required:true),
        TestField(5,'Перерва (год)',kind:'number'),
        TestField(9,'Аванс (zł)',kind:'number'),
        TestField(10,'Місяць роботи'),
        TestField(11,'Оплата (zł)',kind:'number'),
        TestField(12,'Місяць оплати'),
        TestField(14,'Примітка')];
      case 'Працівники': return const [
        TestField(0,'Працівник',required:true),
        TestField(1,'Посада'),
        TestField(3,'Активний',kind:'active',required:true),
        TestField(4,'Примітка')];
      case 'Обʼєкти': return const [
        TestField(0,'Об’єкт',required:true),
        TestField(1,'Адреса'),
        TestField(2,'Активний',kind:'active',required:true),
        TestField(3,'Примітка')];
      case 'Історія ставок': return const [
        TestField(0,'Працівник',required:true),
        TestField(1,'Діє від',kind:'date',required:true),
        TestField(2,'Ставка netto/год',kind:'positive',required:true),
        TestField(3,'Примітка')];
    }
  }
  if (book == 'finance') {
    switch (tab) {
      case 'Операції': return const [
        TestField(1,'Дата',kind:'date',required:true),
        TestField(2,'Хто',required:true),
        TestField(3,'Сума (zł)',kind:'positive',required:true),
        TestField(4,'Тип операції',kind:'operation',required:true),
        TestField(5,'Опис'),
        TestField(6,'Категорія'),
        TestField(7,'Об’єкт'),
        TestField(8,'Документ №')];
      case 'Закупівельники': return const [TestField(0,'Ім’я',required:true)];
      case 'Довідники': return const [TestField(0,'Категорія',required:true)];
    }
  }
  return const [];
}

String testNumber(String source) {
  var s=source.replaceAll(RegExp(r'[^0-9,.\-]'),'');
  if (s.contains('.') && s.contains(',')) {
    s=s.lastIndexOf('.')>s.lastIndexOf(',')
      ? s.replaceAll(',','')
      : s.replaceAll('.','').replaceAll(',','.');
  } else if (s.contains(',')) {
    s=s.replaceAll(',','.');
  }
  return s;
}
String testInitial(TestField field,String raw) {
  final v=raw.trim();
  if (field.kind=='number'||field.kind=='positive') return testNumber(v);
  if (field.kind=='date') {
    final m=RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(v);
    if(m!=null) return '${m[3]}-${m[2]!.padLeft(2,'0')}-${m[1]!.padLeft(2,'0')}';
  }
  return v;
}

class SheetRecordEditor extends StatefulWidget {
  final String book,tab;
  final int? sheetRow;
  final List<String>? original;
  final Future<void> Function(Map<String,String> values,String requestId) onSave;
  const SheetRecordEditor({super.key,required this.book,required this.tab,
    required this.onSave,this.sheetRow,this.original});
  @override
  State<SheetRecordEditor> createState()=>_SheetRecordEditorState();
}
class _SheetRecordEditorState extends State<SheetRecordEditor> {
  final formKey=GlobalKey<FormState>();
  final controllers=<int,TextEditingController>{};
  late final String requestId;
  bool saving=false;
  String? error;
  List<TestField> get fields=>testFields(widget.book,widget.tab);

  @override
  void initState(){
    super.initState();
    requestId='${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1<<32).toRadixString(16)}';
    for (final f in fields) {
      final r=widget.original;
      final current=r!=null && f.column<r.length ? r[f.column]:'';
      controllers[f.column]=TextEditingController(text:testInitial(f,
        f.kind=='active' && current.isEmpty ? 'Так':current));
    }
  }
  @override
  void dispose(){
    for(final c in controllers.values){c.dispose();}
    super.dispose();
  }

  String? check(TestField f,String? raw){
    final s=(raw??'').trim();
    if(f.required && s.isEmpty)return 'Обов’язкове поле';
    if(s.isEmpty)return null;
    if(f.kind=='number'||f.kind=='positive'){
      final n=double.tryParse(testNumber(s));
      if(n==null||!n.isFinite||n<0||(f.kind=='positive'&&n==0))return 'Некоректна сума';
    }
    if(f.kind=='date'){
      final match=RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);
      final d=DateTime.tryParse(s);
      if(!match||d==null||d.year<2020||d.year>2100||
        '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}'!=s)
        return 'Дата РРРР-ММ-ДД';
    }
    if(f.kind=='time'&&!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s))
      return 'Час ГГ:ХХ';
    if(f.kind=='active'&&s!='Так'&&s!='Ні')return 'Так або Ні';
    if(f.kind=='operation'&&s!='Надходження'&&s!='Витрати')
      return 'Надходження або Витрати';
    if(s.startsWith('=')||s.startsWith('+')||s.startsWith('@'))
      return 'Формули заборонені';
    return null;
  }

  Future<void> pick(TestField f)async{
    if(f.kind=='date'){
      final chosen=await showDatePicker(context:context,
        initialDate:DateTime.tryParse(controllers[f.column]!.text)??DateTime.now(),
        firstDate:DateTime(2020),lastDate:DateTime(2100));
      if(chosen!=null)controllers[f.column]!.text=
        '${chosen.year}-${chosen.month.toString().padLeft(2,'0')}-${chosen.day.toString().padLeft(2,'0')}';
    } else {
      final p=controllers[f.column]!.text.split(':');
      final h=int.tryParse(p.first);
      final m=p.length>1?int.tryParse(p[1]):null;
      final result=await showTimePicker(context:context,
        initialTime:TimeOfDay(hour:h!=null&&h>=0&&h<24?h:8,
          minute:m!=null&&m>=0&&m<60?m:0));
      if(result!=null)controllers[f.column]!.text=
        '${result.hour.toString().padLeft(2,'0')}:${result.minute.toString().padLeft(2,'0')}';
    }
  }

  Future<void> save()async{
    if(saving||!formKey.currentState!.validate())return;
    if(widget.tab=='Робочі години' &&
      controllers[3]!.text==controllers[4]!.text){
      setState(()=>error='Початок і кінець роботи мають відрізнятися');
      return;
    }
    final values=<String,String>{
      for(final f in fields) '${f.column}':
        f.kind=='number'||f.kind=='positive'
          ? testNumber(controllers[f.column]!.text.trim())
          : controllers[f.column]!.text.trim()
    };
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(widget.sheetRow==null?'Додати запис до TEST?':'Редагувати запис у TEST?'),
      content:Text('Вкладка: ${widget.tab}\n'
        '${widget.sheetRow==null?'Новий запис':'Рядок ${widget.sheetRow}'}\n'
        'Збереження може змінити TEST-розрахунки. Оригінали не використовуються.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Скасувати')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Підтвердити')),
      ]));
    if(ok!=true||!mounted)return;
    setState((){saving=true;error=null;});
    try{
      await widget.onSave(values,requestId);
      if(mounted)Navigator.pop(context,true);
    }catch(e){
      if(mounted)setState(()=>error='$e');
    }finally{
      if(mounted)setState(()=>saving=false);
    }
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.sheetRow==null?'Додати — TEST':'Редагувати — TEST')),
    body:Form(key:formKey,child:ListView(padding:const EdgeInsets.all(16),children:[
      Text('TEST • ${widget.tab}',style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
      if(widget.tab=='Працівники')const Padding(padding:EdgeInsets.only(top:8),
        child:Text('Ставка розраховується з «Історії ставок» і тут не редагується.')),
      if(widget.tab=='Закупівельники')const Padding(padding:EdgeInsets.only(top:8),
        child:Text('Редагується лише ім’я. Надходження, витрати та баланс — формули.')),
      if(widget.tab=='Довідники')const Padding(padding:EdgeInsets.only(top:8),
        child:Text('Об’єкти надходять із таблиці «Обʼєкти». Тут редагуються лише категорії.')),
      const SizedBox(height:14),
      ...fields.map((f)=>Padding(padding:const EdgeInsets.only(bottom:12),
        child:(f.kind=='active'||f.kind=='operation')
          ? DropdownButtonFormField<String>(
              initialValue:controllers[f.column]!.text.isEmpty
                ? null:controllers[f.column]!.text,
              isExpanded:true,
              decoration:InputDecoration(labelText:f.name,border:const OutlineInputBorder()),
              items:(f.kind=='active'?const ['Так','Ні']:const ['Надходження','Витрати'])
                .map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
              onChanged:saving?null:(v){controllers[f.column]!.text=v??'';},
              validator:(v)=>check(f,v))
          :TextFormField(
              controller:controllers[f.column],enabled:!saving,
              keyboardType:f.kind=='number'||f.kind=='positive'
                ?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,
              decoration:InputDecoration(labelText:f.name,border:const OutlineInputBorder(),
                helperText:f.column==5&&widget.tab=='Робочі години'
                  ?'Перерва в годинах (0,5 = 30 хв)':null,
                suffixIcon:f.kind=='date'||f.kind=='time'
                  ?IconButton(icon:Icon(f.kind=='date'?Icons.calendar_month:Icons.schedule),
                    onPressed:()=>pick(f)):null),
              validator:(v)=>check(f,v)))),
      if(error!=null)Padding(padding:const EdgeInsets.only(bottom:12),
        child:SelectableText(error!,style:const TextStyle(color:Colors.red))),
      FilledButton.icon(onPressed:saving?null:save,
        icon:const Icon(Icons.save_outlined),
        label:Text(saving?'Збереження…':widget.sheetRow==null
          ?'Додати у TEST-таблицю':'Зберегти зміни у TEST')),
      if(saving)const LinearProgressIndicator(),
      const SizedBox(height:12),
      const Text('Сервер перевіряє права, змінені рядки та захист формул.',
        style:TextStyle(fontSize:12,color:Color(0xFF51647A))),
    ])));
}
