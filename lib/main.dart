import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/app_type.dart';
import 'theme.dart';
import 'widgets/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Locking orientation avoids a camera re-configure on rotation, which is the
  // slowest thing that can happen mid-scan.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
    ),
  );
  runApp(const QrScannerApp());
}

class QrScannerApp extends StatefulWidget {
  const QrScannerApp({super.key});

  @override
  State<QrScannerApp> createState() => _QrScannerAppState();
}

class _QrScannerAppState extends State<QrScannerApp> {
  AppType? _appType;

  void _onAppTypeChanged(AppType? appType) {
    if (_appType == appType) return;
    setState(() => _appType = appType);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Scanner',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(_appType ?? AppType.food),
      home: AuthGate(onAppTypeChanged: _onAppTypeChanged),
    );
  }
}
