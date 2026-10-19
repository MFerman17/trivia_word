import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'services/cloud_service.dart';
import 'services/audio_service.dart';
import 'services/locale_service.dart';
import 'services/question_repository.dart';
import 'services/save_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    SaveService.onLocalSaveChanged = CloudService.syncFullSave;
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

  // Idioma del juego (guardado o el del teléfono) y su banco de preguntas.
  await LocaleService.init();
  await QuestionRepository.load(language: LocaleService.languageCode);
  // Prepara el audio (música en bucle, volumen, silencio guardado).
  await AudioService.init();

  runApp(MyApp(initError: initError));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initError});

  final Object? initError;

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Vigila si la app pasa a segundo plano para pausar la música
/// (por ejemplo, al recibir una llamada o cambiar de app).
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      AudioService.pauseForBackground();
    } else if (state == AppLifecycleState.resumed) {
      AudioService.resumeFromBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initError = widget.initError;
    // Al cambiar de idioma en el Perfil, toda la app se redibuja.
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService.locale,
      builder: (context, locale, _) => MaterialApp(
        title: 'Words & Monsters',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        locale: locale,
        supportedLocales: LocaleService.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Guarda los textos actuales para el código sin `context`.
        builder: (context, child) {
          L10n.current = AppLocalizations.of(context);
          return child ?? const SizedBox.shrink();
        },
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
      ),
    );
  }
}
