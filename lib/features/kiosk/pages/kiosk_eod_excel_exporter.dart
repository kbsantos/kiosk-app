import 'package:excel/excel.dart';
import '../currency/kiosk_currency.dart';

import '../orders/kiosk_order.dart';
import '../models/kiosk_models.dart';

class KioskEodExcelExporter {
  static Future<bool> export({
    required DateTime date,
    required List<KioskOrder> orders,
  }) async {
    final workbook = Excel.createExcel();

    final summary = workbook['End of Day Summary'];
    final ordersSheet = workbook['Orders'];
    final itemsSheet = workbook['Items'];
    final drinkSummarySheet = workbook['Drink Summary'];
    final mealSummarySheet = workbook['Meal Summary'];
    final accessoriesSummarySheet = workbook['Accessories Daily Summary'];

    workbook.delete('Sheet1');
    workbook.setDefaultSheet('End of Day Summary');

    final completed = orders
        .where((order) => order.status == KioskOrderStatus.completed)
        .toList(growable: false);
    final refunded = orders
        .where((order) =>
            order.status == KioskOrderStatus.cancelled &&
            order.paymentStatus == 'refunded')
        .toList(growable: false);
    final pendingPayment = completed
        .where((order) => order.paymentStatus != 'paid')
        .toList(growable: false);

    final itemCount = completed.fold<int>(
      0,
      (sum, order) =>
          sum +
          order.items.fold<int>(
            0,
            (itemSum, item) => itemSum + item.quantity,
          ),
    );
    final sales = completed.fold<int>(0, (sum, order) => sum + order.total);
    final pending =
        pendingPayment.fold<int>(0, (sum, order) => sum + order.total);
    final refunds = refunded.fold<int>(0, (sum, order) => sum + order.total);

    summary.appendRow([TextCellValue('BIGGER BREW END-OF-DAY SUMMARY')]);
    summary.appendRow([
      TextCellValue('Date'),
      DateCellValue(
        year: date.year,
        month: date.month,
        day: date.day,
      )
    ]);
    summary.appendRow(
        [TextCellValue('Completed Orders'), IntCellValue(completed.length)]);
    summary.appendRow([TextCellValue('Items Sold'), IntCellValue(itemCount)]);
    summary.appendRow(
        [TextCellValue('Completed Sales (${KioskCurrency.code})'), IntCellValue(sales)]);
    summary.appendRow(
        [TextCellValue('Payment Still Pending (${KioskCurrency.code})'), IntCellValue(pending)]);
    summary.appendRow([TextCellValue('Refunds (${KioskCurrency.code})'), IntCellValue(refunds)]);
    summary.appendRow([]);
    summary.appendRow([TextCellValue('PAYMENT BREAKDOWN')]);
    summary.appendRow([
      TextCellValue('Payment Mode'),
      TextCellValue('Completed Orders'),
      TextCellValue('Completed Sales (${KioskCurrency.code})'),
      TextCellValue('Pending Payment (${KioskCurrency.code})'),
    ]);

    for (final method in _paymentMethods(orders)) {
      final methodCompleted = completed
          .where((order) => order.paymentMethod == method)
          .toList(growable: false);
      final methodPending = methodCompleted
          .where((order) => order.paymentStatus != 'paid')
          .fold<int>(0, (sum, order) => sum + order.total);
      final methodSales =
          methodCompleted.fold<int>(0, (sum, order) => sum + order.total);

      summary.appendRow([
        TextCellValue(method),
        IntCellValue(methodCompleted.length),
        IntCellValue(methodSales),
        IntCellValue(methodPending),
      ]);
    }

    ordersSheet.appendRow([
      TextCellValue('Order #'),
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Order Type'),
      TextCellValue('Payment Mode'),
      TextCellValue('Payment Status'),
      TextCellValue('Order Mode'),
      TextCellValue('Order Status'),
      TextCellValue('Total (${KioskCurrency.code})'),
      TextCellValue('Cancellation Reason'),
    ]);

    for (final order in orders) {
      ordersSheet.appendRow([
        TextCellValue(order.orderNumber),
        DateCellValue(
          year: order.createdAt.year,
          month: order.createdAt.month,
          day: order.createdAt.day,
        ),
        TextCellValue(_timeLabel(order.createdAt)),
        TextCellValue(order.orderType),
        TextCellValue(order.paymentMethod),
        TextCellValue(order.paymentStatus.toUpperCase()),
        TextCellValue(order.orderMode),
        TextCellValue(order.status.name.toUpperCase()),
        IntCellValue(order.total),
        TextCellValue(order.cancellationReason ?? ''),
      ]);
    }

    itemsSheet.appendRow([
      TextCellValue('Order #'),
      TextCellValue('Product'),
      TextCellValue('Category'),
      TextCellValue('Size'),
      TextCellValue('Variant'),
      TextCellValue('Options'),
      TextCellValue('Quantity'),
      TextCellValue('Unit Price (${KioskCurrency.code})'),
      TextCellValue('Subtotal (${KioskCurrency.code})'),
      TextCellValue('Order Status'),
      TextCellValue('Payment Mode'),
    ]);

    for (final order in orders) {
      for (final item in order.items) {
        itemsSheet.appendRow([
          TextCellValue(order.orderNumber),
          TextCellValue(item.product.name),
          TextCellValue(_categoryLabel(item.product.category)),
          TextCellValue(item.size == null
              ? ''
              : '${item.size!.name}${item.size!.displayVolume == null ? '' : ' (${item.size!.displayVolume})'}'),
          TextCellValue(item.variant?.name ?? ''),
          TextCellValue(item.options.map((option) => option.name).join(', ')),
          IntCellValue(item.quantity),
          IntCellValue(item.unitPrice),
          IntCellValue(item.total),
          TextCellValue(order.status.name.toUpperCase()),
          TextCellValue(order.paymentMethod),
        ]);
      }
    }

    _buildDrinkSummary(
      sheet: drinkSummarySheet,
      completedOrders: completed,
    );
    _buildMealSummary(
      sheet: mealSummarySheet,
      completedOrders: completed,
    );
    _buildAccessoriesSummary(
      sheet: accessoriesSummarySheet,
      completedOrders: completed,
    );

    _styleHeader(summary, 0, 0, 'BIGGER BREW END-OF-DAY SUMMARY');
    _styleHeader(summary, 0, 8, 'PAYMENT BREAKDOWN');
    _styleRow(summary, 0, 9);
    _styleRow(ordersSheet, 0, 0);
    _styleRow(itemsSheet, 0, 0);

    _setWidths(summary, [30, 22, 20, 22]);
    _setWidths(ordersSheet, [14, 14, 12, 18, 18, 18, 16, 18, 16, 30]);
    _setWidths(itemsSheet, [14, 28, 18, 22, 22, 35, 12, 18, 18, 18, 18]);
    _setWidths(drinkSummarySheet, [30, 12, 12, 12, 14]);
    _setWidths(mealSummarySheet, [30, 14, 28, 14]);
    _setWidths(accessoriesSummarySheet, [34, 14]);

    final safeDate = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final bytes = workbook.save(
      fileName: 'Bigger_Brew_EOD_$safeDate.xlsx',
    );
    return bytes != null;
  }

