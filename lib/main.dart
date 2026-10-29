import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdfrx/pdfrx.dart';

void main()=>runApp(const EquityBasketApp());
const navy=Color(0xFF071B49), blue=Color(0xFF0878FF), green=Color(0xFF08B86A), red=Color(0xFFE34D59);
final money=NumberFormat.currency(locale:'en_IN',symbol:'₹',decimalDigits:2);
final dates=DateFormat('dd MMM yyyy');

class PriceRefreshResult {
  final Map<String, double> prices;
  final int unchanged;
  final bool hasError;
  final String? errorMessage;

  const PriceRefreshResult({
    required this.prices,
    required this.unchanged,
    this.hasError = false,
    this.errorMessage,
  });

  int get updated => prices.length;
}

class Basket { String id,name; Basket(this.id,this.name); Map<String,dynamic> toJson()=>{'id':id,'name':name}; factory Basket.fromJson(Map<String,dynamic> j)=>Basket(j['id'],j['name']); }
class Trade {
 String id,basketId,symbol,side; double qty,price,charges; DateTime date;
 Trade(this.id,this.basketId,this.symbol,this.side,this.qty,this.price,this.charges,this.date);
 Map<String,dynamic> toJson()=>{'id':id,'basketId':basketId,'symbol':symbol,'side':side,'qty':qty,'price':price,'charges':charges,'date':date.toIso8601String()};
 factory Trade.fromJson(Map<String,dynamic> j)=>Trade(j['id'],j['basketId'],j['symbol'],j['side'],(j['qty'] as num).toDouble(),(j['price'] as num).toDouble(),(j['charges'] as num).toDouble(),DateTime.tryParse(j['date']??'')??DateTime.now());
}
class Holding { String symbol; double qty=0,cost=0,price=0; Holding(this.symbol); double get value=>qty*price; double get pnl=>value-cost; }

double _roundMoney(double value) => (value * 100).roundToDouble() / 100;
Map<String, double> estimateDeliveryCharges(double qty, double price, String side) {
  final turnover = math.max(0.0, qty) * math.max(0.0, price);
  final sebi = _roundMoney(turnover * 10 / 10000000);
  final exchange = _roundMoney(turnover * 0.0000307);
  final stt = _roundMoney(turnover * 0.001);
  final stamp = side == 'BUY' ? (turnover * 0.00015).roundToDouble() : 0.0;
  const brokerage = 0.0;
  final gst = _roundMoney((brokerage + exchange + sebi) * 0.18);
  final total = _roundMoney(sebi + exchange + stt + stamp + gst + brokerage);
  return {'SEBI fee':sebi,'Exchange fee':exchange,'STT':stt,'Stamp duty':stamp,'GST':gst,'Brokerage':brokerage,'Total':total};
}
List<Trade> chronologicalTrades(List<Trade> source) {
  final indexed = source.asMap().entries.toList();
  indexed.sort((a, b) {
    final byDate = a.value.date.compareTo(b.value.date);
    return byDate != 0 ? byDate : a.key.compareTo(b.key);
  });
  return indexed.map((entry) => entry.value).toList();
}

