import 'package:flutter/material.dart';
import 'app_store.dart';
import 'calculations.dart';
import 'prices_screen.dart';

class CalculatorScreen extends StatefulWidget {
  final AppStore store;
  const CalculatorScreen({super.key,required this.store});
  @override State<CalculatorScreen> createState()=>_CalculatorScreenState();
}
class _CalculatorScreenState extends State<CalculatorScreen> {
  String? cropId,marketId;
  final qty=TextEditingController(text:'500');
  final cost=TextEditingController(text:'80');
  double shift=0;
  @override void dispose(){qty.dispose();cost.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final store=widget.store;
    if(store.crops.isEmpty||store.markets.isEmpty)return Scaffold(appBar:AppBar(title:const Text('Profit calculator')),body:const Center(child:Text('No API data yet')));
    cropId ??=store.crops.first.id;marketId ??=store.markets.first.id;
    final price=store.latest(cropId!,marketId!)?.price;
    final quantity=double.tryParse(qty.text)??0,costPerUnit=double.tryParse(cost.text)??0;
    final sell=PriceMath.adjustedPrice(price??0,shift);
    final revenue=PriceMath.revenue(quantity,sell),total=PriceMath.totalCost(quantity,costPerUnit);
    final profit=PriceMath.profit(quantity,sell,costPerUnit);
    final margin=PriceMath.margin(quantity,sell,costPerUnit);
    return Scaffold(appBar:AppBar(title:const Text('Profit calculator')),
      body:ListView(padding:const EdgeInsets.all(18),children:[
        const Text('What would you earn?',style:TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
        const Text('Estimated values based on fictional mandi prices.'),const SizedBox(height:16),
        DropdownButtonFormField<String>(initialValue:cropId,decoration:const InputDecoration(labelText:'Crop',border:OutlineInputBorder()),
          items:store.crops.map((c)=>DropdownMenuItem(value:c.id,child:Text(c.name))).toList(),onChanged:(v)=>setState(()=>cropId=v)),
        const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:marketId,decoration:const InputDecoration(labelText:'Market',border:OutlineInputBorder()),
          items:store.markets.map((m)=>DropdownMenuItem(value:m.id,child:Text(m.name))).toList(),onChanged:(v)=>setState(()=>marketId=v)),
        const SizedBox(height:12),TextField(controller:qty,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Quantity (kg)',border:OutlineInputBorder()),keyboardType:const TextInputType.numberWithOptions(decimal:true)),
        const SizedBox(height:12),TextField(controller:cost,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Production cost per kg (PKR)',border:OutlineInputBorder()),keyboardType:const TextInputType.numberWithOptions(decimal:true)),
        const SizedBox(height:16),Text('Market price: ${price==null?'Not available':pkr(price)} /kg'),
        Text('What-if selling-price shift: ${shift>=0?'+':''}${shift.toStringAsFixed(0)}%',style:const TextStyle(fontWeight:FontWeight.bold)),
        Slider(value:shift,min:-20,max:20,divisions:40,label:'${shift.toStringAsFixed(0)}%',onChanged:(v)=>setState(()=>shift=v)),
        Text('Adjusted price: ${pkr(sell)} /kg'),const SizedBox(height:14),
        if(quantity<=0||costPerUnit<0||price==null)const Text('Enter a positive quantity, nonnegative cost, and choose an available price.',style:TextStyle(color:Colors.red)),
        if(quantity>0&&costPerUnit>=0&&price!=null)...[
          _result('Revenue',pkr(revenue)),_result('Production cost',pkr(total)),
          Card(color:profit>=0?Colors.green.shade50:Colors.red.shade50,child:Padding(padding:const EdgeInsets.all(16),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(profit>=0?'Estimated profit':'Estimated loss',style:const TextStyle(fontWeight:FontWeight.bold)),
              Text(pkr(profit),style:const TextStyle(fontSize:27,fontWeight:FontWeight.bold)),
              Text('Margin: ${margin.toStringAsFixed(2)}%'),
            ]))),
        ],const SizedBox(height:10),const Text('Estimates exclude transport and other unentered costs.',style:TextStyle(fontSize:12,color:Colors.black54)),
      ]));
  }
}
Widget _result(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),
    child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(label),Text(value,style:const TextStyle(fontWeight:FontWeight.bold))]));
