import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🔥 Firebase inicializado correctamente');
    if (kDebugMode) {
      final o = Firebase.app().options;
      debugPrint('apiKey length=${o.apiKey.length}, '
          'appId=${o.appId}, projectId=${o.projectId}');
    }
  } catch (e, st) {
    initError = e;
    debugPrint('❌ Error al inicializar Firebase: $e\n$st');
  }

  runApp(MyApp(initError: initError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initError});

  final Object? initError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivia Word',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: initError == null
          ? const HomeScreen()
          : Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No se pudo iniciar la app:\n$initError'),
                ),
              ),
            ),
    );
  }
}