import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_store.dart';
import 'calculations.dart';
import 'main.dart';
import 'models.dart';
import 'prices_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  final AppStore store;
  const MarketplaceScreen({super.key,required this.store});
  @override State<MarketplaceScreen> createState()=>_MarketplaceScreenState();
}
class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String query='',cropId='all',district='all',grade='all',sort='newest';
  @override Widget build(BuildContext context){
    final store=widget.store;
    final filtered=store.listings.where((l)=>l.status=='Active'&&(cropId=='all'||l.cropId==cropId)
      &&(district=='all'||l.district==district)&&(grade=='all'||l.grade==grade)
      &&(store.crop(l.cropId)?.name.toLowerCase().contains(query.toLowerCase())??false)).toList();
    filtered.sort((a,b)=>sort=='price'?a.askingPrice.compareTo(b.askingPrice):b.createdAt.compareTo(a.createdAt));
    return RefreshIndicator(onRefresh:store.refresh,child:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[const Expanded(child:Text('Farm-gate marketplace',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold))),
        if(store.user?.isFarmer==true)FilledButton.icon(onPressed:()=>showListingEditor(context,store),icon:const Icon(Icons.add),label:const Text('List produce'))]),
      const Text('Prices and phone numbers are fictional demo records.',style:TextStyle(color:Colors.black54)),
      const SizedBox(height:12),TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(labelText:'Search crop',prefixIcon:Icon(Icons.search),border:OutlineInputBorder())),
      const SizedBox(height:12),Wrap(spacing:10,runSpacing:6,children:[
        _select('Crop',cropId,[('all','All crops'),...store.crops.map((c)=>(c.id,c.name))],(v)=>setState(()=>cropId=v)),
        _select('District',district,[('all','All districts'),...store.markets.map((m)=>(m.district,m.district))],(v)=>setState(()=>district=v)),
        _select('Grade',grade,[('all','All grades'),('A','A'),('B','B'),('C','C')],(v)=>setState(()=>grade=v)),
        _select('Sort',sort,[('newest','Newest'),('price','Lowest price')],(v)=>setState(()=>sort=v)),
      ]),const SizedBox(height:8),
      if(filtered.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(22),child:Text('No active listings match these filters.'))),
      for(final listing in filtered)ListingCard(store:store,listing:listing),
    ]));
  }
}
Widget _select(String label,String value,List<(String,String)> choices,ValueChanged<String> onChange)=>
  SizedBox(width:155,child:DropdownButtonFormField<String>(initialValue:value,isExpanded:true,
    decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),isDense:true),
    items:choices.toSet().map((o)=>DropdownMenuItem(value:o.$1,child:Text(o.$2,overflow:TextOverflow.ellipsis))).toList(),
    onChanged:(v){if(v!=null)onChange(v);}));

class ListingCard extends StatelessWidget {
  final AppStore store;final ProduceListing listing;
  const ListingCard({super.key,required this.store,required this.listing});
  @override Widget build(BuildContext context){
    final label=PriceMath.marketLabel(listing.askingPrice,store.marketAverage(listing.cropId));
    return Card(child:ListTile(
      title:Text(store.crop(listing.cropId)?.name??'Crop',style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:Text('${listing.quantity.toStringAsFixed(0)} kg · Grade ${listing.grade} · ${listing.district}\n$label · Available ${listing.availableFrom}'),
      isThreeLine:true,trailing:Text('${pkr(listing.askingPrice)}\n/kg',textAlign:TextAlign.end,
        style:const TextStyle(fontWeight:FontWeight.w600)),
      onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ListingDetails(store:store,listing:listing))),
    ));
  }
}

