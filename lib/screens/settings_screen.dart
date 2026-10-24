import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import '../services/locale_service.dart';
import '../widgets/game_3d.dart';

/// Versión que se muestra al pie de Ajustes.
/// Al publicar una versión nueva, cambiarla aquí y en pubspec.yaml.
const String appVersion = '1.0.0';

/// Pantalla de Ajustes: sonido, idioma y preguntas frecuentes.
///
/// Todo lo que se cambia aquí se aplica al momento y se guarda solo
/// (no hay botón "Guardar"): así el jugador oye el volumen mientras lo mueve.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WM.outline,
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(title: context.l10n.settingsTitle),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  children: [
                    EntranceFlip(index: 0, child: _buildSoundPanel()),
                    const SizedBox(height: 16),
                    EntranceFlip(index: 1, child: _buildLanguagePanel()),
                    const SizedBox(height: 16),
                    EntranceFlip(index: 2, child: _buildFaqPanel()),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        context.l10n.settingsVersion(appVersion),
                        style: GoogleFonts.oswald(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: GoogleFonts.oswald(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      );

  // ---------------------------------------------------------------
  // SONIDO: interruptor + volumen para música y para efectos
  // ---------------------------------------------------------------
  Widget _buildSoundPanel() {
    return Panel3D(
      accent: WM.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context.l10n.settingsSound),
          _soundRow(
            emoji: '🎵',
            label: context.l10n.settingsMusic,
            enabled: AudioService.musicOn,
            volume: AudioService.musicVolume,
            onToggle: (value) async {
              await AudioService.setMusicOn(value);
              if (mounted) setState(() {});
            },
            onVolume: (value) {
              AudioService.setMusicVolume(value);
              setState(() {});
            },
            onVolumeEnd: (value) => AudioService.setMusicVolume(value, save: true),
          ),
          const SizedBox(height: 8),
          _soundRow(
            emoji: '🔊',
            label: context.l10n.settingsEffects,
            enabled: AudioService.sfxOn,
            volume: AudioService.sfxVolume,
            onToggle: (value) async {
              await AudioService.setSfxOn(value);
              if (value) AudioService.playButtonClick();
              if (mounted) setState(() {});
            },
            onVolume: (value) {
              AudioService.setSfxVolume(value);
              setState(() {});
            },
            // Al soltar, suena un efecto de prueba con el volumen elegido.
            onVolumeEnd: (value) {
              AudioService.setSfxVolume(value, save: true);
              AudioService.playButtonClick();
            },
          ),
        ],
      ),
    );
  }

  Widget _soundRow({
    required String emoji,
    required String label,
    required bool enabled,
    required double volume,
    required ValueChanged<bool> onToggle,
    required ValueChanged<double> onVolume,
    required ValueChanged<double> onVolumeEnd,
  }) {
    return Row(
      children: [
        Socket3D(
          size: 44,
          color: enabled ? WM.cyan : const Color(0xFF4A4660),
          child: Text(emoji, style: const TextStyle(fontSize: 19)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.oswald(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  activeTrackColor: WM.cyan,
                  inactiveTrackColor: WM.outline,
                  thumbColor: WM.bone,
                  overlayColor: WM.cyan.withValues(alpha: 0.2),
                  disabledActiveTrackColor: Colors.white24,
                  disabledInactiveTrackColor: WM.outline,
                  disabledThumbColor: Colors.white38,
                ),
                child: Slider(
                  value: volume,
                  // El volumen solo se puede mover con el sonido activado.
                  onChanged: enabled ? onVolume : null,
                  onChangeEnd: enabled ? onVolumeEnd : null,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: onToggle,
          activeThumbColor: WM.bone,
          activeTrackColor: WM.cyan,
          inactiveThumbColor: Colors.white54,
          inactiveTrackColor: WM.outline,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // IDIOMA
  // ---------------------------------------------------------------
  // Solo aparecen los idiomas que tienen textos Y banco de preguntas
  // (ver LocaleService). Al elegir uno, toda la app se redibuja.
  Widget _buildLanguagePanel() {
    final languages = LocaleService.availableLanguages;
    final current = LocaleService.languageCode;

    return Panel3D(
      accent: WM.violet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context.l10n.languageTitle),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final code in languages)
                SizedBox(
                  width: 140,
                  child: Pressable3D(
                    // El idioma activo se ve en verde y no se puede tocar.
                    onTap: code == current ? null : () => _changeLanguage(code),
                    color: WM.cyan,
                    disabledColor: const Color(0xFF1E8C3A),
                    height: 44,
                    child: OutlinedGameText(
                      LocaleService.nativeNames[code] ?? code.toUpperCase(),
                      size: 16,
                      font: GameFont.oswald,
                    ),
                  ),
                ),
            ],
          ),
          if (languages.length < 2) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.moreLanguagesSoon,
              style: GoogleFonts.oswald(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _changeLanguage(String code) async {
    AudioService.playSelect();
    await LocaleService.setLanguage(code);
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------
  // PREGUNTAS FRECUENTES: se despliegan al tocarlas
  // ---------------------------------------------------------------
  Widget _buildFaqPanel() {
    final l10n = context.l10n;
    final faqs = [
      (l10n.faqSoundQ, l10n.faqSoundA),
      (l10n.faqProgressQ, l10n.faqProgressA),
      (l10n.faqAdQ, l10n.faqAdA),
      (l10n.faqCoinsQ, l10n.faqCoinsA),
      (l10n.faqRepeatQ, l10n.faqRepeatA),
      (l10n.faqRankingQ, l10n.faqRankingA),
      (l10n.faqLanguageQ, l10n.faqLanguageA),
      (l10n.faqErrorQ, l10n.faqErrorA),
      (l10n.faqCrashQ, l10n.faqCrashA),
    ];

    return Panel3D(
      accent: WM.gold,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l10n.settingsHelp),
          // Theme quita las líneas que ExpansionTile dibuja por defecto.
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (final (question, answer) in faqs)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    iconColor: WM.gold,
                    collapsedIconColor: Colors.white54,
                    expandedAlignment: Alignment.centerLeft,
                    onExpansionChanged: (open) {
                      if (open) AudioService.playPageFlip();
                    },
                    title: Text(
                      question,
                      style: GoogleFonts.oswald(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    children: [
                      Text(
                        answer,
                        style: GoogleFonts.oswald(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
