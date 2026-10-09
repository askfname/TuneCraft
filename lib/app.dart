import 'package:flutter/material.dart';

import 'ui/screens/tuner_screen.dart';
import 'ui/theme/app_theme.dart';

/// App 入口（Riverpod ProviderScope 在 main 中包）
class TuneCraftApp extends StatelessWidget {
  const TuneCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuneCraft 吉他调音',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const TunerScreen(),
    );
  }
}
