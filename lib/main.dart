import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // 👈 Descomentado

void main() async {
  // 1. Asegura que los bindings de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa Firebase usando las opciones de tu archivo configurado
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // 👈 Descomentado
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