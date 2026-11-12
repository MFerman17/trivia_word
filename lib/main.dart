import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'widgets/game_transitions.dart';
import 'services/notification_service.dart';
import 'services/asset_catalog.dart';
import 'services/cloud_service.dart';
import 'services/audio_service.dart';
import 'services/locale_service.dart';
import 'services/question_repository.dart';
import 'services/save_service.dart';
import 'services/lives_service.dart';
import 'services/vibration_service.dart';
import 'services/vip_service.dart';
import 'services/age_gate_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    SaveService.onLocalSaveChanged = CloudService.syncFullSave;
    _setUpCrashlytics();
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

  // Lista de imágenes incluidas (para usar otras de reserva si faltan).
  await AssetCatalog.init();
  // Idioma del juego (guardado o el del teléfono) y su banco de preguntas.
  await LocaleService.init();
  await QuestionRepository.load(language: LocaleService.languageCode);
  // Prepara el audio (música en bucle, volumen, silencio guardado).
  await AudioService.init();
  // Vidas globales (suma las que se recargaron con la app cerrada).
  await LivesService.init();
  // Vibración en los golpes (se puede desactivar en Ajustes).
  await VibrationService.init();
  // Avisos locales (vidas llenas, cofre, racha).
  await NotificationService.init();
  // Edad (menor de 13 o no), para pedir los anuncios adecuados.
  await AgeGateService.init();
  // Pase VIP: lee si ya lo tiene y pregunta a Google Play (sin esperar,
  // para no retrasar la portada).
  unawaited(VipService.init());

  runApp(MyApp(initError: initError));
}

/// CRASHLYTICS: si el juego se cierra o falla algo, Firebase recibe el
/// error exacto (pantalla, línea de código, modelo de teléfono). Así se
/// pueden arreglar fallos que los testers o jugadores no saben explicar.
///
/// Solo en Android y en versiones release: en debug los errores ya se ven
/// en la consola de VS Code, y así no se mezclan con los de los jugadores.
/// El ENVÍO empieza apagado (AndroidManifest) y se enciende al saber que
/// el jugador no es menor de 13 (AnalyticsService.applyAge).
void _setUpCrashlytics() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  if (!kReleaseMode) return;
  final crashlytics = FirebaseCrashlytics.instance;
  // Errores de Flutter (al dibujar pantallas).
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  // Errores en código asíncrono que nadie capturó.
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
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
    // Al salir se programan los avisos; al volver, se quitan.
    NotificationService.onLifecycle(state);
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
        theme: ThemeData.dark().copyWith(pageTransitionsTheme: kGamePageTransitions),
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
          // En Chrome la música no puede empezar hasta el primer toque del
          // jugador: en cada toque se comprueba que la música está sonando.
          return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => AudioService.ensureMusicPlaying(),
            child: child ?? const SizedBox.shrink(),
          );
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
