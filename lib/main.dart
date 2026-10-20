import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

void main()=>runApp(const EquityBasketApp());
const navy=Color(0xFF071B49), blue=Color(0xFF0878FF), green=Color(0xFF08B86A), red=Color(0xFFE34D59);
final money=NumberFormat.currency(locale:'en_IN',symbol:'₹',decimalDigits:2);
final dates=DateFormat('dd MMM yyyy');

class Basket { String id,name; Basket(this.id,this.name); Map<String,dynamic> toJson()=>{'id':id,'name':name}; factory Basket.fromJson(Map<String,dynamic> j)=>Basket(j['id'],j['name']); }
class Trade {
 String id,basketId,symbol,side; double qty,price,charges; DateTime date;
 Trade(this.id,this.basketId,this.symbol,this.side,this.qty,this.price,this.charges,this.date);
 Map<String,dynamic> toJson()=>{'id':id,'basketId':basketId,'symbol':symbol,'side':side,'qty':qty,'price':price,'charges':charges,'date':date.toIso8601String()};
 factory Trade.fromJson(Map<String,dynamic> j)=>Trade(j['id'],j['basketId'],j['symbol'],j['side'],(j['qty'] as num).toDouble(),(j['price'] as num).toDouble(),(j['charges'] as num).toDouble(),DateTime.tryParse(j['date']??'')??DateTime.now());
}
class Holding { String symbol; double qty=0,cost=0,price=0; Holding(this.symbol); double get value=>qty*price; double get pnl=>value-cost; }
class EquityBasketApp extends StatelessWidget { const EquityBasketApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(title:'EquityBasket',debugShowCheckedModeBanner:false,theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:blue),scaffoldBackgroundColor:const Color(0xFFF3F7FC),appBarTheme:const AppBarTheme(backgroundColor:navy,foregroundColor:Colors.white),inputDecorationTheme:InputDecorationTheme(border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))),home:const Home()); }

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home> {
 int tab=0; bool ready=false; List<Basket> baskets=[]; List<Trade> trades=[]; Map<String,double> prices={}; double stcgRate=20.0,ltcgRate=12.5,ltcgExemption=125000.0,cessRate=4.0;
 @override void initState(){super.initState();load();}
 Future<void> load()async{final p=await SharedPreferences.getInstance();try{baskets=(jsonDecode(p.getString('baskets')??'[]') as List).map((e)=>Basket.fromJson(Map<String,dynamic>.from(e))).toList();trades=(jsonDecode(p.getString('trades')??'[]') as List).map((e)=>Trade.fromJson(Map<String,dynamic>.from(e))).toList();prices=Map<String,double>.from((jsonDecode(p.getString('prices')??'{}') as Map).map((k,v)=>MapEntry(k,(v as num).toDouble())));stcgRate=p.getDouble('stcgRate')??20.0;ltcgRate=p.getDouble('ltcgRate')??12.5;ltcgExemption=p.getDouble('ltcgExemption')??125000.0;cessRate=p.getDouble('cessRate')??4.0;}catch(_){baskets=[];trades=[];prices={};}if(baskets.isEmpty)baskets=[Basket('core','Core Portfolio')];if(mounted)setState(()=>ready=true);save();}
 Future<void> save()async{final p=await SharedPreferences.getInstance();await p.setString('baskets',jsonEncode(baskets.map((e)=>e.toJson()).toList()));await p.setString('trades',jsonEncode(trades.map((e)=>e.toJson()).toList()));await p.setString('prices',jsonEncode(prices));await p.setDouble('stcgRate',stcgRate);await p.setDouble('ltcgRate',ltcgRate);await p.setDouble('ltcgExemption',ltcgExemption);await p.setDouble('cessRate',cessRate);}
 List<Trade> byBasket(String id)=>trades.where((t)=>t.basketId==id).toList()..sort((a,b)=>a.date.compareTo(b.date));
 Map<String,Holding> holdings(String id){final m=<String,Holding>{};for(final t in byBasket(id)){final s=t.symbol.toUpperCase();final h=m.putIfAbsent(s,()=>Holding(s));if(t.side=='BUY'){h.qty+=t.qty;h.cost+=t.qty*t.price+t.charges;}else{final q=t.qty.clamp(0.0,h.qty);final avg=h.qty==0?0:h.cost/h.qty;h.qty-=q;h.cost-=avg*q;}}m.removeWhere((k,h)=>h.qty<=0.0000001);for(final h in m.values){h.price=prices[h.symbol]??(h.qty==0?0:h.cost/h.qty);}return m;}
 Map<String,Holding> all(){final m=<String,Holding>{};for(final b in baskets){for(final e in holdings(b.id).entries){final h=m.putIfAbsent(e.key,()=>Holding(e.key));h.qty+=e.value.qty;h.cost+=e.value.cost;h.price=prices[e.key]??e.value.price;}}return m;}
 double get invested=>all().values.fold(0,(s,h)=>s+h.cost); double get value=>all().values.fold(0,(s,h)=>s+h.value); double get pnl=>value-invested;
 void toast(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
 Future<void> addBasket()async{final c=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:const Text('New basket'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(labelText:'Basket name')),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,c.text.trim().isNotEmpty),child:const Text('Create'))]));if(ok==true){baskets.add(Basket(DateTime.now().microsecondsSinceEpoch.toString(),c.text.trim()));setState((){});save();}}
 Future<void> addTrade({Trade? old})async{
 final sym=TextEditingController(text:old?.symbol??''),qty=TextEditingController(text:old?.qty.toString()??''),price=TextEditingController(text:old?.price.toString()??''),fee=TextEditingController(text:old?.charges.toString()??'0');String bid=old?.basketId??baskets.first.id,side=old?.side??'BUY';DateTime date=old?.date??DateTime.now();final key=GlobalKey<FormState>();
 final ok=await showDialog<bool>(context:context,builder:(x)=>StatefulBuilder(builder:(x,ss)=>AlertDialog(title:Text(old==null?'Record transaction':'Edit transaction'),content:SingleChildScrollView(child:Form(key:key,child:Column(mainAxisSize:MainAxisSize.min,children:[
 DropdownButtonFormField<String>(value:bid,decoration:const InputDecoration(labelText:'Basket'),items:baskets.map((b)=>DropdownMenuItem(value:b.id,child:Text(b.name))).toList(),onChanged:(v)=>ss(()=>bid=v??bid)),
 const SizedBox(height:8),DropdownButtonFormField<String>(value:side,decoration:const InputDecoration(labelText:'Type'),items:const [DropdownMenuItem(value:'BUY',child:Text('Buy')),DropdownMenuItem(value:'SELL',child:Text('Sell'))],onChanged:(v)=>ss(()=>side=v??side)),
 const SizedBox(height:8),TextFormField(controller:sym,decoration:const InputDecoration(labelText:'Stock symbol'),validator:(v)=>v==null||v.trim().isEmpty?'Required':null),
 const SizedBox(height:8),TextFormField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantity'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<=0?'Enter quantity above zero':null),
 const SizedBox(height:8),TextFormField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Price per share (₹)'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<=0?'Enter price above zero':null),
 const SizedBox(height:8),TextFormField(controller:fee,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Charges (₹)'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<0?'Enter valid charges':null),
 Row(children:[const Text('Trade date'),const Spacer(),TextButton(onPressed:()async{final d=await showDatePicker(context:x,initialDate:date,firstDate:DateTime(1990),lastDate:DateTime(2100));if(d!=null)ss(()=>date=d);},child:Text(dates.format(date)))])
]))),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>key.currentState!.validate()?Navigator.pop(x,true):null,child:const Text('Save'))])));
 if(ok!=true)return;final symbol=sym.text.trim().toUpperCase(),q=double.parse(qty.text),p=double.parse(price.text),f=double.parse(fee.text);
 if(old!=null)trades.removeWhere((t)=>t.id==old.id);
 if(side=='SELL'&&q>(holdings(bid)[symbol]?.qty??0)){toast('Sale exceeds the available quantity in this basket.');if(old!=null)trades.add(old);return;}
 trades.add(Trade(old?.id??DateTime.now().microsecondsSinceEpoch.toString(),bid,symbol,side,q,p,f,date));prices.putIfAbsent(symbol,()=>p);setState((){});save();
 }
 Future<void> setPrice(String s)async{final c=TextEditingController(text:(prices[s]??0).toString());final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:Text('Current price: '+s),content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Market price (₹)')),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,double.tryParse(c.text)!=null&&double.parse(c.text)>=0),child:const Text('Save'))]));if(ok==true){prices[s]=double.parse(c.text);setState((){});save();}}
 Future<void> exportCsv()async{final rows=<List<dynamic>>[['Date','Basket','Type','Symbol','Quantity','Price','Charges','Transaction ID']];for(final t in trades){final b=baskets.where((b)=>b.id==t.basketId).firstOrNull;rows.add([t.date.toIso8601String(),b?.name??t.basketId,t.side,t.symbol,t.qty,t.price,t.charges,t.id]);}final text=const ListToCsvConverter().convert(rows);final path=await FilePicker.platform.saveFile(fileName:'equitybasket-ledger.csv',type:FileType.custom,allowedExtensions:['csv'],bytes:utf8.encode(text));if(mounted)toast(path==null?'Export cancelled':'CSV saved');}
 Future<void> importCsv()async{final f=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['csv'],withData:true);if(f==null||f.files.single.bytes==null)return;try{final rows=const CsvToListConverter().convert(utf8.decode(f.files.single.bytes!));final head=rows.first.map((e)=>e.toString().trim().toLowerCase()).toList();int ix(String s)=>head.indexOf(s);String val(List r,String s)=>ix(s)>=0&&ix(s)<r.length?r[ix(s)].toString().trim():'';int added=0;for(final r in rows.skip(1)){final s=val(r,'symbol').toUpperCase(),side=val(r,'type').toUpperCase(),q=double.tryParse(val(r,'quantity')),p=double.tryParse(val(r,'price'));if(s.isEmpty||!['BUY','SELL'].contains(side)||q==null||p==null||q<=0||p<=0)continue;final id=val(r,'transaction id');if(id.isNotEmpty&&trades.any((t)=>t.id==id))continue;final name=val(r,'basket');var b=baskets.where((b)=>b.name.toLowerCase()==name.toLowerCase()).firstOrNull;if(b==null){b=Basket(DateTime.now().microsecondsSinceEpoch.toString(),name.isEmpty?'Imported':name);baskets.add(b);}trades.add(Trade(id.isEmpty?DateTime.now().microsecondsSinceEpoch.toString():id,b.id,s,side,q,p,double.tryParse(val(r,'charges'))??0,DateTime.tryParse(val(r,'date'))??DateTime.now()));prices.putIfAbsent(s,()=>p);added++;}setState((){});await save();toast('Imported '+added.toString()+' transactions. Review ledger.');}catch(e){toast('CSV import failed: '+e.toString());}}
 @override Widget build(BuildContext c){if(!ready)return const Scaffold(body:Center(child:CircularProgressIndicator()));final pages=[dashboard(),basketPage(),ledgerPage(),reportsPage(),settingsPage()];return Scaffold(appBar:AppBar(title:const Text('EquityBasket',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(onPressed:()=>addTrade(),icon:const Icon(Icons.add_chart),tooltip:'Add transaction')]),body:pages[tab],floatingActionButton:tab==1?FloatingActionButton.extended(onPressed:addBasket,icon:const Icon(Icons.add),label:const Text('New basket')):tab==2?FloatingActionButton.extended(onPressed:()=>addTrade(),icon:const Icon(Icons.add),label:const Text('Transaction')):null,bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),label:'Home'),NavigationDestination(icon:Icon(Icons.grid_view),label:'Baskets'),NavigationDestination(icon:Icon(Icons.receipt_long),label:'Ledger'),NavigationDestination(icon:Icon(Icons.query_stats),label:'Reports'),NavigationDestination(icon:Icon(Icons.tune),label:'Settings')]));}
 Widget title(String s,{VoidCallback? onTap})=>Row(children:[Expanded(child:Text(s,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:navy))),if(onTap!=null)TextButton(onPressed:onTap,child:const Text('View all'))]);
 Widget metric(String s,String v)=>Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s,style:const TextStyle(color:Colors.white70,fontSize:12)),const SizedBox(height:5),Text(v,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600))]));
 Widget dashboard()=>ListView(padding:const EdgeInsets.all(16),children:[
   Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[navy,Color(0xFF0678B8)]),borderRadius:BorderRadius.circular(24)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('TOTAL PORTFOLIO VALUE',style:TextStyle(color:Colors.white70,letterSpacing:1)),const SizedBox(height:10),
    Text(money.format(value),style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.bold)),const SizedBox(height:8),
    Text((pnl>=0?'▲ +':'▼ ')+money.format(pnl)+' • '+(invested>0?(pnl/invested*100).toStringAsFixed(2)+'%':'—'),style:TextStyle(color:pnl>=0?const Color(0xFF48F6A8):const Color(0xFFFFAAAA))),const SizedBox(height:20),
    Row(children:[metric('Invested',money.format(invested)),metric('Unrealised P/L',money.format(pnl))]),
   ])),
   const SizedBox(height:22),title('Your baskets',onTap:()=>setState(()=>tab=1)),const SizedBox(height:8),
   ...baskets.take(5).map((b){
    final h=holdings(b.id); final v=h.values.fold(0.0,(s,x)=>s+x.value); final i=h.values.fold(0.0,(s,x)=>s+x.cost);
    return Card(child:ListTile(onTap:()=>setState(()=>tab=1),leading:CircleAvatar(backgroundColor:green.withOpacity(.12),child:const Icon(Icons.stacked_line_chart,color:green)),title:Text(b.name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${h.length} holdings • ${byBasket(b.id).length} trades'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text(money.format(v),style:const TextStyle(fontWeight:FontWeight.bold)),Text(money.format(v-i),style:TextStyle(color:v>=i?green:red,fontSize:12))])));
   }),
   const SizedBox(height:12),title('Quick actions'),
   Row(children:[Expanded(child:action(Icons.add_circle_outline,'Buy / Sell',()=>addTrade())),Expanded(child:action(Icons.upload_file,'Import CSV',importCsv)),Expanded(child:action(Icons.download,'Export CSV',exportCsv))]),
   const SizedBox(height:14),const Text('Prices are manual. Live market quotes are not connected yet.',style:TextStyle(color:Colors.blueGrey,fontSize:12)),
 ]);
 Widget action(IconData i,String s,VoidCallback f)=>Card(child:InkWell(onTap:f,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Icon(i,color:blue),const SizedBox(height:6),Text(s,style:const TextStyle(fontSize:12))]))));
 Widget basketPage()=>ListView(padding:const EdgeInsets.all(16),children:[title('All baskets'),...baskets.map((b){
  final h=holdings(b.id);final i=h.values.fold(0.0,(s,x)=>s+x.cost),v=h.values.fold(0.0,(s,x)=>s+x.value);
  return Card(child:ExpansionTile(title:Text(b.name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${h.length} active holdings • ${byBasket(b.id).length} trades'),leading:const Icon(Icons.account_balance_wallet,color:blue),children:[
    Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Text('Value ${money.format(v)}   P/L ${money.format(v-i)}'),
      if(h.isEmpty) const ListTile(title:Text('No active holdings yet')),
      ...h.values.map((x)=>ListTile(dense:true,title:Text(x.symbol),subtitle:Text('${x.qty.toStringAsFixed(4)} shares • avg cost ${money.format(x.qty>0?x.cost/x.qty:0)}'),trailing:Text(money.format(x.value)))),
      Wrap(spacing:8,children:[
        FilledButton.tonal(onPressed:()=>addTrade(),child:const Text('Add trade')),
        TextButton(onPressed:()=>renameBasket(b),child:const Text('Rename')),
        if(baskets.length>1) TextButton(onPressed:()=>deleteBasket(b),child:const Text('Delete')),
      ]),
    ]))
   ]));
 }),]);
 Widget ledgerPage(){final list=trades.toList()..sort((a,b)=>b.date.compareTo(a.date));return ListView(padding:const EdgeInsets.all(16),children:[
  Row(children:[Expanded(child:title('Transaction ledger')),IconButton(onPressed:importCsv,icon:const Icon(Icons.upload_file)),IconButton(onPressed:exportCsv,icon:const Icon(Icons.download))]),
  if(list.isEmpty)const Padding(padding:EdgeInsets.all(28),child:Text('No transactions yet. Add your first buy or sell.')),
   ...list.map((t)=>Card(child:ListTile(
     leading:CircleAvatar(backgroundColor:(t.side=='BUY'?blue:red).withOpacity(.12),child:Icon(t.side=='BUY'?Icons.south_west:Icons.north_east,color:t.side=='BUY'?blue:red)),
     title:Text('${t.side} • ${t.symbol}',style:const TextStyle(fontWeight:FontWeight.bold)),
     subtitle:Text('${dates.format(t.date)} • ${t.qty} × ${money.format(t.price)}\\nCharges ${money.format(t.charges)}'),
     isThreeLine:true,
     trailing:PopupMenuButton<String>(
       onSelected:(v){if(v=='edit')addTrade(old:t);if(v=='delete')deleteTrade(t);},
       itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'delete',child:Text('Delete'))],
     ),
   ))),
 ]);}
  Future<void> renameBasket(Basket b) async {
    final controller = TextEditingController(text: b.name);
    final ok = await showDialog<bool>(context: context, builder: (x) => AlertDialog(title: const Text('Rename basket'), content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Basket name')), actions: [TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(x, controller.text.trim().isNotEmpty), child: const Text('Save'))]));
    if (ok == true) { b.name = controller.text.trim(); setState(() {}); await save(); }
  }
  Future<void> deleteBasket(Basket b) async {
    final ok = await showDialog<bool>(context: context, builder: (x) => AlertDialog(title: const Text('Delete basket?'), content: Text('This removes ${trades.where((t) => t.basketId == b.id).length} transactions too.'), actions: [TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(x, true), child: const Text('Delete'))]));
    if (ok == true) { trades.removeWhere((t) => t.basketId == b.id); baskets.remove(b); setState(() {}); await save(); }
  }
  Future<void> deleteTrade(Trade t) async {
    final ok = await showDialog<bool>(context: context, builder: (x) => AlertDialog(title: const Text('Delete transaction?'), content: Text('${t.side} ${t.qty} ${t.symbol} will be removed.'), actions: [TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(x, true), child: const Text('Delete'))]));
    if (ok == true) { trades.removeWhere((e) => e.id == t.id); setState(() {}); await save(); }
  }
  Map<String, double> _realisedByYear() {
    final grouped = <String, List<Trade>>{};
    for (final trade in trades) {
      grouped.putIfAbsent('${trade.basketId}|${trade.symbol.toUpperCase()}', () => <Trade>[]).add(trade);
    }
    final result = <String, double>{};
    for (final items in grouped.values) {
      items.sort((a, b) => a.date.compareTo(b.date));
      double quantity = 0, cost = 0;
      for (final trade in items) {
        if (trade.side == 'BUY') { quantity += trade.qty; cost += trade.qty * trade.price + trade.charges; }
        else if (quantity > 0) {
          final sold = trade.qty.clamp(0.0, quantity);
          final average = cost / quantity;
          final proceeds = sold * trade.price - trade.charges * (sold / trade.qty);
          final year = trade.date.year.toString();
          result[year] = (result[year] ?? 0) + proceeds - average * sold;
          quantity -= sold; cost -= average * sold;
        }
      }
    }
    return result;
  }
  double? _xirr() {
    final flows = <MapEntry<DateTime, double>>[];
    for (final trade in trades) {
      final amount = trade.qty * trade.price;
      flows.add(MapEntry(trade.date, trade.side == 'BUY' ? -amount - trade.charges : amount - trade.charges));
    }
    if (value > 0) flows.add(MapEntry(DateTime.now(), value));
    if (flows.length < 2 || !flows.any((f) => f.value < 0) || !flows.any((f) => f.value > 0)) return null;
    flows.sort((a, b) => a.key.compareTo(b.key));
    final start = flows.first.key;
    double npv(double rate) {
      var total = 0.0;
      for (final f in flows) {
        final years = f.key.difference(start).inSeconds / (365.25 * 86400);
        total += f.value / math.pow(1 + rate, years);
      }
      return total;
    }
    var low = -0.9999, high = 100.0;
    var fl = npv(low), fh = npv(high);
    if (!fl.isFinite || !fh.isFinite || fl.sign == fh.sign) return null;
    for (var i = 0; i < 180; i++) {
      final mid = (low + high) / 2, fm = npv(mid);
      if (fm.abs() < 0.000001) return mid;
      if (fm.sign == fl.sign) { low = mid; fl = fm; } else { high = mid; fh = fm; }
    }
    return (low + high) / 2;
  }
 Map<String,double> _taxEstimate() {
   final grouped=<String,List<Trade>>{};
   for(final t in trades){grouped.putIfAbsent('${t.basketId}|${t.symbol.toUpperCase()}',()=>[]).add(t);}
   var stcg=0.0,ltcg=0.0;
   for(final entries in grouped.values){
     entries.sort((a,b)=>a.date.compareTo(b.date));
     final lots=<Map<String,dynamic>>[];
     for(final t in entries){
       if(t.side=='BUY'){lots.add({'qty':t.qty,'unitCost':t.price+(t.qty>0?t.charges/t.qty:0),'date':t.date});continue;}
       var toSell=t.qty;
       for(final lot in lots){
         if(toSell<=0)break;
         final remaining=(lot['qty'] as double);if(remaining<=0)continue;
         final match=toSell<remaining?toSell:remaining;
         final unitCost=lot['unitCost'] as double;
         final holdingDays=t.date.difference(lot['date'] as DateTime).inDays;
         final proceeds=match*t.price-(t.qty>0?t.charges*match/t.qty:0);
         final gain=proceeds-match*unitCost;
         if(holdingDays>365)ltcg+=gain;else stcg+=gain;
         lot['qty']=remaining-match;toSell-=match;
       }
     }
   }
   final ltcgTaxable=(ltcg-ltcgExemption).clamp(0.0,double.infinity);
   final beforeCess=(stcg*(stcgRate/100))+(ltcgTaxable*(ltcgRate/100));
   final cess=beforeCess*(cessRate/100);
   return {'stcgGain':stcg,'ltcgGain':ltcg,'taxableLtcg':ltcgTaxable,'baseTax':beforeCess,'cess':cess,'estimatedTax':beforeCess+cess};
 }
 Future<void> _editTaxSettings() async {
   final s=TextEditingController(text:stcgRate.toStringAsFixed(2));final l=TextEditingController(text:ltcgRate.toStringAsFixed(2));final e=TextEditingController(text:ltcgExemption.toStringAsFixed(0));final c=TextEditingController(text:cessRate.toStringAsFixed(2));
   final form=GlobalKey<FormState>();
   final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:const Text('Tax estimate assumptions'),content:Form(key:form,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     TextFormField(controller:s,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Short-term rate (%)'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<0?'Enter a valid rate':null),
     TextFormField(controller:l,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Long-term rate (%)'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<0?'Enter a valid rate':null),
     TextFormField(controller:e,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'LTCG exemption assumption (₹)'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<0?'Enter a valid amount':null),
     TextFormField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Cess rate (%)'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<0?'Enter a valid rate':null),
   ]))),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,form.currentState!.validate()),child:const Text('Save'))]));
   if(ok==true){stcgRate=double.parse(s.text);ltcgRate=double.parse(l.text);ltcgExemption=double.parse(e.text);cessRate=double.parse(c.text);setState((){});await save();}
 }
 Widget reportsPage(){
   final holdings=all(); final years=_realisedByYear(); final irr=_xirr(); final tax=_taxEstimate();
   final buys=trades.where((t)=>t.side=='BUY').fold(0.0,(s,t)=>s+t.qty*t.price+t.charges);
   final sells=trades.where((t)=>t.side=='SELL').fold(0.0,(s,t)=>s+t.qty*t.price-t.charges);
   final sortedYears=years.keys.toList()..sort((a,b)=>b.compareTo(a));
   return ListView(padding:const EdgeInsets.all(16),children:[
     title('Performance report'),
     reportCard('Portfolio cost basis',money.format(invested),Icons.account_balance_wallet),
     reportCard('Market value',money.format(value),Icons.show_chart),
     reportCard('Unrealised profit / loss',money.format(pnl),Icons.trending_up,pnl>=0?green:red),
     reportCard('Realised P/L (average cost)',money.format(years.values.fold(0.0,(s,v)=>s+v)),Icons.check_circle,years.values.fold(0.0,(s,v)=>s+v)>=0?green:red),
     reportCard('Money-weighted return (XIRR)',irr==null?'—':(irr*100).toStringAsFixed(2)+'%',Icons.query_stats,irr==null?blue:irr>=0?green:red),
     reportCard('Buy transaction total',money.format(buys),Icons.south_west),
     reportCard('Sell proceeds',money.format(sells),Icons.north_east),
     const SizedBox(height:12),title('Estimated tax view'),
     reportCard('Short-term realised gain',money.format(tax['stcgGain']!),Icons.schedule),
     reportCard('Long-term realised gain',money.format(tax['ltcgGain']!),Icons.event_available),
     reportCard('Assumed LTCG exemption',money.format(ltcgExemption),Icons.shield_outlined),
     reportCard('Estimated tax incl. cess',money.format(tax['estimatedTax']!),Icons.receipt_long,red),
     ListTile(leading:const Icon(Icons.tune,color:blue),title:const Text('Edit tax assumptions'),subtitle:Text('STCG ${stcgRate.toStringAsFixed(2)}% • LTCG ${ltcgRate.toStringAsFixed(2)}% • cess ${cessRate.toStringAsFixed(2)}%'),trailing:const Icon(Icons.chevron_right),onTap:_editTaxSettings),
     const SizedBox(height:12),title('Yearly realised P/L'),
     if(sortedYears.isEmpty) const Padding(padding:EdgeInsets.all(16),child:Text('Realised profit/loss appears after a sell transaction.')),
     ...sortedYears.map((year)=>Card(child:ListTile(title:Text(year),subtitle:const Text('Average-cost estimate'),trailing:Text(money.format(years[year]!),style:TextStyle(fontWeight:FontWeight.bold,color:years[year]!>=0?green:red))))),
     const SizedBox(height:12),title('Holdings'),
     ...holdings.values.map((h)=>Card(child:ListTile(title:Text(h.symbol),subtitle:Text('${h.qty.toStringAsFixed(4)} shares • cost ${money.format(h.cost)}'),trailing:Text(money.format(h.pnl),style:TextStyle(color:h.pnl>=0?green:red,fontWeight:FontWeight.bold))))),
     const Text('Tax estimate is an educational approximation using FIFO and user-configured rates, with a simple 365-day holding-period split and one assumed LTCG exemption applied to aggregate gains. It does not model all statutory conditions, set-offs, surcharges, corporate actions or tax-lot rules. Verify with a tax professional.',style:TextStyle(color:Colors.blueGrey,fontSize:12)),
     const Text('XIRR uses dated buys/sells and the current manually entered holding value. Live prices and broker data are not connected.',style:TextStyle(color:Colors.blueGrey,fontSize:12)),
   ]);
 }
 Widget reportCard(String s,String v,IconData i,[Color c=blue])=>Card(child:ListTile(leading:Icon(i,color:c),title:Text(s),trailing:Text(v,style:TextStyle(color:c,fontWeight:FontWeight.bold))));
 Widget settingsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
   title('Settings'),
   Card(child:ListTile(leading:const Icon(Icons.price_change,color:blue),title:const Text('Update current prices'),subtitle:const Text('Manually update prices for any active holding'),onTap:pricePicker)),
   Card(child:ListTile(leading:const Icon(Icons.tune,color:blue),title:const Text('Tax estimate assumptions'),subtitle:Text('STCG ${stcgRate.toStringAsFixed(2)}% • LTCG ${ltcgRate.toStringAsFixed(2)}%'),onTap:_editTaxSettings)),
   Card(child:ListTile(leading:const Icon(Icons.upload_file,color:blue),title:const Text('Import CSV'),subtitle:const Text('Rows with duplicate transaction IDs are skipped'),onTap:importCsv)),
   Card(child:ListTile(leading:const Icon(Icons.download,color:blue),title:const Text('Export CSV backup'),onTap:exportCsv)),
   const Card(child:ListTile(leading:Icon(Icons.storage,color:blue),title:Text('Local storage'),subtitle:Text('Baskets, prices and trades are stored on this device. Export a backup before uninstalling.'))),
   const Padding(padding:EdgeInsets.all(12),child:Text('Tax outcomes depend on current law and personal circumstances. These inputs drive a rough estimate only. No broker connection or live market prices.',style:TextStyle(color:Colors.blueGrey,fontSize:12))),
 ]);
 Future<void> pricePicker()async{final symbols=all().keys.toList()..sort();if(symbols.isEmpty){toast('Add a buy transaction first.');return;}showModalBottomSheet(context:context,builder:(x)=>SafeArea(child:ListView(shrinkWrap:true,children:[const ListTile(title:Text('Select a holding to update price')),...symbols.map((s)=>ListTile(title:Text(s),subtitle:Text(money.format(prices[s]??0)),trailing:const Icon(Icons.edit),onTap:(){Navigator.pop(x);setPrice(s);} ))])));}
}
