import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/pages/kiosk_category_page.dart';

void main() {
  testWidgets(
    'food product with assigned option opens options modal and saves selection',
    (tester) async {
      final cart = KioskCart();
      final product = KioskProduct(
        id: 'cheeseburger',
        name: 'Cheeseburger',
        price: 120,
        category: KioskCategory.burgers,
        productType: 'food',
        options: const [
          KioskCatalogOption(
            id: 'takeout',
            name: 'Takeout',
            price: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => addKioskProductToCart(context, product, cart),
                child: const Text('ADD'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      // expect(find.text('ADD-ONS'), findsOneWidget);
      expect(find.text('Choose any add-ons for Cheeseburger'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'ADD-ONS'));
      await tester.pumpAndSettle();
      expect(find.text('Takeout'), findsOneWidget);

      await tester.tap(find.text('Takeout'));
      await tester.tap(find.text('ADD TO ORDER'));
      await tester.pumpAndSettle();

      expect(cart.items, hasLength(1));
      expect(cart.items.single.options, hasLength(1));
      expect(cart.items.single.options.single.name, 'Takeout');
    },
  );
}
