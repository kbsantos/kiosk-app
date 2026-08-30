import 'package:flutter/foundation.dart';

class KioskCategory {
  final String id;
  final String title;
  final String icon;

  const KioskCategory._(this.id, this.title, this.icon);

  static const milkTea = KioskCategory._('milk_tea', 'Milk Tea', '🧋');
  static const fruitTea = KioskCategory._('fruit_tea', 'Fruit Tea', '🍓');
  static const coffee = KioskCategory._('coffee', 'Coffee', '☕');
  static const chocolate = KioskCategory._('chocolate', 'Chocolate', '🍫');
  static const matcha = KioskCategory._('matcha', 'Matcha', '🍵');
  static const frappe = KioskCategory._('frappe', 'Frappe', '🥤');
  static const fruitySoda = KioskCategory._('fruity_soda', 'Fruity Soda', '🫧');
  static const slushies = KioskCategory._('slushies', 'Slushies', '🧊');
  static const riceMeals = KioskCategory._('rice_meals', 'Rice Meals', '🍚');
  static const burgers = KioskCategory._('burgers', 'Burgers', '🍔');
  static const merienda = KioskCategory._('merienda', 'Merienda', '🍟');
  static const accessories =
      KioskCategory._('accessories', 'Accessories', '🛍️');
  static const addOns = KioskCategory._('add_ons', 'Add-ons', '➕');

  static const List<KioskCategory> values = [
    milkTea,
    fruitTea,
    coffee,
    chocolate,
    matcha,
    frappe,
    fruitySoda,
    slushies,
    riceMeals,
    burgers,
    merienda,
    accessories,
    addOns,
  ];

  factory KioskCategory.fromCatalog({
    required String id,
    required String title,
    String? icon,
  }) {
    final known = fromId(id);
    if (known != null && (icon == null || icon.trim().isEmpty)) {
      return known;
    }
    return KioskCategory._(
      id,
      title,
      icon?.trim().isNotEmpty == true ? icon!.trim() : (known?.icon ?? '📦'),
    );
  }

  static KioskCategory? fromId(String id) {
    for (final category in values) {
      if (category.id == id) return category;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is KioskCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class KioskSize {
  final String id;
  final String name;
  final int? volumeMl;
  final String? displayVolume;
  final int? price;

  const KioskSize({
    required this.id,
    required this.name,
    this.volumeMl,
    this.displayVolume,
    this.price,
  });

  bool get priceConfigured => price != null;
}

class KioskVariant {
  final String id;
  final String name;
  final int? price;
  final bool active;

  const KioskVariant({
    required this.id,
    required this.name,
    this.price,
    this.active = true,
  });

  bool get priceConfigured => price != null;

  KioskVariant copyWith({
    String? id,
    String? name,
    int? price,
    bool? active,
  }) {
    return KioskVariant(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      active: active ?? this.active,
    );
  }
}

class KioskCatalogOption {
  final String id;
  final String name;
  final int price;
  final bool kitchenPrepared;

  const KioskCatalogOption({
    required this.id,
    required this.name,
    required this.price,
    this.kitchenPrepared = false,
  });
}

class KioskProduct {
  final String id;
  final String name;
  final int? price;
  final KioskCategory category;
  final bool available;
  final String? recipeRef;
  final String? groupId;
  final String? groupName;
  final String productType;
  final String? drinkTemperature;
  final bool kitchenPrepared;
  final List<KioskSize> sizes;
  final List<KioskVariant> variants;
  final List<KioskCatalogOption> options;

  const KioskProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.available = true,
    this.recipeRef,
    this.groupId,
    this.groupName,
    this.productType = 'drink',
    this.drinkTemperature,
    this.kitchenPrepared = false,
    this.sizes = const [],
    this.variants = const [],
    this.options = const [],
  });

  bool get priceConfigured =>
      price != null ||
      sizes.any((size) => size.priceConfigured) ||
      variants.any((variant) => variant.priceConfigured);

  bool get hasSizes => sizes.isNotEmpty;

  bool get hasVariants => variants.any((variant) => variant.active);

  List<KioskVariant> get activeVariants =>
      variants.where((variant) => variant.active).toList(growable: false);
}

class KioskOption {
  final String id;
  final String name;
  final int price;
  final bool kitchenPrepared;

  const KioskOption({
    required this.id,
    required this.name,
    required this.price,
    this.kitchenPrepared = false,
  });
}

class KioskCartItem {
  final KioskProduct product;
  final KioskSize? size;
  final KioskVariant? variant;
  final int quantity;
  final List<KioskOption> options;
  /// Snapshot from the product at time of sale; null for legacy orders.
  final String? drinkTemperature;

  const KioskCartItem({
    required this.product,
    this.size,
    this.variant,
    this.quantity = 1,
    this.options = const [],
    this.drinkTemperature,
  });

  int get basePrice => size?.price ?? variant?.price ?? product.price ?? 0;

  int get unitPrice =>
      basePrice + options.fold<int>(0, (sum, option) => sum + option.price);

  int get total => unitPrice * quantity;

  /// Human-readable item description used consistently across kiosk UI,
  /// order history, reports, and receipts. The selected variant is part of
  /// the item identity and must never be dropped from presentation.
  String get displayLabel {
    final parts = <String>[product.name];
    if (size != null) {
      parts.add(
        '${size!.name}${size!.displayVolume == null ? '' : ' • ${size!.displayVolume}'}',
      );
    }
    if (variant != null) {
      parts.add(variant!.name);
    }
    if (options.isNotEmpty) {
      parts.add(options.map((option) => option.name).join(' • '));
    }
    return parts.join(' — ');
  }

  KioskCartItem copyWith({
    int? quantity,
    KioskSize? size,
    KioskVariant? variant,
    List<KioskOption>? options,
    String? drinkTemperature,
  }) {
    return KioskCartItem(
      product: product,
      size: size ?? this.size,
      variant: variant ?? this.variant,
      quantity: quantity ?? this.quantity,
      options: options ?? this.options,
      drinkTemperature: drinkTemperature ?? this.drinkTemperature,
    );
  }
}

class KioskCart extends ChangeNotifier {
  final List<KioskCartItem> _items = [];

  List<KioskCartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold<int>(0, (sum, item) => sum + item.quantity);

  int get total => _items.fold<int>(0, (sum, item) => sum + item.total);

  bool canAdd(
    KioskProduct product, {
    KioskSize? size,
    KioskVariant? variant,
  }) {
    if (!product.available) return false;
    if (variant != null && !variant.active) return false;

    final effectivePrice = size?.price ?? variant?.price ?? product.price;
    return effectivePrice != null;
  }

  void add(
    KioskProduct product, {
    KioskSize? size,
    KioskVariant? variant,
    List<KioskOption> options = const [],
  }) {
    if (!canAdd(product, size: size, variant: variant)) return;

    _items.add(
      KioskCartItem(
        product: product,
        size: size,
        variant: variant,
        options: List.unmodifiable(options),
        drinkTemperature: product.drinkTemperature,
      ),
    );

    notifyListeners();
  }

  void increment(int index) {
    if (index < 0 || index >= _items.length) return;

    _items[index] = _items[index].copyWith(
      quantity: _items[index].quantity + 1,
    );

    notifyListeners();
  }

  void decrement(int index) {
    if (index < 0 || index >= _items.length) return;

    if (_items[index].quantity <= 1) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity - 1,
      );
    }

    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
