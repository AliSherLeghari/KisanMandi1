import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_store.dart';
import 'models.dart';
import 'calculations.dart';

String pkr(double value)=>NumberFormat.currency(locale:'en_PK',symbol:'Rs ',decimalDigits:2).format(value);

class PricesScreen extends StatefulWidget {
  final AppStore store;
  const PricesScreen({super.key,required this.store});
  @override State<PricesScreen> createState()=>_PricesScreenState();
}
class _PricesScreenState extends State<PricesScreen> {
  String? marketId,category;
  String search='';
  @override Widget build(BuildContext context) {
    final s=widget.store;
    if(s.markets.isEmpty)return const Center(child:Text('No markets available. Refresh to retry.'));
    marketId ??=s.markets.first.id;
    final items=s.crops.where((c)=>c.name.toLowerCase().contains(search.toLowerCase())&&(category==null||c.category==category)).toList();
    return RefreshIndicator(onRefresh:s.refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('Today’s simulated mandi rates',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      const Text('Fictional PKR/kg · Pull down to refresh',style:TextStyle(color:Colors.black54)),
      const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:marketId,
        decoration:const InputDecoration(labelText:'Select market',border:OutlineInputBorder(),prefixIcon:Icon(Icons.location_city)),
        items:s.markets.map((m)=>DropdownMenuItem(value:m.id,child:Text('${m.name} · ${m.district}'))).toList(),
        onChanged:(v)=>setState(()=>marketId=v)),const SizedBox(height:12),
      TextField(onChanged:(v)=>setState(()=>search=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Search crops',border:OutlineInputBorder())),
      const SizedBox(height:10),SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        ChoiceChip(label:const Text('All'),selected:category==null,onSelected:(_)=>setState(()=>category=null)),
        ...s.crops.map((c)=>c.category).toSet().map((c)=>Padding(padding:const EdgeInsets.only(left:8),child:ChoiceChip(label:Text(c),selected:category==c,onSelected:(_)=>setState(()=>category=c))))
      ])),const SizedBox(height:8),
      for(final crop in items)Builder(builder:(context){
        final hist=s.history(crop.id,marketId!);if(hist.isEmpty)return const SizedBox.shrink();
        final last=hist.last;final prev=hist.length<2?null:hist[hist.length-2];
        final delta=prev==null?null:PriceMath.change(last.price,prev.price);
        final pct=prev==null?null:PriceMath.changePercent(last.price,prev.price);
        return Card(child:ListTile(title:Text(crop.name,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${crop.category} · ${last.date}\n${delta==null?'No previous day':'${delta>=0?'+':''}${pkr(delta)} (${pct==null?'—':'${pct>=0?'+':''}${pct.toStringAsFixed(1)}%'})'}'),
          isThreeLine:true,trailing:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,
            children:[Text(pkr(last.price),style:const TextStyle(fontWeight:FontWeight.bold)),const Text('/kg',style:TextStyle(fontSize:12))]),
          onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CropDetail(store:s,crop:crop,marketId:marketId!)))));
      }),
      if(items.isEmpty)const Padding(padding:EdgeInsets.all(22),child:Text('No matching crops')),
      const SizedBox(height:12),OutlinedButton.icon(onPressed:s.refresh,icon:const Icon(Icons.refresh),label:const Text('Refresh prices and alerts')),
    ]));
  }
}

class CropDetail extends StatefulWidget {
  final AppStore store;
  final Crop crop;
  final String marketId;
  const CropDetail({super.key,required this.store,required this.crop,required this.marketId});
  @override State<CropDetail> createState()=>_CropDetailState();
}
class _CropDetailState extends State<CropDetail> {
  late String marketId=widget.marketId;
  @override Widget build(BuildContext context) {
    final s=widget.store;final h=s.history(widget.crop.id,marketId);final rankings=s.ranking(widget.crop.id);
    if(h.isEmpty)return Scaffold(appBar:AppBar(title:Text(widget.crop.name)),body:const Center(child:Text('No price history available')));
    final min=h.map((x)=>x.price).reduce((a,b)=>a<b?a:b);
    final max=h.map((x)=>x.price).reduce((a,b)=>a>b?a:b);
    return Scaffold(appBar:AppBar(title:Text('${widget.crop.name} · 14 days')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        DropdownButtonFormField<String>(initialValue:marketId,decoration:const InputDecoration(labelText:'Market',border:OutlineInputBorder()),
          items:s.markets.map((m)=>DropdownMenuItem(value:m.id,child:Text(m.name))).toList(),onChanged:(v)=>setState(()=>marketId=v!)),
        const SizedBox(height:24),const Text('Price trend · PKR/kg',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        const SizedBox(height:20),SizedBox(height:235,child:LineChart(LineChartData(
          minX:0,maxX:(h.length-1).toDouble(),minY:min-10,maxY:max+10,
          gridData:const FlGridData(show:true),borderData:FlBorderData(show:false),
          titlesData:FlTitlesData(topTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
            rightTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),
            bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:30,interval:3,
              getTitlesWidget:(value,meta){final n=value.toInt();return n>=0&&n<h.length?Text(h[n].date.substring(5),style:const TextStyle(fontSize:10)):const SizedBox.shrink();})),
            leftTitles:const AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:48))),
          lineBarsData:[LineChartBarData(spots:[for(var i=0;i<h.length;i++)FlSpot(i.toDouble(),h[i].price)],
            isCurved:true,barWidth:3,color:Colors.green,dotData:const FlDotData(show:false),belowBarData:BarAreaData(show:true,color:Colors.green.withValues(alpha:0.12)))],
        ))),const SizedBox(height:20),
        Wrap(spacing:10,runSpacing:10,children:[_Stat('Minimum',pkr(min)),_Stat('Maximum',pkr(max)),_Stat('Average',pkr(PriceMath.average(h.map((x)=>x.price))!))]),
        const SizedBox(height:24),const Text('Markets ranked by today’s selling price',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
        for(var i=0;i<rankings.length;i++)Card(child:ListTile(leading:CircleAvatar(child:Text('${i+1}')),
          title:Text(rankings[i].market.name),subtitle:Text('${rankings[i].market.district}${i==0?' · Best selling price':''}'),
          trailing:Text(pkr(rankings[i].price.price),style:const TextStyle(fontWeight:FontWeight.bold)))),
        const Text('Ranking considers price only, not transport costs or availability.',style:TextStyle(color:Colors.black54,fontSize:12)),
      ]));
  }
}
class _Stat extends StatelessWidget {
  final String label,value;
  const _Stat(this.label,this.value);
  @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:Colors.black54)),Text(value,style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold))])));
}
