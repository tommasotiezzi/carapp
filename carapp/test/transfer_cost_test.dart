import 'package:carapp/features/listing/data/transfer_cost.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rules = TransferCostRules();

  test('up to 53 kW: fixed IPT + 30% + fixed fees', () {
    // 150.81 * 1.3 = 196.053 -> + 85.20 = 281.253
    expect(rules.estimateCents(categoryId: 'car', powerKw: 53), 28125);
  });

  test('above 53 kW: IPT per kW on the whole power', () {
    // 3.5119 * 100 = 351.19 * 1.3 = 456.547 -> + 85.20 = 541.747
    expect(rules.estimateCents(categoryId: 'car', powerKw: 100), 54175);
  });

  test('no estimate without power or for motorcycles', () {
    expect(rules.estimateCents(categoryId: 'car', powerKw: null), isNull);
    expect(rules.estimateCents(categoryId: 'car', powerKw: 0), isNull);
    expect(rules.estimateCents(categoryId: 'motorcycle', powerKw: 70), isNull);
  });

  test('app_config overrides only the keys it sets', () {
    final custom = TransferCostRules.fromConfig({'provincial_surcharge_pct': 0});
    // 150.81 + 85.20
    expect(custom.estimateCents(categoryId: 'car', powerKw: 40), 23601);
    expect(custom.fixedFeesCents, rules.fixedFeesCents);
  });
}
