import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('master catalog RPC contract exposes and preserves autoApply', () {
    final sql = File(
      'supabase/migrations/20260920_product_option_auto_apply_master_contract.sql',
    ).readAsStringSync();

    expect(sql, contains("'autoApply', x.auto_apply"));
    expect(sql, contains("'autoApply')::boolean"));
    expect(sql, contains('auto_apply'));
  });
}
