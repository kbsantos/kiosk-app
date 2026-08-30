import 'package:flutter/material.dart';

import 'kiosk_staff_access_repository.dart';

class KioskStaffGate {
  static final KioskStaffAccessRepository _repository =
      KioskStaffAccessRepository();

  /// Staff access is cached for one 30-minute in-app session.
  static const Duration sessionDuration = Duration(minutes: 30);
  static DateTime? _sessionExpiresAt;

  static bool get isSessionActive =>
      _sessionExpiresAt != null && DateTime.now().isBefore(_sessionExpiresAt!);

  static void endSession() {
    _sessionExpiresAt = null;
  }

  static Future<bool> requirePin(BuildContext context) async {
    if (isSessionActive) return true;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StaffPinDialog(repository: _repository),
    );

    return result == true;
  }
}

class _StaffPinDialog extends StatefulWidget {
  const _StaffPinDialog({
    required this.repository,
  });

  final KioskStaffAccessRepository repository;

  @override
  State<_StaffPinDialog> createState() => _StaffPinDialogState();
}

class _StaffPinDialogState extends State<_StaffPinDialog> {
  late final TextEditingController _controller;
  bool _obscure = true;
  bool _busy = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    final pin = _controller.text.trim();

    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() {
        _errorText = 'Enter exactly 4 digits.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorText = null;
    });

    final valid = await widget.repository.verifyPin(pin);

    if (!mounted) return;

    if (valid) {
      KioskStaffGate._sessionExpiresAt =
          DateTime.now().add(KioskStaffGate.sessionDuration);
      Navigator.of(context).pop(true);
      return;
    }

    _controller.clear();

    setState(() {
      _busy = false;
      _errorText = 'Incorrect PIN.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'STAFF ACCESS',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the 4-digit staff PIN to start a 30-minute staff session.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: _obscure,
            maxLength: 4,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Staff PIN',
              border: const OutlineInputBorder(),
              counterText: '',
              errorText: _errorText,
              suffixIcon: IconButton(
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Staff functions include settings, order queue, history, cancellation and refunds.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFC69214),
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('UNLOCK'),
        ),
      ],
    );
  }
}
