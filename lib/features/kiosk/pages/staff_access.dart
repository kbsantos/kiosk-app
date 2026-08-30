import 'package:flutter/material.dart';
import '../staff_access.dart';

Future<bool> requestStaffAccess(BuildContext context) async =>
    await requestStaffRole(context) != null;
