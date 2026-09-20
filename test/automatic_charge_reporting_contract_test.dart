import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/20260920_automatic_charge_reporting_contract.sql',
  ).readAsStringSync();

  test('reporting contract persists automatic option flag', () {
    expect(migration, contains('add column if not exists automatic boolean'));
    expect(migration, contains("'automatic', coalesce(tio.automatic, false)"));
    expect(migration, contains('get_kiosk_transactions_for_restore'));
  });

  test('automatic option defaults to false for existing transactions', () {
    expect(migration, contains('not null default false'));
  });
}
