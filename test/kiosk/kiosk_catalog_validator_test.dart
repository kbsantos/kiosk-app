import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/product_catalog/catalog_validator.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';

void main() {
  test('valid food option product type passes catalog health check', () {
    const catalog = ProductCatalog(
      catalogVersion: 'test',
      categories: [],
      products: [],
      optionDefinitions: [
        CatalogOptionDefinition(
          optionId: 'one_rice',
          name: 'One Rice',
          productTypes: ['food'],
          price: 20,
          active: true,
        ),
      ],
    );

    final report = CatalogValidator().validate(catalog);

    expect(
      report.issues.where((i) => i.code == 'invalid_option_product_type'),
      isEmpty,
    );
    expect(report.isValid, isTrue);
  });

  test('unknown option product type fails catalog health check', () {
    const catalog = ProductCatalog(
      catalogVersion: 'test',
      categories: [],
      products: [],
      optionDefinitions: [
        CatalogOptionDefinition(
          optionId: 'invalid_option',
          name: 'Invalid Option',
          productTypes: ['unknown'],
          active: true,
        ),
      ],
    );

    final report = CatalogValidator().validate(catalog);

    expect(
      report.issues.where((i) => i.code == 'invalid_option_product_type'),
      hasLength(1),
    );
    expect(report.isValid, isFalse);
  });
}
