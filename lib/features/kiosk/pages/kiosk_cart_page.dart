import 'package:flutter/material.dart';
import '../currency/kiosk_currency.dart';

import '../models/kiosk_models.dart';
import 'kiosk_checkout_page.dart';

class KioskCartPage extends StatelessWidget {
  final KioskCart cart;

  const KioskCartPage({
    super.key,
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        title: const Text(
          'YOUR ORDER',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListenableBuilder(
        listenable: cart,
        builder: (_, __) {
          if (cart.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.black26,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your order is empty',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final item = cart.items[index];

                    return Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.displayLabel,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (item.size != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                        '${item.size!.name}${item.size!.displayVolume == null ? '' : ' • ${item.size!.displayVolume}'}',
                                      ),
                                    ),
                                  if (item.options.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Text(
                                        item.options
                                            .map((option) => option.name)
                                            .join(' • '),
                                      ),
                                    ),
                                  const SizedBox(height: 5),
                                  Text(
                                    KioskCurrency.format(item.total),
                                    style: const TextStyle(
                                      color: Color(0xFFC69214),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => cart.decrement(index),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                              ),
                            ),
                            Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            IconButton(
                              onPressed: () => cart.increment(index),
                              icon: const Icon(
                                Icons.add_circle_outline,
                              ),
                            ),
                            IconButton(
                              onPressed: () => cart.removeAt(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TOTAL  ${KioskCurrency.format(cart.total)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: cart.items.isEmpty
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        KioskCheckoutPage(cart: cart),
                                  ),
                                );
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC69214),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 18,
                          ),
                        ),
                        child: const Text(
                          'CHECKOUT',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
