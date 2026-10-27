import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/nav.dart';
import '../models/models.dart';
import '../providers/session_provider.dart';
import 'db.dart';

/// Creates the service request for the chosen mechanic, then jumps to the "Requests" tab.
Future<void> sendRequest(BuildContext context, Draft d, Mech m) async {
  final me = context.read<SessionProvider>().profile!;
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (await Db.motoristHasActive()) {
      messenger.showSnackBar(const SnackBar(content: Text('You already have an active request. Finish or cancel it first.')));
      return;
    }
    await Db.createRequest(d, m, me);
    motoristTab.value = 1;
    nav.popUntil((r) => r.isFirst);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not send the request: $e')));
  }
}