bool hasValidTransactionSequence(List<Trade> source) {
  final quantities = <String, double>{};
  for (final trade in chronologicalTrades(source)) {
    if (trade.qty <= 0 || trade.price <= 0 ||
        !['BUY', 'SELL'].contains(trade.side)) return false;
    final key = '${trade.basketId}|${trade.symbol.toUpperCase().trim()}';
    final held = quantities[key] ?? 0.0;
    if (trade.side == 'BUY') {
      quantities[key] = held + trade.qty;
    } else {
      if (trade.qty > held + 0.0000001) return false;
      quantities[key] = held - trade.qty;
    }
  }
  return true;
}
class EquityBasketApp extends StatelessWidget { const EquityBasketApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(title:'EquityBasket',debugShowCheckedModeBanner:false,theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:blue,brightness:Brightness.light),scaffoldBackgroundColor:const Color(0xFFF1F5FB),appBarTheme:const AppBarTheme(backgroundColor:navy,foregroundColor:Colors.white,elevation:0,centerTitle:false),cardTheme:CardThemeData(color:Colors.white,surfaceTintColor:Colors.white,elevation:1,margin:const EdgeInsets.symmetric(vertical:6),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))),navigationBarTheme:const NavigationBarThemeData(backgroundColor:Color(0xFFE9EDF7),indicatorColor:Color(0xFFD7E2FF),labelTextStyle:WidgetStatePropertyAll(TextStyle(fontWeight:FontWeight.w600))),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:const Color(0xFFF8FAFF),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Color(0xFFE1E7F0))),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:blue,width:1.5)))),home:const Home()); }

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home> {
 int tab=0; bool ready=false; bool refreshingPrices=false; String? pricesUpdatedAt; DateTime reportStart=DateTime(DateTime.now().year-1,DateTime.now().month,DateTime.now().day); DateTime reportEnd=DateTime.now(); String dashboardPeriod='Day'; bool periodLoading=false; Map<String,dynamic>? dashboardPeriodData; Map<String,dynamic>? reportPeriodData; String? selectedBasketId; List<Basket> baskets=[]; List<Trade> trades=[]; Map<String,double> prices={}; Map<String,String> stockDirectory={}; double stcgRate=20.0,ltcgRate=12.5,ltcgExemption=125000.0,cessRate=4.0,defaultCharges=0.0;
 @override void initState(){super.initState();load();}
 Future<void> load()async{final p=await SharedPreferences.getInstance();try{baskets=(jsonDecode(p.getString('baskets')??'[]') as List).map((e)=>Basket.fromJson(Map<String,dynamic>.from(e))).toList();trades=(jsonDecode(p.getString('trades')??'[]') as List).map((e)=>Trade.fromJson(Map<String,dynamic>.from(e))).toList();prices=Map<String,double>.from((jsonDecode(p.getString('prices')??'{}') as Map).map((k,v)=>MapEntry(k,(v as num).toDouble())));stockDirectory=Map<String,String>.from((jsonDecode(p.getString('stockDirectory')??'{}') as Map).map((k,v)=>MapEntry(k.toString(),v.toString())));stcgRate=p.getDouble('stcgRate')??20.0;ltcgRate=p.getDouble('ltcgRate')??12.5;ltcgExemption=p.getDouble('ltcgExemption')??125000.0;cessRate=p.getDouble('cessRate')??4.0;defaultCharges=p.getDouble('defaultCharges')??0.0;pricesUpdatedAt=p.getString('pricesUpdatedAt');}catch(_){baskets=[];trades=[];prices={};}if(baskets.isEmpty)baskets=[Basket('core','Core Portfolio')];if(mounted)setState(()=>ready=true);save();loadDashboardPeriod('Day');}
 Future<void> save()async{final p=await SharedPreferences.getInstance();await p.setString('baskets',jsonEncode(baskets.map((e)=>e.toJson()).toList()));await p.setString('trades',jsonEncode(trades.map((e)=>e.toJson()).toList()));await p.setString('prices',jsonEncode(prices));await p.setString('stockDirectory',jsonEncode(stockDirectory));await p.setDouble('stcgRate',stcgRate);await p.setDouble('ltcgRate',ltcgRate);await p.setDouble('ltcgExemption',ltcgExemption);await p.setDouble('cessRate',cessRate);await p.setDouble('defaultCharges',defaultCharges);if(pricesUpdatedAt!=null)await p.setString('pricesUpdatedAt',pricesUpdatedAt!);}
 List<Trade> byBasket(String id)=>chronologicalTrades(trades.where((t)=>t.basketId==id).toList());
 Map<String,Holding> holdings(String id){final m=<String,Holding>{};for(final t in byBasket(id)){final s=t.symbol.toUpperCase();final h=m.putIfAbsent(s,()=>Holding(s));if(t.side=='BUY'){h.qty+=t.qty;h.cost+=t.qty*t.price+t.charges;}else{final q=t.qty.clamp(0.0,h.qty);final avg=h.qty==0?0:h.cost/h.qty;h.qty-=q;h.cost-=avg*q;}}m.removeWhere((k,h)=>h.qty<=0.0000001);for(final h in m.values){h.price=prices[h.symbol]??(h.qty==0?0:h.cost/h.qty);}return m;}
 Map<String,Holding> all(){final m=<String,Holding>{};for(final b in baskets){for(final e in holdings(b.id).entries){final h=m.putIfAbsent(e.key,()=>Holding(e.key));h.qty+=e.value.qty;h.cost+=e.value.cost;h.price=prices[e.key]??e.value.price;}}return m;}
 double get invested=>all().values.fold(0,(s,h)=>s+h.cost); double get value=>all().values.fold(0,(s,h)=>s+h.value); double get pnl=>value-invested;
 void toast(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s))); Future<PriceRefreshResult> fetchNsePrices(Set<String> holdingSymbols) async {
   final pending = holdingSymbols.map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toSet();
   final updated = <String, double>{};
   if (pending.isEmpty) {
     return const PriceRefreshResult(prices: {}, unchanged: 0);
   }

   var validSnapshotsFound = 0;
   var currentDate = DateTime.now();
   String? errorMessage;

   while (validSnapshotsFound < 5 && pending.isNotEmpty) {
     final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);
     final uri = Uri.https('api.tejhq.dev', '/v1/snapshot/nse', {'date': dateStr});

     try {
       final response = await http.get(uri, headers: const {'Accept': 'application/json'})
           .timeout(const Duration(seconds: 12));

       if (response.statusCode == 404 || response.statusCode == 400) {
         // No snapshot for this date (often a weekend, holiday, or not-yet-published file).
       } else if (response.statusCode == 429) {
         errorMessage = 'TejHQ rate limit reached (HTTP 429).';
         break;
       } else if (response.statusCode != 200) {
         errorMessage = 'TejHQ returned HTTP ${response.statusCode}.';
         break;
       } else {
         final decoded = jsonDecode(response.body);
         if (decoded is! Map) {
           errorMessage = 'TejHQ returned an unexpected response format.';
           break;
         }
         final rows = decoded['data'];
         if (rows is! List) {
           errorMessage = 'TejHQ response did not contain a data array.';
           break;
         }

         if (rows.isNotEmpty) {
           validSnapshotsFound++;
           for (final row in rows) {
             if (row is! Map) continue;
             final rawSymbol = row['symbol'];
             final rawSeries = row['series'];
             if (rawSymbol is! String || rawSeries is! String) continue;
             final symbol = rawSymbol.trim().toUpperCase();
             if (rawSeries.trim().toUpperCase() == 'EQ') {
               final rawName = row['name'];
               stockDirectory[symbol] = rawName is String && rawName.trim().isNotEmpty ? rawName.trim() : symbol;
             }
             if (rawSeries.trim().toUpperCase() != 'EQ' || !pending.contains(symbol)) continue;

             final rawClose = row['close'];
             final close = rawClose is num ? rawClose.toDouble() : double.tryParse(rawClose?.toString() ?? '');
             if (close == null || !close.isFinite || close <= 0) continue;

             updated[symbol] = close;
             pending.remove(symbol);
           }
         }
       }
     } catch (_) {
       errorMessage = 'Network error, timeout, or invalid response while fetching NSE prices.';
       break;
     }

     currentDate = currentDate.subtract(const Duration(days: 1));
   }

   return PriceRefreshResult(
     prices: Map.unmodifiable(updated),
     unchanged: pending.length,
     hasError: errorMessage != null,
     errorMessage: errorMessage,
   );
 }

 Future<void> loadStockDirectory() async {
   if (stockDirectory.isNotEmpty) return;
   var date = DateTime.now();
   for (var attempt = 0; attempt < 10; attempt++) {
     final uri = Uri.https('api.tejhq.dev', '/v1/snapshot/nse', {'date':DateFormat('yyyy-MM-dd').format(date)});
     try {
       final response = await http.get(uri, headers: const {'Accept':'application/json'}).timeout(const Duration(seconds:12));
       if (response.statusCode == 200) {
         final decoded = jsonDecode(response.body);
         final rows = decoded is Map ? decoded['data'] : null;
         if (rows is List && rows.isNotEmpty) {
           for (final row in rows) {
             if (row is! Map || row['symbol'] is! String || row['series'] is! String) continue;
             if ((row['series'] as String).trim().toUpperCase() != 'EQ') continue;
             final symbol = (row['symbol'] as String).trim().toUpperCase();
             final rawName = row['name'];
             if (symbol.isNotEmpty) stockDirectory[symbol] = rawName is String && rawName.trim().isNotEmpty ? rawName.trim() : symbol;
           }
           if (mounted) setState(() {});
           await save();
           return;
         }
       } else if (response.statusCode != 404 && response.statusCode != 400) {
         return;
       }
     } catch (_) {
       return;
     }
     date = date.subtract(const Duration(days:1));
   }
 }
 Future<void> refreshPrices() async {
   if (refreshingPrices) return;
   final symbols = all().keys.map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty).toSet();
   if (symbols.isEmpty) {
     toast('Add a buy transaction first.');
     return;
   }

   setState(() => refreshingPrices = true);
   try {
     final result = await fetchNsePrices(symbols);

     // Apply only validated positive prices. Unmatched or failed symbols retain their saved values.
     if (result.prices.isNotEmpty) {
       prices.addAll(result.prices);
       pricesUpdatedAt = DateTime.now().toIso8601String();
       if (mounted) setState(() {});
       await save();
     }

     var message = 'Updated ${result.updated}/${symbols.length} NSE price(s). ${result.unchanged} unchanged.';
     if (result.hasError) {
       message += ' Refresh stopped: ${result.errorMessage ?? 'provider error'}.';
     } else if (result.unchanged > 0) {
       message += ' Unmatched holdings kept their previous prices.';
     }
     toast(message);
   } finally {
     if (mounted) setState(() => refreshingPrices = false);
   }
 }
 Future<Map<DateTime,double>?> _yahooHistory(String ticker, DateTime start, DateTime end) async {
   final p1=DateTime(start.year,start.month,start.day).millisecondsSinceEpoch~/1000;
   final p2=DateTime(end.year,end.month,end.day).add(const Duration(days:2)).millisecondsSinceEpoch~/1000;
   final uri=Uri.https('query1.finance.yahoo.com','/v8/finance/chart/'+ticker,{'period1':'$p1','period2':'$p2','interval':'1d','events':'div,splits'});
   try { final r=await http.get(uri,headers:const {'Accept':'application/json','User-Agent':'Mozilla/5.0'}).timeout(const Duration(seconds:12)); if(r.statusCode!=200)return null; final root=jsonDecode(r.body); final chart=root is Map?root['chart']:null; final results=chart is Map?chart['result']:null; if(results is! List||results.isEmpty||results.first is! Map)return null; final row=results.first as Map; final ts=row['timestamp']; final ind=row['indicators']; final q=ind is Map?ind['quote']:null; if(ts is! List||q is! List||q.isEmpty||q.first is! Map)return null; final closes=(q.first as Map)['close']; if(closes is! List)return null; final out=<DateTime,double>{}; for(var i=0;i<ts.length&&i<closes.length;i++){final t=ts[i],v=closes[i];if(t is! num||v is! num||v<=0)continue;final d=DateTime.fromMillisecondsSinceEpoch(t.toInt()*1000).toLocal();out[DateTime(d.year,d.month,d.day)]=v.toDouble();} return out.isEmpty?null:out; } catch(_){return null;}
 }
 double? _closeOnOrBefore(Map<DateTime,double>? h,DateTime date){if(h==null||h.isEmpty)return null;final target=DateTime(date.year,date.month,date.day);final keys=h.keys.where((d)=>!d.isAfter(target)).toList()..sort((a,b)=>b.compareTo(a));return keys.isEmpty?null:h[keys.first];}
 Future<Map<String,dynamic>> calculatePeriod(DateTime start,DateTime end) async {
   final from=DateTime(start.year,start.month,start.day),to=DateTime(end.year,end.month,end.day);if(to.isBefore(from))return {'error':'End date must be on or after start date.'};
   final symbols=trades.map((t)=>t.symbol.toUpperCase()).toSet();final histories=<String,Map<DateTime,double>?>{};for(final s in symbols){histories[s]=await _yahooHistory(s+'.NS',from,to);}final nifty=await _yahooHistory('^NSEI',from,to);
   final q0=<String,double>{},q1=<String,double>{};for(final t in chronologicalTrades(trades)){final s=t.symbol.toUpperCase();if(t.date.isBefore(from))q0[s]=(q0[s]??0)+(t.side=='BUY'?t.qty:-t.qty);if(!t.date.isAfter(to))q1[s]=(q1[s]??0)+(t.side=='BUY'?t.qty:-t.qty);}
   double startValue=0,endValue=0,buys=0,sells=0,weighted=0;final days=math.max(1,to.difference(from).inDays);var missing=0;
   for(final s in symbols){final h=histories[s],a=_closeOnOrBefore(h,from),b=_closeOnOrBefore(h,to);final qa=math.max(0.0,q0[s]??0),qb=math.max(0.0,q1[s]??0);if((qa>0&&a==null)||(qb>0&&b==null)){missing++;continue;}startValue+=qa*(a??0);endValue+=qb*(b??0);}
   for(final t in trades.where((t)=>!t.date.isBefore(from)&&!t.date.isAfter(to))){final amount=t.qty*t.price+t.charges;final elapsed=t.date.difference(from).inDays.clamp(0,days);final w=(days-elapsed)/days;if(t.side=='BUY'){buys+=amount;weighted+=amount*w;}else{final proceeds=t.qty*t.price-t.charges;sells+=proceeds;weighted-=proceeds*w;}}
   final net=endValue-startValue+sells-buys,denom=startValue+weighted;final ret=missing==0&&denom>0?net/denom*100:null;final na=_closeOnOrBefore(nifty,from),nb=_closeOnOrBefore(nifty,to);final nr=na!=null&&nb!=null&&na>0?(nb/na-1)*100:null;final yrs=to.difference(from).inDays/365.25;final ann=ret!=null&&yrs>0&&1+ret/100>0?(math.pow(1+ret/100,1/yrs)-1)*100:null;
   return {'startValue':startValue,'endValue':endValue,'netPnl':net,'periodReturn':ret,'annualised':ann,'niftyReturn':nr,'missingSymbols':missing,'start':from,'end':to,'days':to.difference(from).inDays};
 }
 Future<void> loadDashboardPeriod(String period) async {final n=DateTime.now(),end=DateTime(n.year,n.month,n.day);final start=period=='Day'?end.subtract(const Duration(days:1)):period=='Week'?end.subtract(const Duration(days:7)):DateTime(end.year,end.month-1,end.day);setState(()=>{dashboardPeriod=period,periodLoading=true});final data=await calculatePeriod(start,end);if(mounted)setState(()=>{dashboardPeriodData=data,periodLoading=false});}
 Future<void> loadReportPeriod() async {setState(()=>periodLoading=true);final data=await calculatePeriod(reportStart,reportEnd);if(mounted)setState(()=>{reportPeriodData=data,periodLoading=false});}
 Future<void> chooseReportDate(bool chooseStart) async {final picked=await showDatePicker(context:context,initialDate:chooseStart?reportStart:reportEnd,firstDate:DateTime(1990),lastDate:DateTime.now());if(picked==null)return;setState((){if(chooseStart){reportStart=picked;if(reportStart.isAfter(reportEnd))reportEnd=picked;}else{reportEnd=picked;if(reportEnd.isBefore(reportStart))reportStart=picked;}reportPeriodData=null;});await loadReportPeriod();}
 Widget periodSummaryCard(String heading,Map<String,dynamic>? d,bool loading){final ret=d?['periodReturn'] as double?,nifty=d?['niftyReturn'] as double?,net=d?['netPnl'] as double?;return Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(heading,style:const TextStyle(fontWeight:FontWeight.bold,color:navy,fontSize:17)),const SizedBox(height:10),if(loading)const LinearProgressIndicator(),if(!loading&&d==null)const Text('Choose a period and calculate.'),if(!loading&&d!=null)...[Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Net P/L',style:TextStyle(color:Colors.blueGrey,fontSize:12)),Text(net==null?'—':money.format(net),style:TextStyle(fontWeight:FontWeight.bold,color:(net??0)>=0?green:red))])),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Portfolio return',style:TextStyle(color:Colors.blueGrey,fontSize:12)),Text(ret==null?'—':ret.toStringAsFixed(2)+'%',style:TextStyle(fontWeight:FontWeight.bold,color:(ret??0)>=0?green:red))]))]),const SizedBox(height:10),Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Nifty 50',style:TextStyle(color:Colors.blueGrey,fontSize:12)),Text(nifty==null?'Unavailable':nifty.toStringAsFixed(2)+'%',style:TextStyle(fontWeight:FontWeight.bold,color:(nifty??0)>=0?green:red))])),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Annualised',style:TextStyle(color:Colors.blueGrey,fontSize:12)),Text(d['annualised']==null?'—':(d['annualised'] as double).toStringAsFixed(2)+'%',style:const TextStyle(fontWeight:FontWeight.bold,color:navy))]))]),if((d['missingSymbols'] as int? ??0)>0)Text('Historical data missing for '+d['missingSymbols'].toString()+' holding(s); portfolio return may be incomplete.',style:const TextStyle(color:Colors.deepOrange,fontSize:12))]])));}
 Future<void> addBasket()async{final c=TextEditingController();final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:const Text('New basket'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(labelText:'Basket name')),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,c.text.trim().isNotEmpty),child:const Text('Create'))]));if(ok==true){baskets.add(Basket(DateTime.now().microsecondsSinceEpoch.toString(),c.text.trim()));setState((){});save();}}
 Future<void> addTrade({Trade? old})async{
 final qty=TextEditingController(text:old?.qty.toString()??''),price=TextEditingController(text:old?.price.toString()??''),fee=TextEditingController(text:old?.charges.toString()??defaultCharges.toString());String symbolInput=old?.symbol??'',bid=old?.basketId??baskets.first.id,side=old?.side??'BUY';DateTime date=old?.date??DateTime.now();final key=GlobalKey<FormState>();
 final ok=await showDialog<bool>(context:context,builder:(x)=>StatefulBuilder(builder:(x,ss)=>AlertDialog(title:Text(old==null?'Record transaction':'Edit transaction'),content:SingleChildScrollView(child:Form(key:key,child:Column(mainAxisSize:MainAxisSize.min,children:[
 DropdownButtonFormField<String>(value:bid,decoration:const InputDecoration(labelText:'Basket'),items:baskets.map((b)=>DropdownMenuItem(value:b.id,child:Text(b.name))).toList(),onChanged:(v)=>ss(()=>bid=v??bid)),
 const SizedBox(height:8),DropdownButtonFormField<String>(value:side,decoration:const InputDecoration(labelText:'Type'),items:const [DropdownMenuItem(value:'BUY',child:Text('Buy')),DropdownMenuItem(value:'SELL',child:Text('Sell'))],onChanged:(v)=>ss(()=>{side=v??side,fee.text=estimateDeliveryCharges(double.tryParse(qty.text)??0,double.tryParse(price.text)??0,side)['Total']!.toStringAsFixed(2)})),
 const SizedBox(height:8),Autocomplete<String>(initialValue:TextEditingValue(text:symbolInput),optionsBuilder:(value){final q=value.text.trim().toUpperCase();symbolInput=value.text;if(q.isEmpty)return const Iterable<String>.empty();final found=stockDirectory.entries.where((e)=>e.key.contains(q)||e.value.toUpperCase().contains(q)).take(8).map((e)=>e.key);const common=['RELIANCE','TCS','HDFCBANK','ICICIBANK','INFY','ITC','SBIN','BHARTIARTL','LT','TATAMOTORS','TATASTEEL','ADANIENT','ADANIGREEN','NIFTYBEES'];return {...found,...common.where((s)=>s.contains(q))}.take(8);},displayStringForOption:(s)=>s,onSelected:(s){symbolInput=s;},optionsViewBuilder:(context,onSelected,options)=>Align(alignment:Alignment.topLeft,child:Material(elevation:6,borderRadius:BorderRadius.circular(12),child:ConstrainedBox(constraints:const BoxConstraints(maxHeight:250),child:ListView(shrinkWrap:true,padding:EdgeInsets.zero,children:options.map((s)=>ListTile(dense:true,leading:const Icon(Icons.show_chart,color:blue),title:Text(s),subtitle:Text(stockDirectory[s]??'NSE equity'),onTap:()=>onSelected(s))).toList())))),fieldViewBuilder:(context,controller,focusNode,onFieldSubmitted){controller.addListener(()=>symbolInput=controller.text);return TextFormField(controller:controller,focusNode:focusNode,onTap:()=>loadStockDirectory(),onFieldSubmitted:(_)=>onFieldSubmitted(),decoration:const InputDecoration(labelText:'Stock ticker',hintText:'Search symbol or company name',prefixIcon:Icon(Icons.search)),validator:(v)=>v==null||v.trim().isEmpty?'Required':null);}),
 const SizedBox(height:8),TextFormField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Quantity'),onChanged:(_)=>ss(()=>fee.text=estimateDeliveryCharges(double.tryParse(qty.text)??0,double.tryParse(price.text)??0,side)['Total']!.toStringAsFixed(2)),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<=0?'Enter quantity above zero':null),
 const SizedBox(height:8),TextFormField(controller:price,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Price per share (₹)'),onChanged:(_)=>ss(()=>fee.text=estimateDeliveryCharges(double.tryParse(qty.text)??0,double.tryParse(price.text)??0,side)['Total']!.toStringAsFixed(2)),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<=0?'Enter price above zero':null),
 const SizedBox(height:8),TextFormField(controller:fee,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Estimated charges (₹) • editable'),validator:(v)=>double.tryParse(v??'')==null||double.parse(v!)<0?'Enter valid charges':null),Builder(builder:(context){final breakdown=estimateDeliveryCharges(double.tryParse(qty.text)??0,double.tryParse(price.text)??0,side);return Container(margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:const Color(0xFFEAF2FF),borderRadius:BorderRadius.circular(12)),child:Column(children:[const Align(alignment:Alignment.centerLeft,child:Text('Estimated NSE equity-delivery charges',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:navy))),const SizedBox(height:5),...breakdown.entries.where((e)=>e.key!='Total').map((e)=>Padding(padding:const EdgeInsets.symmetric(vertical:2),child:Row(children:[Expanded(child:Text(e.key,style:const TextStyle(fontSize:12,color:navy))),Text(money.format(e.value),style:const TextStyle(fontSize:12,color:navy))]))),const Divider(height:10),Row(children:[const Expanded(child:Text('Total estimated charges',style:TextStyle(fontWeight:FontWeight.bold,color:navy))),Text(money.format(breakdown['Total']!),style:const TextStyle(fontWeight:FontWeight.bold,color:navy))]),const Text('Approximate rates; confirm against your broker contract note.',style:TextStyle(fontSize:10,color:Colors.blueGrey))]));}),
 Row(children:[const Text('Trade date'),const Spacer(),TextButton(onPressed:()async{final d=await showDatePicker(context:x,initialDate:date,firstDate:DateTime(1990),lastDate:DateTime(2100));if(d!=null)ss(()=>date=d);},child:Text(dates.format(date)))])
]))),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>key.currentState!.validate()?Navigator.pop(x,true):null,child:const Text('Save'))])));
 if(ok!=true)return;
 final symbol=symbolInput.trim().toUpperCase(),q=double.parse(qty.text),p=double.parse(price.text),f=double.parse(fee.text);
 final original=List<Trade>.from(trades);
 if(old!=null)trades.removeWhere((t)=>t.id==old.id);
 trades.add(Trade(old?.id??DateTime.now().microsecondsSinceEpoch.toString(),bid,symbol,side,q,p,f,date));
 if(!hasValidTransactionSequence(trades)){
   trades..clear()..addAll(original);
   toast('This transaction would make shares held go negative on its trade date. Check the date, basket, and quantity.');
   return;
 }
 prices.putIfAbsent(symbol,()=>p);setState((){});await save();
 }
 Future<void> setPrice(String s)async{final c=TextEditingController(text:(prices[s]??0).toString());final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:Text('Current price: '+s),content:TextField(controller:c,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Market price (₹)')),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,double.tryParse(c.text)!=null&&double.parse(c.text)>=0),child:const Text('Save'))]));if(ok==true){prices[s]=double.parse(c.text);setState((){});save();}}
 Future<void> exportCsv()async{final rows=<List<dynamic>>[['Date','Basket','Type','Symbol','Quantity','Price','Charges','Transaction ID']];for(final t in trades){final b=baskets.where((b)=>b.id==t.basketId).firstOrNull;rows.add([t.date.toIso8601String(),b?.name??t.basketId,t.side,t.symbol,t.qty,t.price,t.charges,t.id]);}final text=const ListToCsvConverter().convert(rows);final path=await FilePicker.platform.saveFile(fileName:'equitybasket-ledger.csv',type:FileType.custom,allowedExtensions:['csv'],bytes:utf8.encode(text));if(mounted)toast(path==null?'Export cancelled':'CSV saved');}

 Future<void> importContractNote([String? requestedBasketId]) async {
   if(baskets.isEmpty){if(mounted)toast('Create a basket before importing a contract note.');return;}
   Basket? destination;
   if(requestedBasketId!=null){destination=baskets.where((b)=>b.id==requestedBasketId).firstOrNull;}
   else if(baskets.length==1){destination=baskets.first;}
   else {destination=await showDialog<Basket>(context:context,builder:(ctx){String? chosen=baskets.first.id;return StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(title:const Text('Import contract note'),content:DropdownButtonFormField<String>(value:chosen,decoration:const InputDecoration(labelText:'Destination basket'),items:baskets.map((b)=>DropdownMenuItem(value:b.id,child:Text(b.name))).toList(),onChanged:(v)=>setDialog(()=>chosen=v)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,baskets.where((b)=>b.id==chosen).firstOrNull),child:const Text('Choose basket'))]));});}
   if(destination==null)return;
   final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['pdf'],withData:true);
   if(picked==null||picked.files.single.bytes==null)return;
   final passwordController=TextEditingController();
   final password=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Contract note password'),content:TextField(controller:passwordController,obscureText:true,autofocus:true,decoration:const InputDecoration(labelText:'PDF password',hintText:'Enter password for this PDF'),onSubmitted:(v)=>Navigator.pop(ctx,v)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,passwordController.text),child:const Text('Read PDF'))]));
   passwordController.dispose();if(password==null||password.isEmpty)return;
   PdfDocument? document;
   try {
     await pdfrxFlutterInitialize();
     document=await PdfDocument.openData(picked.files.single.bytes!,passwordProvider:() async=>password,firstAttemptByEmptyPassword:false,sourceName:picked.files.single.name);
     final pagesText=<String>[];
     for(final page in document.pages){final pageText=await page.loadText();pagesText.add(pageText?.fullText??'');}
     final allText=pagesText.join('\n');
     if(!allText.toUpperCase().contains('CONTRACT NOTE')||!allText.toUpperCase().contains('ANNEXURE A'))throw const FormatException('This does not look like a supported Zerodha contract note with Annexure A trade details.');
     final dateMatch=RegExp(r'Trade Date:\\s*(\\d{2}/\\d{2}/\\d{4})',caseSensitive:false).firstMatch(allText);
     if(dateMatch==null)throw const FormatException('Could not find Trade Date in the contract note.');
     final tradeDate=DateFormat('dd/MM/yyyy').parseStrict(dateMatch.group(1)!);
     final rowPattern=RegExp(r'(\\d{13,16})\\s+(\\d{2}:\\d{2}:\\d{2})\\s+(\\d{5,12})\\s+(\\d{2}:\\d{2}:\\d{2})\\s+([A-Z0-9&._-]+/INE[A-Z0-9]{9})\\s+([BS])\\s+(NSE|BSE)\\s+(\\d+(?:\\.\\d+)?)\\s+([\\d.]+)\\s+([\\d.]+)',caseSensitive:false);
     final candidates=<Trade>[];final seenIds=<String>{};var ignoredExisting=0;
     for(final match in rowPattern.allMatches(allText.toUpperCase())){
       final tradeNo=match.group(3)!;final symbolPart=match.group(5)!;final symbol=symbolPart.split('/').first.split('-').first;
       final side=match.group(6)=='B'?'BUY':'SELL';final exchange=match.group(7)!;
       final qty=double.tryParse(match.group(8)!);final price=double.tryParse(match.group(10)!);
       if(qty==null||price==null||qty<=0||price<=0)continue;
       final id='CN-${DateFormat('yyyyMMdd').format(tradeDate)}-$tradeNo';
       if(trades.any((t)=>t.id==id)||!seenIds.add(id)){ignoredExisting++;continue;}
       final charges=estimateDeliveryCharges(qty,price,side)['Total']??0.0;
       candidates.add(Trade(id,destination.id,symbol,side,qty,price,charges,tradeDate));
     }
     if(candidates.isEmpty)throw const FormatException('No new trade rows were found in Annexure A. The PDF may already be imported, or its layout may be unsupported.');
     final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Review contract note import'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text('Basket: ${destination!.name}'),Text('Trade date: ${dates.format(tradeDate)}'),Text('${candidates.length} new trades • $ignoredExisting already imported'),const SizedBox(height:10),
       const Text('Preview (first 8 trades)',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:6),
       ...candidates.take(8).map((t)=>Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text('${t.side}  ${t.symbol}  ${t.qty} × ${money.format(t.price)}',style:const TextStyle(fontSize:12)))),
       if(candidates.length>8)Text('…and ${candidates.length-8} more'),
       const SizedBox(height:10),const Text('Trade prices come from Annexure A. Per-trade levies are not itemised in this PDF, so charges are estimated using the app settings.',style:TextStyle(fontSize:12,color:Colors.blueGrey)),
     ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Import trades'))]));
     if(confirmed!=true)return;
     final accepted=<Trade>[],qtyByKey=<String,double>{};
     for(final trade in chronologicalTrades([...trades,...candidates])){
       final key='${trade.basketId}|${trade.symbol}';final held=qtyByKey[key]??0.0;
       if(trade.side=='BUY'){qtyByKey[key]=held+trade.qty;if(candidates.contains(trade))accepted.add(trade);}
       else if(trade.qty<=held+0.0000001){qtyByKey[key]=held-trade.qty;if(candidates.contains(trade))accepted.add(trade);}
     }
     final rejected=candidates.length-accepted.length;
     trades.addAll(accepted);
     for(final trade in accepted){prices.putIfAbsent(trade.symbol,()=>trade.price);}
     setState((){});await save();
     if(mounted)toast('Imported ${accepted.length} trades into ${destination.name}; $ignoredExisting duplicate(s) skipped; $rejected sell trade(s) skipped because holdings were insufficient.');
   } catch(e) {
     if(mounted)toast('PDF import failed. Check the password and confirm this is a text-based Zerodha contract note. Details: $e');
   } finally {document?.dispose();}
 }
 Future<void> importCsv([String? requestedBasketId]) async {
   if(baskets.isEmpty){if(mounted)toast('Create a basket before importing transactions.');return;}
   Basket? destination;
   if(requestedBasketId!=null){destination=baskets.where((b)=>b.id==requestedBasketId).firstOrNull;}
   else if(baskets.length==1){destination=baskets.first;}
   else {destination=await showDialog<Basket>(context:context,builder:(ctx){String? chosen=baskets.first.id;return StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(title:const Text('Import into basket'),content:DropdownButtonFormField<String>(value:chosen,decoration:const InputDecoration(labelText:'Destination basket'),items:baskets.map((b)=>DropdownMenuItem(value:b.id,child:Text(b.name))).toList(),onChanged:(v)=>setDialog(()=>chosen=v)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,baskets.where((b)=>b.id==chosen).firstOrNull),child:const Text('Choose basket'))]));});}
   if(destination==null)return;
   final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['csv'],withData:true);
   if(picked==null||picked.files.single.bytes==null)return;
   try {
     final rows=const CsvToListConverter().convert(utf8.decode(picked.files.single.bytes!));
     if(rows.length<2)throw const FormatException('CSV must contain a header and transaction rows.');
     const dateAliases=['date','trade date','trade_date','transaction date','order date'];
     const sideAliases=['type','trade type','buy/sell','action','transaction type','txn type'];
     const symbolAliases=['symbol','tradingsymbol','trading symbol','scrip','instrument','stock symbol'];
     const quantityAliases=['quantity','qty','traded quantity','filled quantity','filled qty'];
     const priceAliases=['price','trade price','average price','avg price','traded price'];
     const basketAliases=['basket','portfolio'];
     const chargeAliases=['charges','transaction charges','brokerage'];
     const idAliases=['transaction id','trade id','trade_id','trade no','trade number','id'];
     bool hasAny(List<String> header,List<String> aliases)=>aliases.any(header.contains);
     var headerRow=-1;List<String> header=[];
     for(var i=0;i<rows.length&&i<15;i++){
       final candidate=rows[i].map((e)=>e.toString().trim().toLowerCase()).toList();
       if(hasAny(candidate,dateAliases)&&hasAny(candidate,sideAliases)&&hasAny(candidate,symbolAliases)&&hasAny(candidate,quantityAliases)&&hasAny(candidate,priceAliases)){headerRow=i;header=candidate;break;}
     }
     if(headerRow<0)throw const FormatException('Could not find transaction columns. Expected Date/Trade Date, Type/Trade Type, Symbol, Quantity and Price.');
     int col(List<String> aliases){for(final alias in aliases){final index=header.indexOf(alias);if(index>=0)return index;}return -1;}
     final dateCol=col(dateAliases),sideCol=col(sideAliases),symbolCol=col(symbolAliases),quantityCol=col(quantityAliases),priceCol=col(priceAliases),basketCol=col(basketAliases),chargesCol=col(chargeAliases),idCol=col(idAliases);
     String field(List<dynamic> row,int index)=>index>=0&&index<row.length?row[index].toString().trim():'';
     DateTime? parseDate(String raw){
       final direct=DateTime.tryParse(raw);if(direct!=null)return direct;
       final serial=double.tryParse(raw);if(serial!=null&&serial>=20000&&serial<=80000)return DateTime(1899,12,30).add(Duration(days:serial.floor()));
       for(final format in <DateFormat>[DateFormat('dd-MM-yyyy'),DateFormat('dd/MM/yyyy'),DateFormat('dd-MMM-yyyy'),DateFormat('dd MMM yyyy'),DateFormat('dd/MM/yy'),DateFormat('dd-MM-yy'),DateFormat('dd-MM-yyyy HH:mm:ss'),DateFormat('dd/MM/yyyy HH:mm:ss'),DateFormat('yyyy-MM-dd HH:mm:ss')]){try{return format.parseStrict(raw);}catch(_){}}
       return null;
     }
     final looksLikeZerodha=header.contains('trade id')||header.contains('trading symbol')||header.contains('tradingsymbol');
     final defaultBasketName=looksLikeZerodha?'Zerodha Import':'Imported Trades';
     final seenIds=<String>{},seenFingerprints=<String>{};var skipped=0,invalid=0;
     final candidates=<Trade>[];
     for(final row in rows.skip(headerRow+1)){
       if(row.every((value)=>value.toString().trim().isEmpty))continue;
       final symbol=field(row,symbolCol).toUpperCase();
       var side=field(row,sideCol).toUpperCase();
       if(side=='B')side='BUY';if(side=='S')side='SELL';
       final quantity=double.tryParse(field(row,quantityCol).replaceAll(',',''));
       final unitPrice=double.tryParse(field(row,priceCol).replaceAll(',',''));
       final charges=double.tryParse(field(row,chargesCol).replaceAll(',',''))??0;
       final when=parseDate(field(row,dateCol));
       if(symbol.isEmpty||!['BUY','SELL'].contains(side)||quantity==null||quantity<=0||unitPrice==null||unitPrice<=0||charges<0||when==null){invalid++;continue;}
       final txId=field(row,idCol);
       final basketName=destination.name;
       final fingerprint='${when.toIso8601String()}|${basketName.toLowerCase()}|$side|$symbol|$quantity|$unitPrice';
       if(txId.isNotEmpty&&(trades.any((t)=>t.id==txId)||!seenIds.add(txId))){skipped++;continue;}
       if(txId.isEmpty&&(seenFingerprints.contains(fingerprint)||trades.any((t){final b=baskets.where((b)=>b.id==t.basketId);return b.isNotEmpty&&b.first.name.toLowerCase()==basketName.toLowerCase()&&t.date==when&&t.side==side&&t.symbol==symbol&&t.qty==quantity&&t.price==unitPrice;}))){skipped++;continue;}
       seenFingerprints.add(fingerprint);
       final basket=destination;
       final id=txId.isEmpty?DateTime.now().microsecondsSinceEpoch.toString()+candidates.length.toString():txId;
       candidates.add(Trade(id,basket.id,symbol,side,quantity,unitPrice,charges,when));
       prices.putIfAbsent(symbol,()=>unitPrice);
     }
     final accepted=<Trade>[],qtyByKey=<String,double>{};
     final ordered=chronologicalTrades([...trades,...candidates]);
     for(final trade in ordered){
       final key='${trade.basketId}|${trade.symbol}';final held=qtyByKey[key]??0.0;
       if(trade.side=='BUY'){qtyByKey[key]=held+trade.qty;if(candidates.contains(trade))accepted.add(trade);}
       else if(trade.qty<=held+0.0000001){qtyByKey[key]=held-trade.qty;if(candidates.contains(trade))accepted.add(trade);}
       else if(candidates.contains(trade)){invalid++;}
     }
     trades.addAll(accepted);setState((){});await save();
     if(mounted)toast('Imported ${accepted.length}; skipped ${skipped} duplicate(s); rejected ${invalid} invalid/oversell row(s). CSV supports EquityBasket exports and common Zerodha tradebook columns; PDF contract notes are not supported yet.');
   }catch(e){if(mounted)toast('CSV import failed: $e');}
 }
 @override Widget build(BuildContext c){if(!ready)return const Scaffold(body:Center(child:CircularProgressIndicator()));final pages=[dashboard(),basketPage(),ledgerPage(),reportsPage(),settingsPage()];return Scaffold(appBar:AppBar(title:const Text('EquityBasket',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(onPressed:()=>importContractNote(),tooltip:'Import Zerodha contract note PDF',icon:const Icon(Icons.picture_as_pdf_rounded)),IconButton(onPressed:refreshingPrices?null:refreshPrices,icon:refreshingPrices?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.refresh_rounded),tooltip:'Refresh EOD prices'),IconButton(onPressed:()=>addTrade(),icon:const Icon(Icons.add_chart),tooltip:'Add transaction')]),body:pages[tab],floatingActionButton:tab==1?FloatingActionButton.extended(onPressed:addBasket,icon:const Icon(Icons.add),label:const Text('New basket')):tab==2?FloatingActionButton.extended(onPressed:()=>addTrade(),icon:const Icon(Icons.add),label:const Text('Transaction')):null,bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),label:'Home'),NavigationDestination(icon:Icon(Icons.grid_view),label:'Baskets'),NavigationDestination(icon:Icon(Icons.receipt_long),label:'Ledger'),NavigationDestination(icon:Icon(Icons.query_stats),label:'Reports'),NavigationDestination(icon:Icon(Icons.tune),label:'Settings')]));}
 Widget title(String s,{VoidCallback? onTap})=>Row(children:[Expanded(child:Text(s,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:navy))),if(onTap!=null)TextButton(onPressed:onTap,child:const Text('View all'))]);
 Widget metric(String s,String v)=>Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(s,style:const TextStyle(color:Colors.white70,fontSize:12)),const SizedBox(height:5),Text(v,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600))]));
 Widget dashboard()=>ListView(padding:const EdgeInsets.all(16),children:[
   Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[navy,Color(0xFF0678B8)]),borderRadius:BorderRadius.circular(24)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Expanded(child:Text('TOTAL PORTFOLIO VALUE',style:TextStyle(color:Colors.white70,letterSpacing:1))),IconButton(onPressed:refreshingPrices?null:refreshPrices,color:Colors.white,tooltip:'Refresh all prices',icon:refreshingPrices?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.refresh_rounded))]),const SizedBox(height:2),
    Text(money.format(value),style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.bold)),const SizedBox(height:8),
    Text((pnl>=0?'▲ +':'▼ ')+money.format(pnl)+' • '+(invested>0?(pnl/invested*100).toStringAsFixed(2)+'%':'—'),style:TextStyle(color:pnl>=0?const Color(0xFF48F6A8):const Color(0xFFFFAAAA))),const SizedBox(height:20),
    Row(children:[metric('Invested',money.format(invested)),metric('Unrealised P/L',money.format(pnl))]),
   ])),
   const SizedBox(height:22),
   Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     const Text('Portfolio performance',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold,color:navy)),
     const SizedBox(height:10),
     SegmentedButton<String>(segments:const [ButtonSegment(value:'Day',label:Text('Day')),ButtonSegment(value:'Week',label:Text('Week')),ButtonSegment(value:'Month',label:Text('Month'))],selected:{dashboardPeriod},onSelectionChanged:(s)=>loadDashboardPeriod(s.first)),
     const SizedBox(height:12),if(periodLoading)const LinearProgressIndicator(),
     if(dashboardPeriodData!=null&&!periodLoading)...[
       Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Starting value',style:TextStyle(color:Colors.blueGrey,fontSize:11)),Text(money.format(dashboardPeriodData!['startValue']),style:const TextStyle(fontWeight:FontWeight.bold,color:navy))])),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Ending value',style:TextStyle(color:Colors.blueGrey,fontSize:11)),Text(money.format(dashboardPeriodData!['endValue']),style:const TextStyle(fontWeight:FontWeight.bold,color:navy))]))]),
       const SizedBox(height:10),
       Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Net P/L',style:TextStyle(color:Colors.blueGrey,fontSize:11)),Text(money.format(dashboardPeriodData!['netPnl']),style:TextStyle(fontWeight:FontWeight.bold,color:(dashboardPeriodData!['netPnl'] as num)>=0?green:red))])),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Portfolio return',style:TextStyle(color:Colors.blueGrey,fontSize:11)),Text(dashboardPeriodData!['periodReturn']==null?'—':(dashboardPeriodData!['periodReturn'] as double).toStringAsFixed(2)+'%',style:const TextStyle(fontWeight:FontWeight.bold,color:navy))]))]),
       const Divider(height:22),
       Row(children:[const Expanded(child:Text('Nifty 50 • same period',style:TextStyle(color:Colors.blueGrey,fontSize:12))),Text(dashboardPeriodData!['niftyReturn']==null?'Unavailable':(dashboardPeriodData!['niftyReturn'] as double).toStringAsFixed(2)+'%',style:const TextStyle(fontWeight:FontWeight.bold,color:blue))]),
     ],
     if(dashboardPeriodData==null&&!periodLoading)TextButton(onPressed:()=>loadDashboardPeriod(dashboardPeriod),child:const Text('Calculate period returns')),
     const SizedBox(height:4),const Text('Historical prices from Yahoo Finance. Returns are estimates; missing price history can affect portfolio results.',style:TextStyle(fontSize:11,color:Colors.blueGrey))
   ]))),
   const SizedBox(height:12),title('Quick actions'),
   Row(children:[Expanded(child:action(Icons.add_circle_outline,'Buy / Sell',()=>addTrade())),Expanded(child:action(Icons.upload_file,'Import CSV',importCsv)),Expanded(child:action(Icons.download,'Export CSV',exportCsv))]),
   const SizedBox(height:14),const Text('Free refresh uses end-of-day NSE/BSE data; it is not intraday live pricing. Manual price entry remains available.',style:TextStyle(color:Colors.blueGrey,fontSize:12)),
 ]);
 Widget action(IconData i,String s,VoidCallback f)=>Card(child:InkWell(onTap:f,borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[Icon(i,color:blue),const SizedBox(height:6),Text(s,style:const TextStyle(fontSize:12))]))));
 Widget basketPage(){
   final selected=baskets.where((b)=>b.id==selectedBasketId).firstOrNull;
   if(selected!=null){
     final h=holdings(selected.id);final invested=h.values.fold(0.0,(s,x)=>s+x.cost),value=h.values.fold(0.0,(s,x)=>s+x.value),pnl=value-invested;
     return ListView(padding:const EdgeInsets.all(16),children:[
       Row(children:[IconButton(onPressed:()=>setState(()=>selectedBasketId=null),icon:const Icon(Icons.arrow_back)),Expanded(child:Text(selected.name,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:navy))),IconButton(onPressed:()=>importCsv(selected.id),tooltip:'Import CSV into this basket',icon:const Icon(Icons.upload_file)),PopupMenuButton<String>(onSelected:(v){if(v=='rename')renameBasket(selected);if(v=='delete')deleteBasket(selected);},itemBuilder:(_)=>[const PopupMenuItem(value:'rename',child:Text('Rename')),if(baskets.length>1)const PopupMenuItem(value:'delete',child:Text('Delete'))])]),
       Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text('${h.length} active shares • ${byBasket(selected.id).length} trades',style:const TextStyle(color:Colors.blueGrey)),const SizedBox(height:16),
         Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('CURRENT VALUE',style:TextStyle(fontSize:11,color:Colors.blueGrey)),const SizedBox(height:4),Text(money.format(value),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:navy))])),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('INVESTED VALUE',style:TextStyle(fontSize:11,color:Colors.blueGrey)),const SizedBox(height:4),Text(money.format(invested),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600,color:navy))]))]),
         const Divider(height:24),
         Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('UNREALISED P/L',style:TextStyle(fontSize:11,color:Colors.blueGrey)),Text('${pnl>=0?'+':''}${money.format(pnl)}',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:pnl>=0?green:red))])),Text(invested>0?'${(pnl/invested*100).toStringAsFixed(2)}%':'—',style:TextStyle(fontSize:17,fontWeight:FontWeight.bold,color:pnl>=0?green:red))])
       ]))),
       const SizedBox(height:12),title('Holdings'),
       if(h.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('No active shares in this basket yet.'))),
       ...h.values.map((x)=>Card(child:ListTile(leading:const Icon(Icons.show_chart,color:blue),title:Text(x.symbol,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${x.qty.toStringAsFixed(4)} shares • avg cost ${money.format(x.qty>0?x.cost/x.qty:0)}'),trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[Text(money.format(x.value),style:const TextStyle(fontWeight:FontWeight.bold)),Text('${x.pnl>=0?'+':''}${money.format(x.pnl)}',style:TextStyle(color:x.pnl>=0?green:red,fontWeight:FontWeight.w600))])))),
       const SizedBox(height:12),FilledButton.icon(onPressed:()=>addTrade(),icon:const Icon(Icons.add),label:const Text('Add trade')),
     ]);
   }
   return ListView(padding:const EdgeInsets.all(16),children:[
     Row(children:[Expanded(child:title('All baskets')),IconButton(onPressed:importCsv,tooltip:'Import CSV into a selected basket',icon:const Icon(Icons.upload_file,color:blue))]),
     const Padding(padding:EdgeInsets.only(bottom:12),child:Text('Each folder tracks its own holdings, current value and profit/loss.',style:TextStyle(color:Colors.blueGrey,fontSize:12))),
     ...baskets.map((b){
       final h=holdings(b.id);final invested=h.values.fold(0.0,(s,x)=>s+x.cost),value=h.values.fold(0.0,(s,x)=>s+x.value),pnl=value-invested;
       return Card(clipBehavior:Clip.antiAlias,elevation:2,margin:const EdgeInsets.only(bottom:12),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),child:InkWell(onTap:()=>setState(()=>selectedBasketId=b.id),borderRadius:BorderRadius.circular(20),child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
         Row(children:[Container(width:52,height:52,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF0878FF),Color(0xFF19B8C7)]),borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.folder_rounded,color:Colors.white,size:28)),const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(b.name,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:navy)),const SizedBox(height:4),Text('${h.length} shares • ${byBasket(b.id).length} trades',style:const TextStyle(color:Colors.blueGrey))])),const Icon(Icons.chevron_right,color:navy)]),
         const Divider(height:24),
         Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('CURRENT VALUE',style:TextStyle(fontSize:10,color:Colors.blueGrey)),const SizedBox(height:5),Text(money.format(value),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:navy))])),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('UNREALISED P/L',style:TextStyle(fontSize:10,color:Colors.blueGrey)),const SizedBox(height:5),Text('${pnl>=0?'+':''}${money.format(pnl)}',style:TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:pnl>=0?green:red))])),Text(invested>0?'${(pnl/invested*100).toStringAsFixed(1)}%':'—',style:TextStyle(fontWeight:FontWeight.bold,color:pnl>=0?green:red))]),
         const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.end,children:[TextButton.icon(onPressed:()=>importCsv(b.id),icon:const Icon(Icons.upload_file),label:const Text('Import CSV')),TextButton(onPressed:()=>renameBasket(b),child:const Text('Rename')),if(baskets.length>1)TextButton(onPressed:()=>deleteBasket(b),child:const Text('Delete'))])
       ]))));
     }),
   ]);
 }
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
      // chronologicalTrades preserves input order when date-only transactions tie.
      double quantity = 0, cost = 0;
      for (final trade in chronologicalTrades(items)) {
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
     // Stable ordering is important when a tradebook has date-only timestamps.
     final lots=<Map<String,dynamic>>[];
     for(final t in chronologicalTrades(entries)){
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
 Future<void> _editDefaultCharges() async {
   final controller=TextEditingController(text:defaultCharges.toStringAsFixed(2));
   final ok=await showDialog<bool>(context:context,builder:(x)=>AlertDialog(title:const Text('Default transaction charges'),content:TextField(controller:controller,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Default charges per transaction (₹)')),actions:[TextButton(onPressed:()=>Navigator.pop(x,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,double.tryParse(controller.text)!=null&&double.parse(controller.text)>=0),child:const Text('Save'))]));
   if(ok==true){defaultCharges=double.parse(controller.text);setState((){});await save();}
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
   final absoluteGain=sells+value-buys;
   final absolutePct=buys>0?absoluteGain/buys*100:null;
   final isSingleInitialBuy=trades.length==1&&trades.first.side=='BUY';
   final elapsedDays=trades.isEmpty?1:math.max(1,DateTime.now().difference(trades.first.date).inDays);
   final cagr=isSingleInitialBuy&&buys>0?math.pow(value/buys,365.25/elapsedDays)-1:null;
   final sortedYears=years.keys.toList()..sort((a,b)=>b.compareTo(a));
   return ListView(padding:const EdgeInsets.all(16),children:[
      title('Performance report'),
      Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Custom-period performance',style:TextStyle(fontWeight:FontWeight.bold,color:navy,fontSize:17)),
        const SizedBox(height:10),
        Row(children:[Expanded(child:OutlinedButton.icon(onPressed:()=>chooseReportDate(true),icon:const Icon(Icons.calendar_today),label:Text('From '+dates.format(reportStart)))),const SizedBox(width:8),Expanded(child:OutlinedButton.icon(onPressed:()=>chooseReportDate(false),icon:const Icon(Icons.event),label:Text('To '+dates.format(reportEnd))))]),
        const SizedBox(height:8),FilledButton.icon(onPressed:loadReportPeriod,icon:const Icon(Icons.query_stats),label:const Text('Calculate selected period'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(44))),
      ]))),
      periodSummaryCard('Selected-period results',reportPeriodData,periodLoading),
     reportCard('Portfolio cost basis',money.format(invested),Icons.account_balance_wallet),
     reportCard('Market value',money.format(value),Icons.show_chart),
     reportCard('Unrealised profit / loss',money.format(pnl),Icons.trending_up,pnl>=0?green:red),
     reportCard('Realised P/L (average cost)',money.format(years.values.fold(0.0,(s,v)=>s+v)),Icons.check_circle,years.values.fold(0.0,(s,v)=>s+v)>=0?green:red),
     reportCard('Cumulative absolute return',absolutePct==null?'—':absolutePct.toStringAsFixed(2)+'%',Icons.assessment,absoluteGain>=0?green:red),
     reportCard('CAGR (single initial buy only)',cagr==null?'— (multiple cash flows)':(cagr*100).toStringAsFixed(2)+'%',Icons.timelapse,cagr==null?blue:cagr>=0?green:red),
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
   Card(child:ListTile(leading:const Icon(Icons.cloud_download,color:blue),title:const Text('Refresh NSE/BSE prices'),subtitle:Text(refreshingPrices?'Fetching latest available end-of-day prices…':pricesUpdatedAt==null?'Free public data • End-of-day, not live':'Last refreshed: '+DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(pricesUpdatedAt!)??DateTime.now())),trailing:refreshingPrices?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.refresh),onTap:refreshingPrices?null:refreshPrices)),
   Card(child:ListTile(leading:const Icon(Icons.price_change,color:blue),title:const Text('Update current prices manually'),subtitle:const Text('Fallback if a symbol is not available in the free data'),onTap:pricePicker)),
   Card(child:ListTile(leading:const Icon(Icons.payments_outlined,color:blue),title:const Text('Default transaction charges'),subtitle:Text('New transaction default: ${money.format(defaultCharges)} (editable per trade)'),onTap:_editDefaultCharges)),
   Card(child:ListTile(leading:const Icon(Icons.tune,color:blue),title:const Text('Tax estimate assumptions'),subtitle:Text('STCG ${stcgRate.toStringAsFixed(2)}% • LTCG ${ltcgRate.toStringAsFixed(2)}%'),onTap:_editTaxSettings)),
   Card(child:ListTile(leading:const Icon(Icons.upload_file,color:blue),title:const Text('Import CSV'),subtitle:const Text('Rows with duplicate transaction IDs are skipped'),onTap:importCsv)),
   Card(child:ListTile(leading:const Icon(Icons.download,color:blue),title:const Text('Export CSV backup'),onTap:exportCsv)),
   const Card(child:ListTile(leading:Icon(Icons.storage,color:blue),title:Text('Local storage'),subtitle:Text('Baskets, prices and trades are stored on this device. Export a backup before uninstalling.'))),
   const Padding(padding:EdgeInsets.all(12),child:Text('CAGR is shown only for a single initial buy. With recurring buys and sells, use XIRR. Tax outcomes depend on current law and personal circumstances; estimates are not tax advice.',style:TextStyle(color:Colors.blueGrey,fontSize:12))),
 ]);
 Future<void> pricePicker()async{final symbols=all().keys.toList()..sort();if(symbols.isEmpty){toast('Add a buy transaction first.');return;}showModalBottomSheet(context:context,builder:(x)=>SafeArea(child:ListView(shrinkWrap:true,children:[const ListTile(title:Text('Select a holding to update price')),...symbols.map((s)=>ListTile(title:Text(s),subtitle:Text(money.format(prices[s]??0)),trailing:const Icon(Icons.edit),onTap:(){Navigator.pop(x);setPrice(s);} ))])));}
}
