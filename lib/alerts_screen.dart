import 'package:flutter/material.dart';
import 'app_store.dart';
import 'calculations.dart';
import 'main.dart';
import 'models.dart';
import 'prices_screen.dart';

class AlertsScreen extends StatelessWidget {
  final AppStore store;
  const AlertsScreen({super.key,required this.store});
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:store.refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
    Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Price alerts',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      Text('${store.triggeredCount} active alerts triggered · fictional prices')
    ])),FilledButton.icon(onPressed:()=>showAlertEditor(context,store),icon:const Icon(Icons.add),label:const Text('Create'))]),
    const SizedBox(height:12),
    if(store.alerts.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(28),child:Text('No alerts yet. Create one to watch prices.'))),
    for(final alert in store.alerts)Card(child:ListTile(
      title:Text('${store.crop(alert.cropId)?.name??'Unknown'} · ${store.market(alert.marketId)?.name??'Unknown'}',style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text('${alert.condition} ${pkr(alert.target)} /kg · ${PriceMath.alertTriggered(alert,store.latest(alert.cropId,alert.marketId)?.price)?'TRIGGERED':'Not triggered'}'),
      leading:Switch(value:alert.active,onChanged:(v)=>showActionError(context,()=>store.saveAlert({...alert.toInput(),'active_status':v},id:alert.id))),
      trailing:PopupMenuButton<String>(tooltip:'Manage alert',onSelected:(v){
        if(v=='edit')showAlertEditor(context,store,existing:alert);
        if(v=='delete')showActionError(context,()=>store.deleteAlert(alert.id));
      },itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'delete',child:Text('Delete'))]),
    )),
  ]));
}

Future<void> showAlertEditor(BuildContext context,AppStore store,{PriceAlert? existing}) async {
  if(store.crops.isEmpty||store.markets.isEmpty)return;
  String cropId=existing?.cropId??store.crops.first.id;
  String marketId=existing?.marketId??store.markets.first.id;
  String condition=existing?.condition??'Above';bool active=existing?.active??true;
  final amount=TextEditingController(text:existing?.target.toStringAsFixed(2)??'');
  final form=GlobalKey<FormState>();
  await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setModal)=>AlertDialog(
    title:Text(existing==null?'New price alert':'Edit price alert'),content:SingleChildScrollView(child:Form(key:form,
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(initialValue:cropId,decoration:const InputDecoration(labelText:'Crop'),
          items:store.crops.map((c)=>DropdownMenuItem(value:c.id,child:Text(c.name))).toList(),onChanged:(v)=>setModal(()=>cropId=v!)),
        DropdownButtonFormField<String>(initialValue:marketId,decoration:const InputDecoration(labelText:'Market'),
          items:store.markets.map((m)=>DropdownMenuItem(value:m.id,child:Text(m.name))).toList(),onChanged:(v)=>setModal(()=>marketId=v!)),
        DropdownButtonFormField<String>(initialValue:condition,decoration:const InputDecoration(labelText:'Condition'),
          items:['Above','Below'].map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v)=>setModal(()=>condition=v!)),
        TextFormField(controller:amount,decoration:const InputDecoration(labelText:'Target PKR/kg'),keyboardType:const TextInputType.numberWithOptions(decimal:true),
          validator:(v)=>(double.tryParse(v??'')??0)>0?null:'Enter positive target'),
        SwitchListTile(title:const Text('Active'),value:active,onChanged:(v)=>setModal(()=>active=v)),
      ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
      FilledButton(onPressed:()async{if(!form.currentState!.validate())return;
        await showActionError(ctx,()async{await store.saveAlert({'crop_id':cropId,'market_id':marketId,'condition':condition,
          'target_price':double.parse(amount.text),'active_status':active},id:existing?.id);
          if(ctx.mounted)Navigator.pop(ctx);});
      },child:const Text('Save'))]
  )));
  amount.dispose();
}
