import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bigger_brew_kiosk/features/kiosk/staff/kiosk_catalog_manager_page.dart';

void main() {
  testWidgets('K15.3 catalog manager shell renders', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(
        home: KioskCatalogManagerPage(),
      ),
    );

    // Allow the initial async catalog load to complete.
    await tester.pump();

    // The dashboard intentionally contains the section title and
    // AppBar title with the same text.
    expect(
      find.text('CATALOG MANAGEMENT'),
      findsNWidgets(2),
    );

    expect(
      find.text('Catalog Management Hub'),
      findsOneWidget,
    );

    expect(
      find.text('Categories'),
      findsOneWidget,
    );

    expect(
      find.text('Products'),
      findsOneWidget,
    );

    expect(
      find.text('Options / Add-ons'),
      findsOneWidget,
    );
  });
}
