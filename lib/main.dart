import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const TriviaWordApp());
}

class TriviaWordApp extends StatelessWidget {
  const TriviaWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TriviaWord',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}