  static void _buildDrinkSummary({
    required Sheet sheet,
    required List<KioskOrder> completedOrders,
  }) {
    // Rows are individual drinks; columns are the commercial cup sizes.
    // The Total Cups column is the number to use directly for daily cup prep.
    final counts = <String, Map<String, int>>{};
    final sizeLabels = <String>{};

    for (final order in completedOrders) {
      for (final item in order.items) {
        if (item.product.productType.toLowerCase() != 'drink') {
          continue;
        }

        final size = _drinkSizeLabel(item.size);
        if (size.isEmpty) {
          // Keep drinks without a configured size out of the size columns,
          // rather than guessing a cup size from price or product name.
          continue;
        }

        sizeLabels.add(size);
        final productCounts = counts.putIfAbsent(
          item.product.name,
          () => <String, int>{},
        );
        productCounts[size] = (productCounts[size] ?? 0) + item.quantity;
      }
    }

    final orderedSizes = _orderedDrinkSizes(sizeLabels);

    sheet.appendRow([
      TextCellValue('DRINK SUMMARY — CUPS'),
    ]);
    sheet.appendRow([
      TextCellValue('Drink'),
      ...orderedSizes.map(TextCellValue.new),
      TextCellValue('Total Cups'),
    ]);

    final totalBySize = <String, int>{};
    var grandTotal = 0;

    final drinkNames = counts.keys.toList()..sort();
    for (final drinkName in drinkNames) {
      final productCounts = counts[drinkName]!;
      var productTotal = 0;
      final row = <CellValue>[
        TextCellValue(drinkName),
      ];

      for (final size in orderedSizes) {
        final quantity = productCounts[size] ?? 0;
        row.add(IntCellValue(quantity));
        totalBySize[size] = (totalBySize[size] ?? 0) + quantity;
        productTotal += quantity;
      }

      row.add(IntCellValue(productTotal));
      grandTotal += productTotal;
      sheet.appendRow(row);
    }

    sheet.appendRow([
      TextCellValue('TOTAL CUPS'),
      ...orderedSizes.map(
        (size) => IntCellValue(totalBySize[size] ?? 0),
      ),
      IntCellValue(grandTotal),
    ]);

    _styleHeader(sheet, 0, 0, 'DRINK SUMMARY — CUPS');
    _styleRow(sheet, 0, 1);
    _styleRow(sheet, 0, sheet.maxRows - 1);
  }

