import 'inventory_recipe_models.dart';

class InventoryRecipeValidationIssue {
  final String code;
  final String message;
  final String? reference;

  const InventoryRecipeValidationIssue({
    required this.code,
    required this.message,
    this.reference,
  });
}

class InventoryRecipeValidationResult {
  final List<InventoryRecipeValidationIssue> errors;

  const InventoryRecipeValidationResult({this.errors = const []});

  bool get isValid => errors.isEmpty;
}

class InventoryRecipeValidator {
  const InventoryRecipeValidator._();

  static InventoryRecipeValidationResult validate({
    required List<InventoryRecipe> recipes,
    required List<CatalogRecipeProductRef> catalogProducts,
    required Set<String> inventoryItemIds,
  }) {
    final errors = <InventoryRecipeValidationIssue>[];
    final catalogByProductId = <String, CatalogRecipeProductRef>{};
    for (final product in catalogProducts) {
      if (product.productId.trim().isNotEmpty) {
        catalogByProductId[product.productId] = product;
      }
    }

    final recipesById = <String, InventoryRecipe>{};
    for (final recipe in recipes) {
      if (recipe.recipeId.trim().isEmpty) {
        errors.add(const InventoryRecipeValidationIssue(
          code: 'invalid_recipe_id',
          message: 'Recipe ID is required.',
        ));
        continue;
      }
      if (recipesById.containsKey(recipe.recipeId)) {
        errors.add(InventoryRecipeValidationIssue(
          code: 'duplicate_recipe_id',
          message: 'Recipe ID is duplicated.',
          reference: recipe.recipeId,
        ));
        continue;
      }
      recipesById[recipe.recipeId] = recipe;

      if (!catalogByProductId.containsKey(recipe.productId)) {
        errors.add(InventoryRecipeValidationIssue(
          code: 'recipe_product_not_in_catalog',
          message: 'Recipe references a product that is not in the catalog.',
          reference: recipe.productId,
        ));
      }
      if (recipe.ingredients.isEmpty) {
        errors.add(InventoryRecipeValidationIssue(
          code: 'recipe_has_no_ingredients',
          message: 'Recipe must contain at least one ingredient.',
          reference: recipe.recipeId,
        ));
      }
      for (final ingredient in recipe.ingredients) {
        if (!inventoryItemIds.contains(ingredient.inventoryItemId)) {
          errors.add(InventoryRecipeValidationIssue(
            code: 'missing_inventory_item_reference',
            message: 'Recipe references an inventory item that does not exist.',
            reference: ingredient.inventoryItemId,
          ));
        }
        if (ingredient.quantity <= 0) {
          errors.add(InventoryRecipeValidationIssue(
            code: 'invalid_recipe_quantity',
            message: 'Recipe ingredient quantity must be greater than zero.',
            reference: recipe.recipeId,
          ));
        }
        if (ingredient.unit.trim().isEmpty) {
          errors.add(InventoryRecipeValidationIssue(
            code: 'missing_recipe_unit',
            message: 'Recipe ingredient unit is required.',
            reference: recipe.recipeId,
          ));
        }
      }
    }

    for (final product in catalogProducts) {
      final ref = product.recipeRef?.trim();
      if (ref != null && ref.isNotEmpty && !recipesById.containsKey(ref)) {
        errors.add(InventoryRecipeValidationIssue(
          code: 'missing_recipe_reference',
          message: 'Catalog product references a recipe that is not available.',
          reference: ref,
        ));
      }
    }

    return InventoryRecipeValidationResult(errors: List.unmodifiable(errors));
  }
}
