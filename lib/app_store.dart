import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'calculations.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  final ApiClient api;
  AppStore({ApiClient? api}) : api = api ?? ApiClient();
  Person? user;
  List<Person> users=[];
  List<Crop> crops=[];
  List<Market> markets=[];
  List<Price> prices=[];
  List<PriceAlert> alerts=[];
  List<ProduceListing> listings=[];
  String? error;
  bool loading = true;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      api.token = prefs.getString('demo_token');
      if (api.token != null) {
        try { user = Person.fromJson(Map<String,dynamic>.from(await api.request('GET','/api/session') as Map)); }
        catch (_) { api.token=null; await prefs.remove('demo_token'); }
      }
      await refresh();
    } catch(e) { error = e.toString(); loading=false; notifyListeners(); }
  }
  Future<void> refresh() async {
    loading=true;error=null;notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        api.list('/api/users',Person.fromJson), api.list('/api/crops',Crop.fromJson),
        api.list('/api/markets',Market.fromJson), api.list('/api/prices',Price.fromJson),
        api.list('/api/listings?active=true',ProduceListing.fromJson),
        if (user?.isFarmer == true) api.list('/api/alerts',PriceAlert.fromJson),
      ]);
      users=List<Person>.from(results[0] as List);crops=List<Crop>.from(results[1] as List);
      markets=List<Market>.from(results[2] as List);prices=List<Price>.from(results[3] as List);
      listings=List<ProduceListing>.from(results[4] as List);
      alerts=user?.isFarmer == true ? List<PriceAlert>.from(results[5] as List) : [];
    } catch(e) { error=e.toString(); }
    loading=false;notifyListeners();
  }
  Future<void> register(String name,String phone,String district,String role) async {
    final response = Map<String,dynamic>.from(await api.request('POST','/api/users',
      {'name':name,'phone':phone,'district':district,'role':role}) as Map);
    await _setUser(response);
  }
  Future<void> demoLogin(String id) async {
    final response = Map<String,dynamic>.from(await api.request('POST','/api/demo-login',{'user_id':id}) as Map);
    await _setUser(response);
  }
  Future<void> _setUser(Json response) async {
    api.token=response['token'] as String;
    user=Person.fromJson(Map<String,dynamic>.from(response['user'] as Map));
    final prefs=await SharedPreferences.getInstance(); await prefs.setString('demo_token',api.token!);
    await refresh();
  }
  Future<void> logout() async {
    api.token=null;user=null;alerts=[];
    final prefs=await SharedPreferences.getInstance();await prefs.remove('demo_token');notifyListeners();
  }
  Future<void> saveListing(Json input,{String? id}) async {
    await api.request(id==null?'POST':'PATCH',id==null?'/api/listings':'/api/listings/$id',input);
    await refresh();
  }
  Future<void> setSold(String id) async { await api.request('PATCH','/api/listings/$id',{'status':'Sold'});await refresh(); }
  Future<void> deleteListing(String id) async { await api.request('DELETE','/api/listings/$id');await refresh(); }
  Future<void> saveAlert(Json input,{String? id}) async {
    await api.request(id==null?'POST':'PATCH',id==null?'/api/alerts':'/api/alerts/$id',input);await refresh();
  }
  Future<void> deleteAlert(String id) async { await api.request('DELETE','/api/alerts/$id');await refresh(); }
  Crop? crop(String id) {for(final x in crops){if(x.id==id)return x;}return null;}
  Market? market(String id) {for(final x in markets){if(x.id==id)return x;}return null;}
  Person? owner(String id) {for(final x in users){if(x.id==id)return x;}return null;}
  List<Price> history(String cropId,String marketId) => prices.where((p)=>p.cropId==cropId&&p.marketId==marketId).toList()..sort((a,b)=>a.date.compareTo(b.date));
  Price? latest(String cropId,String marketId) {final list=history(cropId,marketId);return list.isEmpty?null:list.last;}
  List<({Market market,Price price})> ranking(String cropId) {
    final values=<({Market market,Price price})>[];
    for(final m in markets) {final p=latest(cropId,m.id);if(p!=null)values.add((market:m,price:p));}
    values.sort((a,b)=>b.price.price.compareTo(a.price.price));return values;
  }
  double? marketAverage(String cropId) => PriceMath.average(ranking(cropId).map((x)=>x.price.price));
  int get triggeredCount => alerts.where((alert)=>PriceMath.alertTriggered(alert,latest(alert.cropId,alert.marketId)?.price)).length;
}
