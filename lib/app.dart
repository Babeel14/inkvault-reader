import 'package:flutter/material.dart';

import 'screens/library_screen.dart';
import 'theme.dart';

class InkVaultApp extends StatelessWidget {
  const InkVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InkVault Reader',
      debugShowCheckedModeBanner: false,
      theme: InkTheme.dark(),
      home: const LibraryScreen(),
    );
  }
}
