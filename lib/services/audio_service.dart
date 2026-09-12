import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioPlayer _bgmPlayer = AudioPlayer();
  static final AudioPlayer _sfxPlayer = AudioPlayer();

  static bool isMuted = false;

  /// Inicializar configuraciones de audio (BGM en bucle)
  static Future<void> init() async {
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('🎵 Error al inicializar AudioService: $e');
    }
  }

  /// Reproducir música de fondo (BGM)
  static Future<void> playBgm(String soundFileName) async {
    if (isMuted) return;
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.play(AssetSource('audio/$soundFileName'));
    } catch (e) {
      debugPrint('🎵 Error al reproducir BGM ($soundFileName): $e');
    }
  }

  /// Detener música de fondo
  static Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (e) {
      debugPrint('🎵 Error al detener BGM: $e');
    }
  }

  /// Reproducir efectos de sonido (SFX)
  static Future<void> playSfx(String soundFileName) async {
    if (isMuted) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('audio/$soundFileName'));
    } catch (e) {
      debugPrint('🔊 Error al reproducir SFX ($soundFileName): $e');
    }
  }

  // --- Métodos de efectos de sonido individuales ---

  /// Sonido al responder correctamente una pregunta
  static Future<void> playSuccess() => playSfx('success.mp3');

  /// Sonido al fallar o recibir daño
  static Future<void> playDamage() => playSfx('damage.mp3');

  /// Sonido al ganar un nivel / pantalla de victoria
  static Future<void> playVictorySound() => playSfx('victory.mp3');

  /// Sonido al atacar o golpear
  static Future<void> playAttackSound() => playSfx('attack.mp3');

  /// Sonido al pulsar botones o elementos de la interfaz
  static Future<void> playButtonClick() => playSfx('click.mp3');

  /// Sonido al comprar un objeto en la tienda
  static Future<void> playBuyItem() => playSfx('buy.mp3');

  /// Sonido al usar una poción de vida
  static Future<void> playPotionUse() => playSfx('potion.mp3');

  /// Sonido al utilizar una pista para descartar opciones
  static Future<void> playHintUse() => playSfx('hint.mp3');

  // --- Control de Mute / Unmute ---

  /// Alternar silencio global (BGM y SFX)
  static void toggleMute() {
    isMuted = !isMuted;
    if (isMuted) {
      _bgmPlayer.pause();
      _sfxPlayer.stop();
    } else {
      _bgmPlayer.resume();
    }
  }
}
