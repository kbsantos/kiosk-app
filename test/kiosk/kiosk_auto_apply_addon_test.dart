import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/pages/kiosk_category_page.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';

void main() {
  test('product option autoApply survives catalog JSON round trip', () {
    const option = ProductOption(
      optionId: 'paper_straw',
      name: 'Paper Straw',
      price: 2,
      active: true,
      autoApply: true,
    );

    final restored = ProductOption.fromJson(option.toJson());

    expect(restored.autoApply, isTrue);
    expect(restored.toJson()['autoApply'], isTrue);
  });

  testWidgets('auto-apply option is preselected and remains removable',
      (tester) async {
    final cart = KioskCart();
    const product = KioskProduct(
      id: 'iced_latte',
      name: 'Iced Latte',
      price: 120,
      category: KioskCategory.coffee,
      options: [
        KioskCatalogOption(
          id: 'paper_straw',
          name: 'Paper Straw',
          price: 2,
          autoApply: true,
        ),
        KioskCatalogOption(
          id: 'extra_shot',
          name: 'Extra Shot',
          price: 50,
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'ADD-ONS'));
    await tester.pumpAndSettle();

    final strawTile = find.widgetWithText(CheckboxListTile, 'Paper Straw');
    expect(strawTile, findsOneWidget);
    final strawCheckbox = tester.widget<CheckboxListTile>(strawTile);
    expect(strawCheckbox.value, isTrue);

    await tester.tap(find.text('Paper Straw'));
    await tester.tap(find.text('ADD TO ORDER'));
    await tester.pumpAndSettle();

    expect(cart.items, hasLength(1));
    expect(cart.items.single.options, isEmpty);
  });

  testWidgets('only auto-apply options are added without opening add-on sheet',
      (tester) async {
    final cart = KioskCart();
    const product = KioskProduct(
      id: 'iced_latte',
      name: 'Iced Latte',
      price: 120,
      category: KioskCategory.coffee,
      options: [
        KioskCatalogOption(
          id: 'paper_straw',
          name: 'Paper Straw',
          price: 2,
          autoApply: true,
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

    expect(find.text('ADD-ONS'), findsNothing);
    expect(cart.items, hasLength(1));
    expect(cart.items.single.options, hasLength(1));
    expect(cart.items.single.options.single.name, 'Paper Straw');
    expect(cart.items.single.unitPrice, 122);
  });
}
