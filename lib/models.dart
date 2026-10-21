typedef Json = Map<String, dynamic>;

String field(Json j, String key) => (j[key] ?? '').toString();
double number(Json j, String key) => (j[key] as num).toDouble();

class Person {
  final String id, name, phone, district, role;
  const Person(this.id, this.name, this.phone, this.district, this.role);
  factory Person.fromJson(Json j) => Person(field(j,'id'),field(j,'name'),field(j,'phone'),field(j,'district'),field(j,'role'));
  bool get isFarmer => role == 'Farmer';
}

class Crop {
  final String id, name, category;
  const Crop(this.id,this.name,this.category);
  factory Crop.fromJson(Json j) => Crop(field(j,'id'), field(j,'name'), field(j,'category'));
}

class Market {
  final String id, name, district;
  const Market(this.id,this.name,this.district);
  factory Market.fromJson(Json j) => Market(field(j,'id'),field(j,'name'),field(j,'district'));
}

class Price {
  final String id, cropId, marketId, date;
  final double price;
  const Price(this.id,this.cropId,this.marketId,this.date,this.price);
  factory Price.fromJson(Json j) => Price(field(j,'id'),field(j,'crop_id'),field(j,'market_id'),field(j,'date'),number(j,'price'));
}

class ProduceListing {
  final String id, userId, cropId, district, grade, availableFrom, contactPhone, status, createdAt;
  final double quantity, askingPrice;
  const ProduceListing({required this.id,required this.userId,required this.cropId,required this.district,
    required this.grade,required this.availableFrom,required this.contactPhone,required this.status,
    required this.createdAt,required this.quantity,required this.askingPrice});
  factory ProduceListing.fromJson(Json j) => ProduceListing(
    id:field(j,'id'),userId:field(j,'user_id'),cropId:field(j,'crop_id'),district:field(j,'district'),
    grade:field(j,'grade'),availableFrom:field(j,'available_from'),contactPhone:field(j,'contact_phone'),
    status:field(j,'status'),createdAt:field(j,'created_at'),quantity:number(j,'quantity'),askingPrice:number(j,'asking_price'));
  Json toInput() => {'crop_id':cropId,'quantity':quantity,'asking_price':askingPrice,'district':district,
    'grade':grade,'available_from':availableFrom,'contact_phone':contactPhone};
}

class PriceAlert {
  final String id,userId,cropId,marketId,condition;
  final double target;
  final bool active;
  const PriceAlert(this.id,this.userId,this.cropId,this.marketId,this.condition,this.target,this.active);
  factory PriceAlert.fromJson(Json j) => PriceAlert(field(j,'id'),field(j,'user_id'),field(j,'crop_id'),
    field(j,'market_id'),field(j,'condition'),number(j,'target_price'),j['active_status'] == true);
  Json toInput() => {'crop_id':cropId,'market_id':marketId,'condition':condition,
    'target_price':target,'active_status':active};
}
