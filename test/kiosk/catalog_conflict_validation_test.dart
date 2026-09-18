import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/product_catalog/catalog_validator.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';

void main() {
  ProductCatalog catalogWith({
    List<CatalogOptionDefinition> definitions = const [],
    List<ProductOption> options = const [],
  }) {
    return ProductCatalog(
      catalogVersion: 'test',
      categories: const [
        ProductCategory(
          categoryId: 'burgers',
          name: 'Burgers',
          subtitle: '',
          active: true,
        ),
      ],
      optionDefinitions: definitions,
      products: [
        CatalogProduct(
          productId: 'cheese_burger',
          name: 'Cheese Burger',
          productType: 'food',
          categoryId: 'burgers',
          active: true,
          available: true,
          sizes: const [],
          variants: const [],
          options: options,
        ),
      ],
    );
  }

  test('rejects an assigned option missing from shared definitions', () {
    final report = CatalogValidator().validate(catalogWith(
      options: const [
        ProductOption(
          optionId: 'egg',
          name: 'Egg',
          price: 15,
          active: true,
        ),
      ],
    ));

    expect(
      report.issues.where((i) => i.code == 'missing_product_option_definition'),
      hasLength(1),
    );
    expect(report.isValid, isFalse);
  });

  test('rejects an assigned option incompatible with product type', () {
    final report = CatalogValidator().validate(catalogWith(
      definitions: const [
        CatalogOptionDefinition(
          optionId: 'espresso_shot',
          name: 'Espresso Shot',
          productTypes: ['drink'],
          price: 30,
          active: true,
        ),
      ],
      options: const [
        ProductOption(
          optionId: 'espresso_shot',
          name: 'Espresso Shot',
          price: 30,
          active: true,
        ),
      ],
    ));

    expect(
      report.issues.where((i) => i.code == 'incompatible_product_option_type'),
      hasLength(1),
    );
    expect(report.isValid, isFalse);
  });

  test('accepts an assigned option compatible with its product type', () {
    final report = CatalogValidator().validate(catalogWith(
      definitions: const [
        CatalogOptionDefinition(
          optionId: 'egg',
          name: 'Egg',
          productTypes: ['food'],
          price: 15,
          active: true,
        ),
      ],
      options: const [
        ProductOption(
          optionId: 'egg',
          name: 'Egg',
          price: 15,
          active: true,
        ),
      ],
    ));

    expect(
      report.issues.where((i) => i.code == 'incompatible_product_option_type'),
      isEmpty,
    );
  });
}
