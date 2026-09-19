import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart'; // 👈 Importa tu pantalla de inicio

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("🔥 Firebase inicializado correctamente");
  } catch (e) {
    debugPrint("❌ Error al inicializar Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivia Game',
      debugShowCheckedModeBanner: false, // Oculta la etiqueta de debug si gustas
      theme: ThemeData.dark(),
      home: const HomeScreen(), // 👈 Reemplazado por tu menú principal real
    );
  }
}