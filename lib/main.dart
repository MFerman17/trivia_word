import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart'; // 👈 Importa tu pantalla de inicio

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  if (firebaseApiKey.isEmpty) {
    throw StateError(
      'Falta FIREBASE_API_KEY. Ejecuta Flutter con '
      '--dart-define=FIREBASE_API_KEY=TU_CLAVE_WEB_DE_FIREBASE.',
    );
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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