import 'package:flutter/material.dart';

import '../kiosk_idle_timeout.dart';
import '../pages/kiosk_order_history_page.dart';
import '../pages/kiosk_order_queue_page.dart';
import '../settings/kiosk_settings_page.dart';
import 'kiosk_staff_gate.dart';
import '../administration/kiosk_administration_sync_page.dart';
import '../../store_management/store_administration_page.dart';
import '../../inventory/inventory_stock_page.dart';
import '../pages/kiosk_sales_dashboard_page.dart';
import '../staff_access.dart';

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
          icon: Icons.admin_panel_settings_outlined,
          title: 'ADMINISTRATION SYNC',
          subtitle: 'Manage historical synchronization and reporting transaction sync.',
          onTap: () => _openPage(
            context,
            const KioskAdministrationSyncPage(),
          ),
        ),
        _StaffActionData(
          icon: Icons.settings_outlined,
          title: 'KIOSK SETTINGS',
          subtitle: 'Store status, employee mode, printer and staff PIN.',
          onTap: () => _openPage(context, const KioskSettingsPage()),
        ),
        _StaffActionData(
          icon: Icons.analytics_outlined,
          title: 'SALES DASHBOARD',
          subtitle: 'Analyze local kiosk sales by date, product, category and payment.',
          onTap: () async {
            final role = await requestStaffRole(context);
            if (!context.mounted || role != StaffRole.manager) return;
            await _openPage(context, const KioskSalesDashboardPage());
          },
        ),
        _StaffActionData(
          icon: Icons.inventory_2_outlined,
          title: 'INVENTORY STOCK',
          subtitle: 'View local stock configuration and low-stock indicators.',
          onTap: () async {
            final role = await requestStaffRole(context);
            if (!context.mounted || role != StaffRole.manager) return;
            await _openPage(context, const InventoryStockPage());
          },
        ),
        _StaffActionData(
          icon: Icons.store_mall_directory_outlined,
          title: 'STORE ADMINISTRATION',
          subtitle: 'Manager-only store records and active status.',
          onTap: () async {
            final role = await requestStaffRole(context);
            if (!context.mounted || role != StaffRole.manager) return;
            await _openPage(context, const StoreAdministrationPage());
          },
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
