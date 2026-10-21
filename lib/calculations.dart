import 'models.dart';

/// All prices and asking prices are in fictional PKR per kilogram.
class PriceMath {
  static double change(double today, double yesterday) => today - yesterday;
  static double? changePercent(double today, double yesterday) => yesterday == 0 ? null : (today - yesterday) / yesterday * 100;
  static double? average(Iterable<double> numbers) {
    final values = numbers.toList();
    if (values.isEmpty) return null;
    return values.reduce((a,b)=>a+b) / values.length;
  }
  static String marketLabel(double asking, double? benchmark) {
    if (benchmark == null || benchmark <= 0) return 'No benchmark';
    if (asking < benchmark * 0.95) return 'Below market';
    if (asking > benchmark * 1.05) return 'Above market';
    return 'At market';
  }
  static bool alertTriggered(PriceAlert alert, double? latest) =>
    alert.active && latest != null && (alert.condition == 'Above' ? latest >= alert.target : latest <= alert.target);
  static double revenue(double quantity,double sellPrice) => quantity * sellPrice;
  static double totalCost(double quantity,double costPerUnit) => quantity * costPerUnit;
  static double profit(double quantity,double sellPrice,double costPerUnit) => revenue(quantity,sellPrice) - totalCost(quantity,costPerUnit);
  static double margin(double quantity,double sellPrice,double costPerUnit) {
    final r = revenue(quantity,sellPrice);
    return r == 0 ? 0 : profit(quantity,sellPrice,costPerUnit) / r * 100;
  }
  static double adjustedPrice(double price,double shiftPercent) => price * (1 + shiftPercent / 100);
}
