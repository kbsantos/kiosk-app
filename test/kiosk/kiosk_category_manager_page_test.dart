import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bigger_brew_kiosk/features/kiosk/staff/kiosk_category_manager_page.dart';

void main() {
  testWidgets(
    'K15.3.2 category manager renders',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: KioskCategoryManagerPage(),
        ),
      );

      // Only render the first frame.
      //
      // Category Manager performs asynchronous catalog loading during
      // initState. We intentionally do not use pumpAndSettle() here
      // because the page can contain ongoing framework work/animations.
      await tester.pump();

      expect(
        find.text('CATEGORY MANAGER'),
        findsOneWidget,
      );
    },
  );
}
