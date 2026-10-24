import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Música y efectos de sonido del juego.
///
/// Ideas principales:
///  - Cada pantalla tiene su música (portada, mapa, combate, jefe). Si se pide
///    la misma que ya suena, no se reinicia.
///  - Al cambiar de pantalla rápido, solo gana la ÚLTIMA música pedida
///    (ver [_bgmRequest]); así no se queda sonando la del mapa en el combate.
///  - Los efectos usan varios reproductores en rueda, así pueden sonar dos a la
///    vez (por ejemplo, el acierto y el golpe al monstruo) sin cortarse.
///  - Si falta un archivo de audio, se usa otro de reserva y el juego sigue.
///  - Música y efectos tienen interruptor y volumen propios (pantalla Ajustes)
///    y se recuerdan al cerrar la app.
class AudioService {
  AudioService._();

  static final AudioPlayer _bgmPlayer = AudioPlayer();
  static final List<AudioPlayer> _sfxPlayers =
      List.generate(4, (_) => AudioPlayer());
  static int _nextSfx = 0;

  // --- Preferencias guardadas ---
  static const String _musicOnKey = 'audio_music_on';
  static const String _sfxOnKey = 'audio_sfx_on';
  static const String _musicVolumeKey = 'audio_music_volume';
  static const String _sfxVolumeKey = 'audio_sfx_volume';
  static const String _legacyMuteKey = 'audio_muted'; // versión anterior

  static bool musicOn = true;
  static bool sfxOn = true;
  static double musicVolume = 0.45;
  static double sfxVolume = 1.0;

  /// "Silencio total": lo usan los botones de altavoz del mapa y del combate.
  static bool get isMuted => !musicOn && !sfxOn;

  static String? _currentTrack;
  static List<String> _currentFallbacks = const [];
  static bool _initialized = false;

  /// Número de la última petición de música. Cada [playBgm] lo incrementa y,
  /// tras cada espera, comprueba que nadie ha pedido otra música mientras.
  static int _bgmRequest = 0;

  // --- Pistas de música ---
  static const String menuMusic = 'bg_music.mp3';
  static const String mapMusic = 'map_bgm.mp3'; // nueva (pendiente)
  static const String oldMapMusic = 'game_bgm.mp3'; // reserva del mapa
  static const String battleMusic = 'battle_bgm.mp3';
  static const String bossMusic = 'boss_bgm.mp3';