class ListingDetails extends StatelessWidget {
  final AppStore store;final ProduceListing listing;
  const ListingDetails({super.key,required this.store,required this.listing});
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Produce listing')),
    body:ListView(padding:const EdgeInsets.all(20),children:[
      Text(store.crop(listing.cropId)?.name??'Crop',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:26)),
      Text('${pkr(listing.askingPrice)} /kg',style:TextStyle(fontSize:22,color:Theme.of(context).colorScheme.primary)),
      const SizedBox(height:14),_detail('Quantity','${listing.quantity.toStringAsFixed(0)} kg'),
      _detail('Grade',listing.grade),_detail('District',listing.district),
      _detail('Available from',listing.availableFrom),_detail('Status',listing.status),
      _detail('Market comparison',PriceMath.marketLabel(listing.askingPrice,store.marketAverage(listing.cropId))),
      _detail('Farmer',store.owner(listing.userId)?.name??'Demo farmer'),
      _detail('Contact',listing.contactPhone),
      const SizedBox(height:10),const Text('Fictional contact: these links illustrate call and WhatsApp actions. No actual seller exists.',style:TextStyle(color:Colors.black54)),
      const SizedBox(height:16),Row(children:[Expanded(child:FilledButton.icon(onPressed:()=>showActionError(context,() async {
        if(!await launchUrl(Uri(scheme:'tel',path:listing.contactPhone)))throw Exception('No phone dialer available');
      }),icon:const Icon(Icons.call),label:const Text('Call'))),const SizedBox(width:8),
        Expanded(child:OutlinedButton.icon(onPressed:()=>showActionError(context,() async {
          final digits=listing.contactPhone.replaceAll(RegExp(r'\D'),'');
          if(!await launchUrl(Uri.parse('https://wa.me/$digits'),mode:LaunchMode.externalApplication))throw Exception('Cannot open WhatsApp');
        }),icon:const Icon(Icons.message),label:const Text('WhatsApp')))]),
    ]));
}
Widget _detail(String name,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),
    child:Row(children:[SizedBox(width:145,child:Text(name,style:const TextStyle(color:Colors.black54))),Expanded(child:Text(value,style:const TextStyle(fontWeight:FontWeight.w600)))]));

class MyListingsScreen extends StatefulWidget {
  final AppStore store;
  const MyListingsScreen({super.key,required this.store});
  @override State<MyListingsScreen> createState()=>_MyListingsScreenState();
}
class _MyListingsScreenState extends State<MyListingsScreen> {
  late Future<List<ProduceListing>> future;
  @override void initState(){super.initState();load();}
  void load(){future=widget.store.api.list('/api/listings?mine=true',ProduceListing.fromJson);}
  Future<void> reload()async{setState(load);await future;}
  @override Widget build(BuildContext context)=>RefreshIndicator(onRefresh:reload,child:FutureBuilder<List<ProduceListing>>(
    future:future,builder:(context,snapshot){
      if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());
      if(snapshot.hasError)return ListView(children:[Text('Could not load My Listings: ${snapshot.error}'),TextButton(onPressed:()=>setState(load),child:const Text('Retry'))]);
      final items=snapshot.data??[];
      return ListView(padding:const EdgeInsets.all(16),children:[
        Row(children:[const Expanded(child:Text('My Listings',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold))),
          FilledButton.icon(onPressed:()async{await showListingEditor(context,widget.store);if(mounted)setState(load);},icon:const Icon(Icons.add),label:const Text('New'))]),
        if(items.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('You have no listings.'))),
        for(final item in items)Card(child:Column(children:[ListingCard(store:widget.store,listing:item),
          Padding(padding:const EdgeInsets.fromLTRB(12,0,12,8),child:Row(children:[
            Chip(label:Text(item.status)),const Spacer(),
            if(item.status=='Active')TextButton(onPressed:()async{await showListingEditor(context,widget.store,existing:item);if(mounted)setState(load);},child:const Text('Edit')),
            if(item.status=='Active')TextButton(onPressed:()=>showActionError(context,() async {await widget.store.setSold(item.id);if(context.mounted)setState(load);}),child:const Text('Mark Sold')),
            IconButton(tooltip:'Delete',icon:const Icon(Icons.delete_outline),onPressed:()async{
              final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete listing?'),
                content:const Text('This cannot be undone.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
                  FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
              if(confirmed==true && context.mounted){await showActionError(context,()=>widget.store.deleteListing(item.id));if(mounted)setState(load);}
            })]))]))
      ]);
    }));
}

