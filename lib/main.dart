import 'package:flutter/material.dart';
import 'app_store.dart';
import 'onboarding.dart';
import 'prices_screen.dart';
import 'marketplace_screen.dart';
import 'alerts_screen.dart';
import 'calculator_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KisanMandiApp());
}

class KisanMandiApp extends StatefulWidget {
  const KisanMandiApp({super.key});
  @override State<KisanMandiApp> createState()=>_KisanMandiAppState();
}
class _KisanMandiAppState extends State<KisanMandiApp> {
  final AppStore store=AppStore();
  int selected=0;
  @override void initState(){super.initState();store.initialize();}
  @override void dispose(){store.dispose();super.dispose();}
  @override Widget build(BuildContext context) => MaterialApp(
    title:'KisanMandi',debugShowCheckedModeBanner:false,
    theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF177349)),
      scaffoldBackgroundColor:const Color(0xFFF5F8F3),appBarTheme:const AppBarTheme(backgroundColor:Color(0xFFF5F8F3))),
    home:AnimatedBuilder(animation:store,builder:(context,_) {
      if(store.loading && store.user==null)return const Scaffold(body:Center(child:CircularProgressIndicator()));
      if(store.user==null)return Onboarding(store:store);
      final farmer=store.user!.isFarmer;
      final labels=farmer?['Prices','Marketplace','Alerts','My Listings']:['Prices','Marketplace'];
      final icons=farmer?[Icons.trending_up,Icons.storefront,Icons.notifications,Icons.inventory_2]:[Icons.trending_up,Icons.storefront];
      final index=selected.clamp(0,labels.length-1);
      final pages=<Widget>[PricesScreen(store:store),MarketplaceScreen(store:store),if(farmer)AlertsScreen(store:store),if(farmer)MyListingsScreen(store:store)];
      return Scaffold(
        appBar:AppBar(title:const Text('🌾 KisanMandi',style:TextStyle(fontWeight:FontWeight.w800)),
          actions:[if(farmer)IconButton(tooltip:'Profit calculator',icon:const Icon(Icons.calculate_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CalculatorScreen(store:store)))),
            PopupMenuButton<String>(tooltip:'Account',onSelected:(v)async{if(v=='logout'){await store.logout();setState(()=>selected=0);}else{await store.demoLogin(v);setState(()=>selected=0);}},
              itemBuilder:(_)=>[const PopupMenuItem(enabled:false,child:Text('Switch fictional demo persona')),
                ...store.users.map((u)=>PopupMenuItem(value:u.id,child:Text('${u.name} (${u.role})'))),
                const PopupMenuDivider(),const PopupMenuItem(value:'logout',child:Text('Sign out'))])]),
        body:Column(children:[if(store.error!=null)MaterialBanner(content:Text(store.error!),actions:[TextButton(onPressed:store.refresh,child:const Text('Retry'))]),
          Expanded(child:pages[index])]),
        bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>selected=i),
          destinations:List.generate(labels.length,(i)=>NavigationDestination(icon:Badge(isLabelVisible:farmer&&i==2&&store.triggeredCount>0,
            label:Text('${store.triggeredCount}'),child:Icon(icons[i])),label:labels[i]))),
      );
    }),
  );
}

Future<void> showActionError(BuildContext context,Future<void> Function() action) async {
  try {await action();}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
}
