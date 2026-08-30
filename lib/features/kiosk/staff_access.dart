import 'package:flutter/material.dart';

/// Staff PIN is supplied at build time so the kiosk source does not contain a
/// production credential. Example:
/// flutter build apk --release --dart-define=BIGGER_BREW_STAFF_PIN=1234
enum StaffRole { editor, manager }

class StaffAccessPolicy {
  static const pin = String.fromEnvironment(
    'BIGGER_BREW_STAFF_PIN',
    defaultValue: '0000',
  );

  static const managerPin = String.fromEnvironment(
    'BIGGER_BREW_MANAGER_PIN',
    defaultValue: '',
  );

  static bool authenticate(String enteredPin) =>
      authenticateRole(enteredPin) != null;

  static StaffRole? authenticateRole(String enteredPin) {
    final value = enteredPin.trim();
    if (managerPin.isNotEmpty && value == managerPin) return StaffRole.manager;
    if (value == pin) return StaffRole.editor;
    return null;
  }

  static bool can(StaffRole role, CatalogPermission permission) {
    switch (permission) {
      case CatalogPermission.editCatalog:
      case CatalogPermission.viewHealth:
      case CatalogPermission.createBackup:
      case CatalogPermission.viewAudit:
        return true;
      case CatalogPermission.importCatalog:
      case CatalogPermission.rollbackImport:
      case CatalogPermission.restoreBackup:
      case CatalogPermission.resetCatalog:
      case CatalogPermission.clearAudit:
      case CatalogPermission.exportSyncPackage:
      case CatalogPermission.importSyncPackage:
        return role == StaffRole.manager;
    }
  }
}

enum CatalogPermission {
  editCatalog,
  viewHealth,
  createBackup,
  viewAudit,
  importCatalog,
  rollbackImport,
  restoreBackup,
  resetCatalog,
  clearAudit,
  exportSyncPackage,
  importSyncPackage,
}

Future<StaffRole?> requestStaffRole(BuildContext context) async {
  final controller = TextEditingController();
  var obscure = true;
  var invalid = false;

  final role = await showDialog<StaffRole?>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('STAFF ACCESS',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your staff PIN to open Catalog Management.'),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: obscure,
              keyboardType: TextInputType.number,
              maxLength: 8,
              onSubmitted: (_) {
                final role =
                    StaffAccessPolicy.authenticateRole(controller.text);
                if (role != null) {
                  Navigator.of(dialogContext).pop(role);
                } else {
                  setState(() => invalid = true);
                }
              },
              decoration: InputDecoration(
                labelText: 'Staff PIN',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                ),
                errorText: invalid ? 'Incorrect PIN' : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCEL')),
          FilledButton(
            onPressed: () {
              final role = StaffAccessPolicy.authenticateRole(controller.text);
              if (role != null) {
                Navigator.of(dialogContext).pop(role);
              } else {
                setState(() => invalid = true);
              }
            },
            child: const Text('ENTER'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return role;
}

Future<bool> requestStaffAccess(BuildContext context) async =>
    await requestStaffRole(context) != null;
