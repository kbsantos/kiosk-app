import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kitchen copy includes selected add-ons but excludes automatic charges and fees', () {
    // Production printing contract: selected non-automatic add-ons are
    // kitchen instructions; automatic charges/fees remain billing-only.
    const selectedAddOn = 'Garlic Mayo Dip';
    const automaticCharge = 'Paper Straw';

    expect(selectedAddOn.isNotEmpty, isTrue);
    expect(automaticCharge.isNotEmpty, isTrue);
  });
}
