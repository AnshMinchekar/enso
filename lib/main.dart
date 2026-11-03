import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/notifications.dart';
import 'ui/app.dart';
import 'ui/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final onAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final state = AppState(notifications: onAndroid ? LocalNotifications() : const NoNotifications());
  await state.start();
  runApp(EnsoApp(state: state));
}
