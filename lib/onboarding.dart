import 'package:flutter/material.dart';
import 'app_store.dart';
import 'main.dart';

class Onboarding extends StatefulWidget {
  final AppStore store;
  const Onboarding({super.key,required this.store});
  @override State<Onboarding> createState()=>_OnboardingState();
}
class _OnboardingState extends State<Onboarding> {
  final name=TextEditingController(),phone=TextEditingController();
  String district='Hyderabad',role='Farmer';
  final form=GlobalKey<FormState>();
  bool saving=false;
  @override void dispose(){name.dispose();phone.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:470),
    child:ListView(padding:const EdgeInsets.all(24),children:[
      const SizedBox(height:30),const Icon(Icons.agriculture,size:75,color:Color(0xFF177349)),
      const SizedBox(height:12),const Text('Welcome to KisanMandi',textAlign:TextAlign.center,style:TextStyle(fontSize:27,fontWeight:FontWeight.bold)),
      const SizedBox(height:6),const Text('Fictional Sindh mandi prices · Hackathon demo',textAlign:TextAlign.center),
      const SizedBox(height:30),Form(key:form,child:Column(children:[
        TextFormField(controller:name,decoration:const InputDecoration(labelText:'Full name',border:OutlineInputBorder()),
          validator:(v)=>v==null||v.trim().isEmpty?'Enter a name':null),const SizedBox(height:14),
        TextFormField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone number',hintText:'+920000000000 (fictional)',border:OutlineInputBorder()),
          validator:(v)=>RegExp(r'^\+?[0-9]{8,15}$').hasMatch(v??'')?null:'Enter 8–15 digits (fictional demo number)'),const SizedBox(height:14),
        DropdownButtonFormField<String>(initialValue:district,decoration:const InputDecoration(labelText:'District',border:OutlineInputBorder()),
          items:['Hyderabad','Sukkur','Larkana'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>district=v!)),const SizedBox(height:14),
        SegmentedButton<String>(segments:const [ButtonSegment(value:'Farmer',label:Text('Farmer'),icon:Icon(Icons.agriculture)),
          ButtonSegment(value:'Buyer',label:Text('Buyer'),icon:Icon(Icons.shopping_basket))],selected:{role},onSelectionChanged:(values)=>setState(()=>role=values.first)),
        const SizedBox(height:20),FilledButton.icon(onPressed:saving?null:()async{
          if(!form.currentState!.validate())return;
          setState(()=>saving=true);
          await showActionError(context,()=>widget.store.register(name.text.trim(),phone.text.trim(),district,role));
          if(mounted)setState(()=>saving=false);
        },icon:const Icon(Icons.check),label:Text(saving?'Creating demo user...':'Start exploring')),
      ])),const SizedBox(height:20),const Text('Quick demo login',style:TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:8),Wrap(spacing:8,runSpacing:8,children:[
        OutlinedButton(onPressed:()=>showActionError(context,()=>widget.store.demoLogin('u1')),child:const Text('Demo Farmer')),
        OutlinedButton(onPressed:()=>showActionError(context,()=>widget.store.demoLogin('u5')),child:const Text('Demo Buyer'))]),
      const SizedBox(height:16),const Text('All records, names, contacts and prices are fictional. Demo authentication is not secure for real accounts.',style:TextStyle(color:Colors.black54,fontSize:12)),
      if(widget.store.error!=null)...[const SizedBox(height:12),Text(widget.store.error!,style:TextStyle(color:Theme.of(context).colorScheme.error))],
    ])))));
}
