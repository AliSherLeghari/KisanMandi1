import 'package:flutter_test/flutter_test.dart';
import 'package:kisanmandi/calculations.dart';
import 'package:kisanmandi/models.dart';

void main() {
  test('day-over-day absolute and percentage changes', () {
    expect(PriceMath.change(110,100),10);
    expect(PriceMath.changePercent(110,100),10);
    expect(PriceMath.changePercent(100,0),isNull);
    expect(PriceMath.changePercent(90,100),-10);
  });
  test('14-day average and empty history are safe', () {
    expect(PriceMath.average(List.generate(14,(i)=>i+1.0)),7.5);
    expect(PriceMath.average([]),isNull);
  });
  test('market price classification handles inclusive 5 percent boundaries', () {
    expect(PriceMath.marketLabel(94.99,100),'Below market');
    expect(PriceMath.marketLabel(95,100),'At market');
    expect(PriceMath.marketLabel(105,100),'At market');
    expect(PriceMath.marketLabel(105.01,100),'Above market');
    expect(PriceMath.marketLabel(90,null),'No benchmark');
  });
  test('alert triggers inclusive exact thresholds and ignores inactive alerts', () {
    const above=PriceAlert('a1','u1','c1','m1','Above',100,true);
    const below=PriceAlert('a2','u1','c1','m1','Below',100,true);
    const off=PriceAlert('a3','u1','c1','m1','Above',100,false);
    expect(PriceMath.alertTriggered(above,100),true);
    expect(PriceMath.alertTriggered(below,100),true);
    expect(PriceMath.alertTriggered(above,99),false);
    expect(PriceMath.alertTriggered(below,101),false);
    expect(PriceMath.alertTriggered(off,110),false);
    expect(PriceMath.alertTriggered(above,null),false);
  });
  test('profit calculator correct for gains, losses, margins, what-if', () {
    expect(PriceMath.revenue(100,150),15000);
    expect(PriceMath.totalCost(100,120),12000);
    expect(PriceMath.profit(100,150,120),3000);
    expect(PriceMath.margin(100,150,120),20);
    expect(PriceMath.profit(100,100,120),-2000);
    expect(PriceMath.margin(0,0,0),0);
    expect(PriceMath.adjustedPrice(100,-20),80);
    expect(PriceMath.adjustedPrice(100,20),120);
  });
}
