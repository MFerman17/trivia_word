import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import '../services/cloud_service.dart';
import '../services/lives_service.dart';
import '../services/locale_service.dart';
import '../services/question_repository.dart';
import '../services/vibration_service.dart';
import '../widgets/game_3d.dart';
import 'home_screen.dart';

/// Dirección pública de la política de privacidad (GitHub Pages, carpeta docs/).
const String privacyPolicyUrl = 'https://mferman17.github.io/trivia_word/privacidad.html';

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
  /// Botón de privacidad de anuncios: solo donde Google lo exige (Europa).
  bool _showAdPrivacy = false;

  @override
  void initState() {
    super.initState();
    AdService.privacyOptionsRequired().then((required) {
      if (mounted && required) setState(() => _showAdPrivacy = true);
    });
  }

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
                    const SizedBox(height: 16),
                    EntranceFlip(index: 3, child: _buildDataPanel()),
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
          const SizedBox(height: 8),
          // Vibración: al activarla, el teléfono da un golpe de prueba.
          Row(
            children: [
              Socket3D(
                size: 44,
                color: VibrationService.enabled ? WM.cyan : const Color(0xFF4A4660),
                child: const Text('📳', style: TextStyle(fontSize: 19)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.settingsVibration,
                  style: GoogleFonts.oswald(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Switch(
                value: VibrationService.enabled,
                onChanged: (value) async {
                  await VibrationService.setEnabled(value);
                  if (mounted) setState(() {});
                },
                activeThumbColor: WM.bone,
                activeTrackColor: WM.cyan,
                inactiveThumbColor: Colors.white54,
                inactiveTrackColor: WM.outline,
              ),
            ],
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
  // CUENTA Y DATOS: política de privacidad y borrado de datos.
  // Google Play exige que el jugador pueda borrar sus datos desde la app.
  // ---------------------------------------------------------------
  Widget _buildDataPanel() {
    const danger = Color(0xFFFF4D5E);
    return Panel3D(
      accent: danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context.l10n.settingsData),
          Text(
            context.l10n.privacyPolicyLabel,
            style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
          ),
          // Seleccionable para poder copiar la dirección.
          SelectableText(
            privacyPolicyUrl,
            style: GoogleFonts.oswald(color: WM.cyan, fontSize: 13),
          ),
          if (_showAdPrivacy) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Pressable3D(
                onTap: AdService.showPrivacyOptions,
                color: WM.violet,
                height: 42,
                child: OutlinedGameText(
                  context.l10n.adPrivacyOptions,
                  size: 15,
                  font: GameFont.oswald,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Pressable3D(
              onTap: _deleting ? null : _confirmDeleteData,
              color: danger,
              height: 46,
              child: _deleting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 3, color: WM.outline),
                    )
                  : OutlinedGameText(context.l10n.deleteData, size: 16, font: GameFont.oswald),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.deleteDataHint,
            style: GoogleFonts.oswald(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  bool _deleting = false;

  Future<void> _confirmDeleteData() async {
    const danger = Color(0xFFFF4D5E);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Panel3D(
          accent: danger,
          radius: 22,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedGameText(
                context.l10n.deleteDataConfirmTitle,
                size: 24,
                colors: const [Color(0xFFFFB3BA), danger],
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.deleteDataConfirmBody,
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: Pressable3D(
                  onTap: () => Navigator.of(dialogContext).pop(true),
                  color: danger,
                  height: 46,
                  child: OutlinedGameText(
                    context.l10n.deleteDataConfirm,
                    size: 16,
                    font: GameFont.oswald,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  context.l10n.cancel,
                  style: GoogleFonts.oswald(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final ok = await CloudService.deleteAllData();
    if (!mounted) return;
    if (!ok) {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deleteDataFailed)),
      );
      return;
    }
    // Vuelve a cargar lo que estaba en memoria (vidas e historial de preguntas).
    await LivesService.init();
    await QuestionRepository.load(language: LocaleService.languageCode);
    if (!mounted) return;
    final message = context.l10n.deleteDataDone;
    // Empieza de nuevo desde la portada, sin pantallas anteriores.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
