import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart'; // <-- Esto se generará cuando uses FlutterFire CLI

void main() async {
  // 1. Asegura que los bindings de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa Firebase
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform, // Descomenta esto tras configurar FlutterFire
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivia Game',
      theme: ThemeData.dark(),
      home: const Text('Tu pantalla de inicio aquí'), // Cambia por tu pantalla principal
    );
  }
}