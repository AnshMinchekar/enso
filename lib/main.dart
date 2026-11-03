import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/app.dart';
import 'ui/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = AppState();
  await state.start();
  runApp(EnsoApp(state: state));
}
