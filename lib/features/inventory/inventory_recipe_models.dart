/// Integration contract between the kiosk catalog and the separate inventory
/// / recipe system. The kiosk stores only stable references and consumption
/// quantities; it does not depend on Recipe Guide application classes.

library;

class InventoryRecipeIngredient {
  final String inventoryItemId;
  final num quantity;
  final String unit;

  const InventoryRecipeIngredient({
    required this.inventoryItemId,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toJson() => {
        'inventoryItemId': inventoryItemId,
        'quantity': quantity,
        'unit': unit,
      };

  factory InventoryRecipeIngredient.fromJson(Map<String, dynamic> json) =>
      InventoryRecipeIngredient(
        inventoryItemId: json['inventoryItemId']?.toString() ?? '',
        quantity: json['quantity'] as num? ?? 0,
        unit: json['unit']?.toString() ?? '',
      );
}

class InventoryRecipe {
  final String recipeId;
  final String productId;
  final String? sizeId;
  final String? variantId;
  final List<InventoryRecipeIngredient> ingredients;

  const InventoryRecipe({
    required this.recipeId,
    required this.productId,
    this.sizeId,
    this.variantId,
    required this.ingredients,
  });

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'productId': productId,
        if (sizeId != null) 'sizeId': sizeId,
        if (variantId != null) 'variantId': variantId,
        'ingredients': ingredients.map((x) => x.toJson()).toList(),
      };

  factory InventoryRecipe.fromJson(Map<String, dynamic> json) => InventoryRecipe(
        recipeId: json['recipeId']?.toString() ?? '',
        productId: json['productId']?.toString() ?? '',
        sizeId: json['sizeId']?.toString(),
        variantId: json['variantId']?.toString(),
        ingredients: (json['ingredients'] as List<dynamic>? ?? const [])
            .map((e) => InventoryRecipeIngredient.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList(growable: false),
      );

  bool get isBaseRecipe => sizeId == null && variantId == null;
}

/// Minimal catalog-side reference used by validation. Keeping this small
/// prevents the inventory integration from taking ownership of catalog data.
class CatalogRecipeProductRef {
  final String productId;
  final String? recipeRef;

  const CatalogRecipeProductRef({
    required this.productId,
    this.recipeRef,
  });
}
