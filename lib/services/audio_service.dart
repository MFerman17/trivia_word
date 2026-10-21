import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Música y efectos de sonido del juego.
///
/// Ideas principales:
///  - Cada pantalla tiene su música (portada, mapa, combate, jefe). Si se pide
///    la misma que ya suena, no se reinicia.
///  - Los efectos usan varios reproductores en rueda, así pueden sonar dos a la
///    vez (por ejemplo, el acierto y el golpe al monstruo) sin cortarse.
///  - Si falta un archivo de audio, se usa otro de reserva y el juego sigue.
///    Así se pueden ir añadiendo los sonidos nuevos poco a poco.
///  - El botón de silencio se recuerda al cerrar la app.
class AudioService {
  AudioService._();

  static final AudioPlayer _bgmPlayer = AudioPlayer();
  static final List<AudioPlayer> _sfxPlayers =
      List.generate(4, (_) => AudioPlayer());
  static int _nextSfx = 0;

  static const double _musicVolume = 0.45;
  static const double _sfxVolume = 1.0;
  static const String _muteKey = 'audio_muted';

  static bool isMuted = false;
  static String? _currentTrack;
  static bool _initialized = false;

  // --- Pistas de música ---
  static const String menuMusic = 'menu_bgm.mp3';
  static const String mapMusic = 'game_bgm.mp3';
  static const String battleMusic = 'battle_bgm.mp3';
  static const String bossMusic = 'boss_bgm.mp3';

  /// Prepara los reproductores y recupera el silencio guardado.
  /// Se llama una vez al arrancar la app (main.dart).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(_musicVolume);
      for (final player in _sfxPlayers) {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(_sfxVolume);
      }
      final prefs = await SharedPreferences.getInstance();
      isMuted = prefs.getBool(_muteKey) ?? false;
    } catch (e) {
      debugPrint('🎵 Error al inicializar AudioService: $e');
    }
  }

  // =================================================================
  // MÚSICA
  // =================================================================

  /// Pone la música de una pantalla. Si [soundFileName] no existe todavía,
  /// prueba con las de [fallbacks] en orden.
  static Future<void> playBgm(
    String soundFileName, {
    List<String> fallbacks = const [],
  }) async {
    if (_currentTrack == soundFileName && _bgmPlayer.state == PlayerState.playing) {
      return; // Ya está sonando: no la reiniciamos.
    }
    _currentTrack = soundFileName;
    if (isMuted) return; // Se recuerda la pista para cuando se quite el silencio.

    for (final file in [soundFileName, ...fallbacks]) {
      try {
        await _bgmPlayer.stop();
        await _bgmPlayer.play(AssetSource('audio/$file'), volume: _musicVolume);
        return;
      } catch (e) {
        debugPrint('🎵 No se pudo reproducir la música $file: $e');
      }
    }
  }

  static Future<void> stopBgm() async {
    _currentTrack = null;
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('🎵 Error al detener la música: $e');
    }
  }

  /// Pausa y reanuda la música cuando la app pasa a segundo plano y vuelve.
  static Future<void> pauseForBackground() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  static Future<void> resumeFromBackground() async {
    if (isMuted || _currentTrack == null) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  // Música de cada pantalla, con reservas mientras no existan los archivos.
  static Future<void> playMenuMusic() =>
      playBgm(menuMusic, fallbacks: ['bg_music.mp3', mapMusic]);
  static Future<void> playMapMusic() => playBgm(mapMusic);
  static Future<void> playBattleMusic({bool boss = false}) => boss
      ? playBgm(bossMusic, fallbacks: [battleMusic, mapMusic])
      : playBgm(battleMusic, fallbacks: [mapMusic]);

  // =================================================================
  // EFECTOS
  // =================================================================

  /// Reproduce un efecto. Si el archivo no existe, prueba con [fallback].
  static Future<void> playSfx(String soundFileName, {String? fallback}) async {
    if (isMuted) return;
    final player = _sfxPlayers[_nextSfx];
    _nextSfx = (_nextSfx + 1) % _sfxPlayers.length;
    for (final file in [soundFileName, ?fallback]) {
      try {
        await player.stop();
        await player.play(AssetSource('audio/$file'), volume: _sfxVolume);
        return;
      } catch (e) {
        debugPrint('🔊 No se pudo reproducir el efecto $file: $e');
      }
    }
  }

  // --- Combate ---
  /// Acierto: sonido de acierto y, un instante después, el golpe al monstruo.
  static Future<void> playSuccess() async {
    await playSfx('success.mp3');
    Future.delayed(const Duration(milliseconds: 180), () => playAttackSound());
  }

  /// Fallo: sonido de error y el daño que recibe el jugador.
  static Future<void> playWrong() async {
    await playSfx('wrong.mp3', fallback: 'damage.mp3');
    Future.delayed(const Duration(milliseconds: 150), () => playDamage());
  }

  static Future<void> playDamage() => playSfx('damage.mp3');
  static Future<void> playAttackSound() => playSfx('attack.mp3');

  /// Victoria: se detiene la música para que destaque la fanfarria.
  static Future<void> playVictorySound() async {
    await stopBgm();
    await playSfx('victory.mp3');
  }

  /// Derrota (al quedarse sin vidas o perder la batalla).
  static Future<void> playDefeatSound() async {
    await stopBgm();
    await playSfx('defeat.mp3', fallback: 'damage.mp3');
  }

  /// Cada estrella que aparece en la pantalla de victoria.
  static Future<void> playStar() => playSfx('star.mp3', fallback: 'success.mp3');

  /// Volver a la batalla tras ver el video o usar una poción.
  static Future<void> playRevive() => playSfx('revive.mp3', fallback: 'potion.mp3');

  static Future<void> playPotionUse() => playSfx('potion.mp3');
  static Future<void> playHintUse() => playSfx('hint.mp3');

  // --- Interfaz y tienda ---
  static Future<void> playButtonClick() => playSfx('click.mp3');

  /// Al tocar una casilla de la tienda (personaje, marco, accesorio).
  static Future<void> playSelect() => playSfx('select.mp3', fallback: 'button_click.mp3');

  /// Al equipar un aspecto que ya tienes.
  static Future<void> playEquip() => playSfx('equip.mp3', fallback: 'buy.mp3');

  static Future<void> playBuyItem() => playSfx('buy.mp3');

  /// Monedas o premios: cofre diario, misiones, recompensas por anuncio.
  static Future<void> playCoins() => playSfx('coins.mp3', fallback: 'buy.mp3');

  // =================================================================
  // SILENCIO
  // =================================================================

  /// Activa o quita el silencio de todo (música y efectos) y lo recuerda.
  static void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      _bgmPlayer.pause();
      for (final player in _sfxPlayers) {
        player.stop();
      }
    } else if (_currentTrack != null) {
      final track = _currentTrack!;
      _currentTrack = null; // Para que playBgm no crea que ya está sonando.
      if (track == bossMusic) {
        playBattleMusic(boss: true);
      } else if (track == battleMusic) {
        playBattleMusic();
      } else if (track == menuMusic) {
        playMenuMusic();
      } else {
        playBgm(track);
      }
    }
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_muteKey, isMuted))
        .catchError((_) => false);
  }
}
