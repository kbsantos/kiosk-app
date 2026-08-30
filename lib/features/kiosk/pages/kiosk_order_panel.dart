import 'package:flutter/material.dart';
import '../currency/kiosk_currency.dart';

import '../models/kiosk_models.dart';

class KioskOrderPanel extends StatelessWidget {
  final KioskCart cart;
  final VoidCallback? onCheckout;
  final bool showHeader;

  const KioskOrderPanel({
    super.key,
    required this.cart,
    this.onCheckout,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Color(0xFFE4DED5)),
        ),
      ),
      child: Column(
        children: [
          if (showHeader)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF171717),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                    size: 27,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'YOUR ORDER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: cart,
                    builder: (_, __) => Text(
                      '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: cart,
              builder: (_, __) {
                if (cart.items.isEmpty) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // The Android keyboard can leave the order panel with
                      // only a small amount of vertical space in landscape.
                      // Keep the empty state compact so it never competes
                      // with the fixed order summary at the bottom.
                      final compact = constraints.maxHeight < 180;

                      return Center(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Padding(
                            padding: EdgeInsets.all(compact ? 12 : 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: compact ? 44 : 62,
                                  color: Colors.black26,
                                ),
                                SizedBox(height: compact ? 6 : 12),
                                Text(
                                  'Your order is empty',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: compact ? 16 : 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black54,
                                  ),
                                ),
                                SizedBox(height: compact ? 3 : 5),
                                const Text(
                                  'Select a product to add it here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black45),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (_, index) {
                    final item = cart.items[index];
                    return _OrderItemTile(cart: cart, index: index, item: item);
                  },
                );
              },
            ),
          ),
          _OrderSummary(cart: cart, onCheckout: onCheckout),
        ],
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final KioskCart cart;
  final int index;
  final KioskCartItem item;

  const _OrderItemTile({
    required this.cart,
    required this.index,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E0D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.displayLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                KioskCurrency.format(item.total),
                style: const TextStyle(
                  color: Color(0xFFC69214),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (item.size != null) ...[
            const SizedBox(height: 4),
            Text(
              '${item.size!.name}${item.size!.displayVolume == null ? '' : ' • ${item.size!.displayVolume}'}',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (item.options.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.options.map((option) => option.name).join(' • '),
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _QuantityButton(
                icon: Icons.remove,
                onPressed: () => cart.decrement(index),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _QuantityButton(
                icon: Icons.add,
                onPressed: () => cart.increment(index),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                onPressed: () => cart.removeAt(index),
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _QuantityButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEFE9E0),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final KioskCart cart;
  final VoidCallback? onCheckout;

  const _OrderSummary({required this.cart, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: Offset(0, -3),
              color: Color(0x18000000),
            ),
          ],
        ),
        child: ListenableBuilder(
          listenable: cart,
          builder: (_, __) {
            final enabled = cart.items.isNotEmpty;
            return Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      KioskCurrency.format(cart.total),
                      style: const TextStyle(
                        color: Color(0xFFC69214),
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: enabled ? onCheckout : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC69214),
                    ),
                    child: const Text(
                      'CHECKOUT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
