import 'package:bigger_brew_kiosk/features/kiosk/staff_access.dart';
import 'package:flutter/material.dart';

class CatalogPermissionGate extends StatelessWidget {
  final StaffRole role;
  final CatalogPermission permission;
  final Widget child;
  final bool hideWhenDenied;

  const CatalogPermissionGate({
    super.key,
    required this.role,
    required this.permission,
    required this.child,
    this.hideWhenDenied = false,
  });

  @override
  Widget build(BuildContext context) {
    final allowed = StaffAccessPolicy.can(role, permission);
    if (allowed) return child;
    if (hideWhenDenied) return const SizedBox.shrink();
    return Opacity(opacity: 0.45, child: IgnorePointer(child: child));
  }
}

Future<bool> requireCatalogPermission(
  BuildContext context,
  StaffRole role,
  CatalogPermission permission,
) async {
  if (StaffAccessPolicy.can(role, permission)) return true;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('MANAGER ACCESS REQUIRED'),
      content:
          const Text('This catalog operation is restricted to a manager PIN.'),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK')),
      ],
    ),
  );
  return false;
}