Future<void> showListingEditor(BuildContext context,AppStore store,{ProduceListing? existing}) async {
  if(store.crops.isEmpty)return;
  String cropId=existing?.cropId??store.crops.first.id;
  String district=existing?.district??store.user?.district??'Hyderabad';
  String grade=existing?.grade??'A';
  DateTime available=existing==null?DateTime.now():DateTime.tryParse(existing.availableFrom)??DateTime.now();
  final qty=TextEditingController(text:existing?.quantity.toStringAsFixed(0)??'');
  final price=TextEditingController(text:existing?.askingPrice.toStringAsFixed(2)??'');
  final phone=TextEditingController(text:existing?.contactPhone??store.user?.phone??'');
  final form=GlobalKey<FormState>();
  await showDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:Text(existing==null?'List your produce':'Edit listing'),
    content:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(initialValue:cropId,decoration:const InputDecoration(labelText:'Crop'),
        items:store.crops.map((x)=>DropdownMenuItem(value:x.id,child:Text(x.name))).toList(),onChanged:(v)=>update(()=>cropId=v!)),
      TextFormField(controller:qty,decoration:const InputDecoration(labelText:'Quantity (kg)'),keyboardType:const TextInputType.numberWithOptions(decimal:true),
        validator:(v)=>(double.tryParse(v??'')??0)>0?null:'Enter a positive quantity'),
      TextFormField(controller:price,decoration:const InputDecoration(labelText:'Asking price (PKR/kg)'),keyboardType:const TextInputType.numberWithOptions(decimal:true),
        validator:(v)=>(double.tryParse(v??'')??0)>0?null:'Enter a positive price'),
      DropdownButtonFormField<String>(initialValue:district,decoration:const InputDecoration(labelText:'District'),
        items:store.markets.map((m)=>m.district).toSet().map((d)=>DropdownMenuItem(value:d,child:Text(d))).toList(),onChanged:(v)=>update(()=>district=v!)),
      DropdownButtonFormField<String>(initialValue:grade,decoration:const InputDecoration(labelText:'Grade'),
        items:['A','B','C'].map((g)=>DropdownMenuItem(value:g,child:Text('Grade $g'))).toList(),onChanged:(v)=>update(()=>grade=v!)),
      ListTile(contentPadding:EdgeInsets.zero,title:const Text('Available from'),subtitle:Text(available.toIso8601String().substring(0,10)),
        trailing:const Icon(Icons.calendar_today),onTap:()async{
          final now=DateTime.now();final today=DateTime(now.year,now.month,now.day);
          final date=await showDatePicker(context:ctx,initialDate:available.isBefore(today)?today:available,firstDate:today,lastDate:today.add(const Duration(days:365)));
          if(date!=null)update(()=>available=date);
        }),
      TextFormField(controller:phone,decoration:const InputDecoration(labelText:'Contact phone (fictional)'),keyboardType:TextInputType.phone,
        validator:(v)=>RegExp(r'^\+?[0-9]{8,15}$').hasMatch(v??'')?null:'Enter a fictional 8–15 digit contact'),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
      FilledButton(onPressed:()async{
        if(!form.currentState!.validate())return;
        final input=<String,dynamic>{'crop_id':cropId,'quantity':double.parse(qty.text),'asking_price':double.parse(price.text),
          'district':district,'grade':grade,'available_from':available.toIso8601String().substring(0,10),'contact_phone':phone.text.trim()};
        await showActionError(ctx,()async{await store.saveListing(input,id:existing?.id);if(ctx.mounted)Navigator.pop(ctx);});
      },child:const Text('Save'))]
  )));
  qty.dispose();price.dispose();phone.dispose();
}
