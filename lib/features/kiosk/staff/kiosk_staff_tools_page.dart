import 'package:flutter/material.dart';

import '../kiosk_idle_timeout.dart';
import '../pages/kiosk_order_history_page.dart';
import '../pages/kiosk_order_queue_page.dart';
import '../settings/kiosk_settings_page.dart';
import 'kiosk_catalog_manager_page.dart';
import 'kiosk_staff_gate.dart';
import '../orders/kiosk_order_repository.dart';

class KioskStaffToolsPage extends StatelessWidget {
  const KioskStaffToolsPage({super.key});

  Future<void> _openPage(BuildContext context, Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _exit(BuildContext context) {
    KioskStaffGate.endSession();
    kioskIdleTimeoutController.start();
    Navigator.of(context).pop();
  }

  Future<void> _syncHistoricalDrinkTemperatures(BuildContext context) async {
    final repository = KioskOrderRepository();

    // Preview the operation before changing any transaction data.
    final resultPreview = await repository.syncHistoricalDrinkTemperatures(dryRun: true);

    if (!context.mounted) return;

    final action = resultPreview.updatedItems == 0
        ? 'No historical drink temperatures need to be synchronized.'
        : '${resultPreview.updatedItems} drink item(s) across '
            '${resultPreview.updatedOrders} order(s) will be synchronized.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('SYNC HISTORICAL DRINK TEMPERATURE'),
        content: Text(
          '$action\n\n'
          'Historical drink temperatures will be synchronized to the current '
          'product catalog. This includes transactions that were previously '
          'saved with the default Iced value. Non-drink items and all other '
          'transaction details are left unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CLOSE'),
          ),
          if (resultPreview.updatedItems > 0)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('SYNC'),
            ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final result = await repository.syncHistoricalDrinkTemperatures();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Historical sync complete: ${result.updatedItems} '
              'drink item(s) updated.',
            ),
          ),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to sync historical drinks: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF171717);
    const gold = Color(0xFFC69214);

    final media = MediaQuery.sizeOf(context);
    final isLandscape = media.width > media.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2ED),
      appBar: AppBar(
        backgroundColor: dark,
        foregroundColor: Colors.white,
        title: const Text(
          'STAFF MODE',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            onPressed: () => _exit(context),
            icon: const Icon(Icons.lock_outline, color: Colors.white),
            label: const Text(
              'EXIT STAFF MODE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            final horizontalPadding = isLandscape ? 24.0 : 18.0;
            final contentMaxWidth = isLandscape ? 980.0 : 720.0;
            final topPadding = compact ? 12.0 : (isLandscape ? 18.0 : 24.0);
            final iconSize = compact ? 48.0 : (isLandscape ? 58.0 : 64.0);

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                compact ? 16 : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_outlined,
                        size: iconSize,
                        color: dark,
                      ),
                      SizedBox(height: compact ? 6 : 10),
                      Text(
                        'STAFF TOOLS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 24 : (isLandscape ? 28 : 30),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Customer ordering is hidden while staff mode is active.\n'
                        'Your staff session remains authenticated for up to 30 minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                      SizedBox(height: compact ? 14 : 22),
                      if (isLandscape)
                        _buildLandscapeActions(context, compact)
                      else
                        _buildPortraitActions(context, compact),
                      SizedBox(height: compact ? 14 : 22),
                      _buildReturnButton(context, gold, compact),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeActions(BuildContext context, bool compact) {
    final actions = _actions(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: compact ? 92 : 108,
      ),
      itemBuilder: (context, index) => _StaffAction(
        icon: actions[index].icon,
        title: actions[index].title,
        subtitle: actions[index].subtitle,
        onTap: actions[index].onTap,
        compact: true,
      ),
    );
  }

  Widget _buildPortraitActions(BuildContext context, bool compact) {
    final actions = _actions(context);

    return Column(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          _StaffAction(
            icon: actions[i].icon,
            title: actions[i].title,
            subtitle: actions[i].subtitle,
            onTap: actions[i].onTap,
            compact: compact,
          ),
          if (i != actions.length - 1) SizedBox(height: compact ? 10 : 12),
        ],
      ],
    );
  }

  List<_StaffActionData> _actions(BuildContext context) => [
        _StaffActionData(
          icon: Icons.receipt_long_outlined,
          title: 'ORDER QUEUE',
          subtitle: 'View and manage active orders.',
          onTap: () => _openPage(context, const KioskOrderQueuePage()),
        ),
        _StaffActionData(
          icon: Icons.history_outlined,
          title: 'ORDER HISTORY / EOD',
          subtitle: 'Review orders and export daily reports.',
          onTap: () => _openPage(context, const KioskOrderHistoryPage()),
        ),
        _StaffActionData(
          icon: Icons.sync_outlined,
          title: 'SYNC HISTORICAL DRINKS',
          subtitle: 'Synchronize historical drink temperatures with the current catalog.',
          onTap: () => _syncHistoricalDrinkTemperatures(context),
        ),
        _StaffActionData(
          icon: Icons.inventory_2_outlined,
          title: 'PRODUCT CATALOG',
          subtitle: 'Browse, search and manage the menu catalog.',
          onTap: () => _openPage(context, const KioskCatalogManagerPage()),
        ),
        _StaffActionData(
          icon: Icons.settings_outlined,
          title: 'KIOSK SETTINGS',
          subtitle: 'Store status, employee mode, printer and staff PIN.',
          onTap: () => _openPage(context, const KioskSettingsPage()),
        ),
      ];

  Widget _buildReturnButton(BuildContext context, Color gold, bool compact) {
    return FilledButton.icon(
      onPressed: () => _exit(context),
      icon: const Icon(Icons.lock_outline),
      label: const Text('RETURN TO CUSTOMER KIOSK'),
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: Colors.white,
        minimumSize: Size.fromHeight(compact ? 48 : 54),
      ),
    );
  }
}

class _StaffActionData {
  const _StaffActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _StaffAction extends StatelessWidget {
  const _StaffAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 12 : 18,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: compact ? 30 : 34,
                color: const Color(0xFFC69214),
              ),
              SizedBox(width: compact ? 14 : 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: compact ? 16 : 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
