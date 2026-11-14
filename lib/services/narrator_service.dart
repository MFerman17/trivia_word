import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../models/chapter_story.dart';
import 'audio_service.dart';

/// NARRADOR: lee en voz alta las historias de los capítulos y los mundos.
///
/// Usa la mejor voz disponible, en este orden:
///   1. Una GRABACIÓN en assets/audio/voice/IDIOMA/story_M_C.mp3
///      (M = mundo, C = capítulo; por ejemplo voice/es/story_1_3.mp3).
///      Es la opción buena: una voz con emoción y misterio de verdad.
///   2. Si no hay grabación, la VOZ DEL TELÉFONO (texto a voz de Android),
///      más grave y más lenta de lo normal para que suene a narrador.
///      Funciona desde ya, sin archivos, pero suena más robótica.
///
/// Mientras habla, la música baja de volumen. Se calla al cerrar la
/// historia, si el jugador silencia los efectos o apaga el narrador en
/// Ajustes.
class NarratorService {
  NarratorService._();

  static const _key = 'narrator_on';

  /// Interruptor de Ajustes ("Voz del narrador").
  static bool enabled = true;

  static final AudioPlayer _voice = AudioPlayer();
  static FlutterTts? _tts;
  static bool _listening = false;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_key) ?? true;
    } catch (_) {}
    // Que la voz suene encima de la música sin pausarla (en Android cada
    // reproductor "pide el turno" del audio si no se le dice lo contrario).
    if (!kIsWeb) {
      try {
        await _voice.setAudioContext(AudioService.effectsContext);
      } catch (_) {}
    }
    // Si el jugador silencia el juego mientras habla, se calla.
    AudioService.mutedNotifier.addListener(() {
      if (AudioService.mutedNotifier.value) stop();
    });
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    if (!value) await stop();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, value);
    } catch (_) {}
  }

  static String get _lang => L10n.current.localeName.startsWith('en') ? 'en' : 'es';

  /// Nombre del archivo grabado de una historia (dentro de assets/audio/).
  static String recordingFor(int world, int chapter, String lang) =>
      'voice/$lang/story_${world}_$chapter.mp3';

  /// Lee la historia que aparece al terminar el capítulo [chapter] del
  /// mundo [world].
  static Future<void> tellStory(int world, int chapter, ChapterStory story) async {
    if (!enabled || !AudioService.sfxOn) return;
    await stop();
    _listenOnce();
    await AudioService.duckMusic(true);
    final file = recordingFor(world, chapter, _lang);
    try {
      if (AudioService.hasAudio(file)) {
        await _voice.play(AssetSource('audio/$file'), volume: AudioService.sfxVolume);
      } else {
        await _speak(story);
      }
    } catch (e) {
      debugPrint('Narrador: no se pudo leer la historia: $e');
      await AudioService.duckMusic(false);
    }
  }

  /// Voz del teléfono. Grave (tono 0,8) y pausada para dar misterio.
  static Future<void> _speak(ChapterStory story) async {
    final tts = _tts ??= FlutterTts();
    await tts.setLanguage(_lang == 'en' ? 'en-US' : 'es-ES');
    // En Android 0,5 es la velocidad normal; en el navegador, 1,0.
    await tts.setSpeechRate(kIsWeb ? 0.85 : 0.42);
    await tts.setPitch(0.8);
    await tts.setVolume(AudioService.sfxVolume);
    // Los puntos y los "…" hacen que la voz se detenga, como un narrador.
    await tts.speak(
      '${story.heading}… ${story.destination}. ${story.narrative} … ${story.objective}',
    );
  }

  /// Al terminar de hablar (grabación o voz del teléfono), la música vuelve
  /// a su volumen.
  static void _listenOnce() {
    if (_listening) return;
    _listening = true;
    _voice.onPlayerComplete.listen((_) => AudioService.duckMusic(false));
    final tts = _tts ??= FlutterTts();
    tts.setCompletionHandler(() => AudioService.duckMusic(false));
    tts.setCancelHandler(() => AudioService.duckMusic(false));
    tts.setErrorHandler((_) => AudioService.duckMusic(false));
  }

  static Future<void> stop() async {
    try {
      await _voice.stop();
    } catch (_) {}
    try {
      await _tts?.stop();
    } catch (_) {}
    await AudioService.duckMusic(false);
  }
}