  /// Prepara los reproductores y recupera las preferencias guardadas.
  /// Se llama una vez al arrancar la app (main.dart).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyMuted = prefs.getBool(_legacyMuteKey) ?? false;
      musicOn = prefs.getBool(_musicOnKey) ?? !legacyMuted;
      sfxOn = prefs.getBool(_sfxOnKey) ?? !legacyMuted;
      musicVolume = prefs.getDouble(_musicVolumeKey) ?? musicVolume;
      sfxVolume = prefs.getDouble(_sfxVolumeKey) ?? sfxVolume;

      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(musicVolume);
      for (final player in _sfxPlayers) {
        await player.setReleaseMode(ReleaseMode.stop);
      }
    } catch (e) {
      debugPrint('🎵 Error al inicializar AudioService: $e');
    }
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicOnKey, musicOn);
      await prefs.setBool(_sfxOnKey, sfxOn);
      await prefs.setDouble(_musicVolumeKey, musicVolume);
      await prefs.setDouble(_sfxVolumeKey, sfxVolume);
    } catch (e) {
      debugPrint('🎵 No se pudieron guardar los ajustes de audio: $e');
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
    if (_currentTrack == soundFileName &&
        _bgmPlayer.state == PlayerState.playing) {
      return; // Ya está sonando: no la reiniciamos.
    }
    final request = ++_bgmRequest;
    _currentTrack = soundFileName;
    _currentFallbacks = fallbacks;
    if (!musicOn) {
      await _bgmPlayer.stop();
      return; // Se recuerda la pista para cuando se active la música.
    }

    for (final file in [soundFileName, ...fallbacks]) {
      try {
        await _bgmPlayer.stop();
        if (request != _bgmRequest) return; // Ya se pidió otra música.
        await _bgmPlayer.play(AssetSource('audio/$file'), volume: musicVolume);
        return;
      } catch (e) {
        debugPrint('🎵 No se pudo reproducir la música $file: $e');
      }
    }
  }

  static Future<void> stopBgm() async {
    _bgmRequest++;
    _currentTrack = null;
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('🎵 Error al detener la música: $e');
    }
  }

  /// Vuelve a lanzar la música actual si no está sonando.
  ///
  /// Los navegadores (Chrome) no dejan sonar nada hasta que el usuario toca
  /// la pantalla. main.dart llama a esto en cada toque, así la música de la
  /// portada empieza en cuanto el jugador interactúa.
  static Future<void> ensureMusicPlaying() async {
    final track = _currentTrack;
    if (!musicOn || track == null) return;
    if (_bgmPlayer.state == PlayerState.playing) return;
    _currentTrack = null;
    await playBgm(track, fallbacks: _currentFallbacks);
  }

  /// Pausa y reanuda la música cuando la app pasa a segundo plano y vuelve.
  static Future<void> pauseForBackground() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  static Future<void> resumeFromBackground() async {
    if (!musicOn || _currentTrack == null) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  // Música de cada pantalla, con reservas mientras no existan los archivos.
  static Future<void> playMenuMusic() =>
      playBgm(menuMusic, fallbacks: [oldMapMusic]);
  static Future<void> playMapMusic() =>
      playBgm(mapMusic, fallbacks: [oldMapMusic]);
  static Future<void> playBattleMusic({bool boss = false}) => boss
      ? playBgm(bossMusic, fallbacks: [battleMusic, oldMapMusic])
      : playBgm(battleMusic, fallbacks: [oldMapMusic]);

  // =================================================================
  // EFECTOS
  // =================================================================

  /// Reproduce un efecto. Si el archivo no existe, prueba con [fallback].
  static Future<void> playSfx(String soundFileName, {String? fallback}) async {
    if (!sfxOn || sfxVolume <= 0) return;
    final player = _sfxPlayers[_nextSfx];
    _nextSfx = (_nextSfx + 1) % _sfxPlayers.length;
    for (final file in [soundFileName, ?fallback]) {
      try {
        await player.stop();
        await player.play(AssetSource('audio/$file'), volume: sfxVolume);
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
    Future.delayed(const Duration(milliseconds: 180), () => playMonsterHit());
  }

  /// Fallo: sonido de error y el daño que recibe el jugador.
  static Future<void> playWrong() async {
    await playSfx('wrong.mp3', fallback: 'damage.mp3');
    Future.delayed(const Duration(milliseconds: 150), () => playDamage());
  }

  static Future<void> playDamage() => playSfx('damage.mp3');
  static Future<void> playAttackSound() => playSfx('attack.mp3');
  static Future<void> playMonsterHit() =>
      playSfx('monster_hit.mp3', fallback: 'attack.mp3');

  /// Rugido del monstruo al empezar la batalla (los jefes, con su intro).
  static Future<void> playBattleStart({bool boss = false}) => boss
      ? playSfx('boss_intro.mp3', fallback: 'monster_roar.mp3')
      : playSfx('monster_roar.mp3');

  /// Aviso de que al jugador le queda una sola vida.
  static Future<void> playLowHealth() => playSfx('low_health.mp3');

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

  static Future<void> playLevelUp() => playSfx('level_up.mp3');

  /// Volver a la batalla tras ver el video o usar una poción.
  static Future<void> playRevive() => playSfx('revive.mp3', fallback: 'potion.mp3');

  static Future<void> playPotionUse() => playSfx('potion.mp3');
  static Future<void> playHintUse() => playSfx('hint.mp3');

  // --- Interfaz, mapa y tienda ---
  static Future<void> playButtonClick() => playSfx('click.mp3');

  /// Al tocar un nivel del mapa.
  static Future<void> playNodeSelect() =>
      playSfx('node_select.mp3', fallback: 'click.mp3');

  /// Al pasar de página en las historias o abrir un panel.
  static Future<void> playPageFlip() => playSfx('page_flip.mp3');

  /// Al tocar una casilla de la tienda (personaje, marco, accesorio).
  static Future<void> playSelect() => playSfx('select.mp3', fallback: 'button_click.mp3');

  /// Al equipar un aspecto que ya tienes.
  static Future<void> playEquip() => playSfx('equip.mp3', fallback: 'buy.mp3');

  static Future<void> playBuyItem() => playSfx('buy.mp3');

  /// Monedas o premios: misiones, recompensas por anuncio.
  static Future<void> playCoins() => playSfx('coins.mp3', fallback: 'buy.mp3');

  /// Cofre diario de la portada.
  static Future<void> playChestOpen() =>
      playSfx('chest_open.mp3', fallback: 'coins.mp3');

  /// Al entrar al ranking (aparece el podio).
  static Future<void> playPodium() => playSfx('podium.mp3');

  // =================================================================
  // AJUSTES
  // =================================================================

  static Future<void> setMusicOn(bool value) async {
    musicOn = value;
    if (!value) {
      await _bgmPlayer.pause();
    } else {
      await ensureMusicPlaying();
    }
    await _save();
  }

  static Future<void> setSfxOn(bool value) async {
    sfxOn = value;
    if (!value) {
      for (final player in _sfxPlayers) {
        player.stop();
      }
    }
    await _save();
  }

  /// Cambia el volumen al momento (mientras se arrastra el control).
  /// [save] = true al soltar el dedo, para no escribir en disco a cada paso.
  static Future<void> setMusicVolume(double value, {bool save = false}) async {
    musicVolume = value.clamp(0.0, 1.0);
    try {
      await _bgmPlayer.setVolume(musicVolume);
    } catch (_) {}
    if (save) await _save();
  }

  static Future<void> setSfxVolume(double value, {bool save = false}) async {
    sfxVolume = value.clamp(0.0, 1.0);
    if (save) await _save();
  }

  /// Botón de altavoz: silencia o activa todo (música y efectos).
  static void toggleMute() {
    final turnOn = isMuted;
    setSfxOn(turnOn);
    setMusicOn(turnOn);
  }
}