  static void _buildAccessoriesSummary({
    required Sheet sheet,
    required List<KioskOrder> completedOrders,
  }) {
    final accessoryCounts = <String, int>{};

    for (final order in completedOrders) {
      for (final item in order.items) {
        if (item.product.productType.toLowerCase() != 'accessory') {
          continue;
        }
        accessoryCounts[item.product.name] =
            (accessoryCounts[item.product.name] ?? 0) + item.quantity;
      }
    }

    sheet.appendRow([
      TextCellValue('ACCESSORIES DAILY SUMMARY'),
    ]);
    sheet.appendRow([
      TextCellValue('Accessory'),
      TextCellValue('Qty'),
    ]);

    var totalAccessories = 0;
    final names = accessoryCounts.keys.toList()..sort();
    for (final name in names) {
      final quantity = accessoryCounts[name]!;
      totalAccessories += quantity;
      sheet.appendRow([
        TextCellValue(name),
        IntCellValue(quantity),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL ACCESSORIES'),
      IntCellValue(totalAccessories),
    ]);

    _styleHeader(sheet, 0, 0, 'ACCESSORIES DAILY SUMMARY');
    _styleRow(sheet, 0, 1);
    _styleRow(sheet, 0, sheet.maxRows - 1);
  }

  static void _buildMealSummary({
    required Sheet sheet,
    required List<KioskOrder> completedOrders,
  }) {
    final mealCounts = <String, int>{};
    final addOnCounts = <String, int>{};

    for (final order in completedOrders) {
      for (final item in order.items) {
        if (item.product.category != KioskCategory.riceMeals) {
          continue;
        }

        mealCounts[item.product.name] =
            (mealCounts[item.product.name] ?? 0) + item.quantity;

        for (final option in item.options) {
          addOnCounts[option.name] =
              (addOnCounts[option.name] ?? 0) + (item.quantity);
        }
      }
    }

    sheet.appendRow([
      TextCellValue('MEAL SUMMARY — COUNT'),
    ]);
    sheet.appendRow([
      TextCellValue('Meal'),
      TextCellValue('Qty'),
    ]);

    var totalMeals = 0;
    final mealNames = mealCounts.keys.toList()..sort();
    for (final mealName in mealNames) {
      final quantity = mealCounts[mealName]!;
      totalMeals += quantity;
      sheet.appendRow([
        TextCellValue(mealName),
        IntCellValue(quantity),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL MEALS'),
      IntCellValue(totalMeals),
    ]);

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue('MEAL ADD-ONS — COUNT'),
    ]);
    sheet.appendRow([
      TextCellValue('Meal Add-on'),
      TextCellValue('Qty'),
    ]);

    var totalAddOns = 0;
    final addOnNames = addOnCounts.keys.toList()..sort();
    for (final addOnName in addOnNames) {
      final quantity = addOnCounts[addOnName]!;
      totalAddOns += quantity;
      sheet.appendRow([
        TextCellValue(addOnName),
        IntCellValue(quantity),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL MEAL ADD-ONS'),
      IntCellValue(totalAddOns),
    ]);

    _styleHeader(sheet, 0, 0, 'MEAL SUMMARY — COUNT');
    _styleRow(sheet, 0, 1);

    final mealAddOnHeaderRow = mealNames.length + 4;
    _styleHeader(sheet, 0, mealAddOnHeaderRow, 'MEAL ADD-ONS — COUNT');
    _styleRow(sheet, 0, mealAddOnHeaderRow + 1);
    _styleRow(sheet, 0, sheet.maxRows - 1);
  }

  static String _drinkSizeLabel(KioskSize? size) {
    if (size == null) return '';

    final name = size.name.trim().toLowerCase();
    final displayVolume = size.displayVolume?.trim().toLowerCase() ?? '';

    if (name == '12oz' || displayVolume == '12oz') return '12oz';
    if (name == '22oz' || displayVolume == '22oz') return '22oz';
    if (name == '1l' ||
        name == '1 liter' ||
        displayVolume == '1l' ||
        displayVolume == '1 liter') {
      return '1 Liter';
    }

    // Preserve a future catalog size instead of silently dropping it.
    return size.displayVolume?.trim().isNotEmpty == true
        ? size.displayVolume!.trim()
        : size.name.trim();
  }

  static List<String> _orderedDrinkSizes(Set<String> sizes) {
    const preferred = <String>['12oz', '22oz', '1 Liter'];
    final ordered = <String>[];

    for (final size in preferred) {
      if (sizes.contains(size)) ordered.add(size);
    }

    final remaining = sizes.difference(ordered.toSet()).toList()..sort();
    ordered.addAll(remaining);
    return ordered;
  }

  static String _categoryLabel(KioskCategory category) {
    switch (category) {
      case KioskCategory.milkTea:
        return 'Milk Tea';
      case KioskCategory.fruitTea:
        return 'Fruit Tea';
      case KioskCategory.coffee:
        return 'Coffee';
      case KioskCategory.chocolate:
        return 'Chocolate';
      case KioskCategory.matcha:
        return 'Matcha';
      case KioskCategory.frappe:
        return 'Frappe';
      case KioskCategory.fruitySoda:
        return 'Fruity Soda';
      case KioskCategory.slushies:
        return 'Slushies';
      case KioskCategory.riceMeals:
        return 'Rice Meals';
      case KioskCategory.burgers:
        return 'Burgers';
      case KioskCategory.merienda:
        return 'Merienda';
      case KioskCategory.accessories:
        return 'Accessories';
      case KioskCategory.addOns:
        return 'Add-ons';
    }

    // Safety fallback for future categories.
    return category.title;
  }

  static Set<String> _paymentMethods(List<KioskOrder> orders) {
    final methods = <String>{};
    for (final order in orders) {
      if (order.paymentMethod.trim().isNotEmpty) {
        methods.add(order.paymentMethod);
      }
    }
    if (methods.isEmpty) {
      methods.addAll(const ['GCash', 'Cash', 'Others']);
    }
    return methods;
  }

  static String _timeLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static void _styleHeader(Sheet sheet, int column, int row, String value) {
    final cell = sheet.cell(CellIndex.indexByColumnRow(
      columnIndex: column,
      rowIndex: row,
    ));
    cell.value = TextCellValue(value);
    cell.cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
      backgroundColorHex: ExcelColor.fromHexString('#C69214'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
  }

  static void _styleRow(Sheet sheet, int startColumn, int row) {
    for (var column = startColumn; column < sheet.maxColumns; column++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: column,
        rowIndex: row,
      ));
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#F7F5F1'),
      );
    }
  }

  static void _setWidths(Sheet sheet, List<double> widths) {
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }
}
