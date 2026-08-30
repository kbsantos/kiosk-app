import '../models/kiosk_models.dart';

class KioskMenuData {
  static const riceMeals = <KioskProduct>[
    KioskProduct(id: 'hungarian_sausage_egg', name: 'Hungarian Sausage w/ Egg', price: 85, category: KioskCategory.riceMeals),
    KioskProduct(id: 'liempo', name: 'Liempo', price: 85, category: KioskCategory.riceMeals),
    KioskProduct(id: 'lechon_kawali', name: 'Lechon Kawali', price: 85, category: KioskCategory.riceMeals),
    KioskProduct(id: 'sisig', name: 'Sisig', price: 85, category: KioskCategory.riceMeals),
    KioskProduct(id: 'fried_chicken', name: 'Fried Chicken', price: 80, category: KioskCategory.riceMeals),
    KioskProduct(id: 'bacon_egg', name: 'Bacon & Egg', price: 80, category: KioskCategory.riceMeals),
    KioskProduct(id: 'spam_egg', name: 'Spam & Egg', price: 80, category: KioskCategory.riceMeals),
    KioskProduct(id: 'burger_steak', name: 'Burger Steak', price: 70, category: KioskCategory.riceMeals),
    KioskProduct(id: 'chicken_pastil', name: 'Chicken Pastil', price: 70, category: KioskCategory.riceMeals),
  ];

  static const riceMealAddOns = <KioskOption>[
    KioskOption(id: 'extra_rice', name: 'Extra Rice', price: 20, kitchenPrepared: true),
    KioskOption(id: 'garlic_mayo', name: 'Garlic Mayo Dip', price: 10, kitchenPrepared: true),
    KioskOption(id: 'egg', name: 'Egg', price: 15, kitchenPrepared: true),
  ];

  static List<KioskProduct> productsFor(KioskCategory category) {
    if (category == KioskCategory.riceMeals) return riceMeals;
    return const [];
  }
}
