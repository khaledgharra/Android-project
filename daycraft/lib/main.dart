import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const DayCraftApp());
}

class DayCraftApp extends StatelessWidget {
  const DayCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DayCraft',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginScreen(),
    );
  }
}