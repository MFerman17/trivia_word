import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player_profile.dart';
import '../services/save_service.dart';
import '../services/cloud_service.dart';
import '../widgets/player_avatar.dart';
import '../widgets/game_3d.dart';
import '../l10n/l10n.dart';
import '../services/audio_service.dart';
import '../services/locale_service.dart';

class ProfileScreen extends StatefulWidget {
  final PlayerProfile? playerProfile;

  const ProfileScreen({super.key, this.playerProfile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late PlayerProfile _profile;
  bool _isLoading = true;
  bool _isLinkingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (widget.playerProfile != null) {
      setState(() {
        _profile = widget.playerProfile!;
        _isLoading = false;
      });
    } else {
      final loaded = await SaveService.loadPlayerData();
      if (!mounted) return;
      setState(() {
        _profile = loaded;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: WM.outline,
        body: Center(child: CircularProgressIndicator(color: WM.cyan)),
      );
    }

    return Scaffold(
      backgroundColor: WM.outline,
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(title: context.l10n.profileTitle),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  child: Column(
                    children: [
                      _buildHero(),
                      const SizedBox(height: 18),
                      EntranceFlip(index: 0, child: _buildXpPanel()),
                      const SizedBox(height: 16),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      EntranceFlip(index: 5, child: _buildGoogleButton()),
                      const SizedBox(height: 16),
                      EntranceFlip(index: 6, child: _buildLanguagePanel()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // HÉROE: avatar flotando sobre un pedestal 3D + insignia de nivel
  // ---------------------------------------------------------------
  Widget _buildHero() {
    return Column(
      children: [
        SizedBox(
          width: 240,
          height: 200,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Halo de luz detrás del personaje
              Positioned(
                bottom: 28,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [WM.cyan.withValues(alpha: 0.32), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: CustomPaint(size: const Size(200, 56), painter: PedestalPainter()),
              ),
              Positioned(
                bottom: 32,
                child: Bob(
                  amplitude: 7,
                  child: PlayerAvatar(profile: _profile, radius: 60),
                ),
              ),
              Positioned(
                bottom: 14,
                right: 4,
                child: _buildLevelBadge(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedGameText(_profile.name, size: 30, letterSpacing: 1.5),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            Chip3D(emoji: '🎖️', text: context.l10n.rankRecruit, accent: WM.gold),
            Chip3D(emoji: '⭐', text: context.l10n.starsCount(_profile.totalStars), accent: WM.cyan),
          ],
        ),
      ],
    );
  }

  // Placa dorada inclinada. La sombra SIN desenfoque (blurRadius 0)
  // dibuja un canto sólido debajo: el truco más barato para dar volumen.
  Widget _buildLevelBadge() {
    return Transform(
      transform: Matrix4.skewX(WM.skew),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: WM.outline, width: 2.5),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE37A), Color(0xFFFFB627), Color(0xFFFF9D00)],
            stops: [0, 0.5, 1],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0xFF9A4F00), offset: Offset(0, 5)),
            BoxShadow(color: Colors.black54, offset: Offset(0, 9), blurRadius: 10),
          ],
        ),
        child: Transform(
          transform: Matrix4.skewX(-WM.skew),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OutlinedGameText(context.l10n.levelShort, size: 13, font: GameFont.oswald),
              const SizedBox(width: 4),
              OutlinedGameText('${_profile.level}', size: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // EXPERIENCIA
  // ---------------------------------------------------------------
  Widget _buildXpPanel() {
    final int currentXp = _profile.experience;
    final int maxLevelXp = _profile.maxExperienceForCurrentLevel;
    final int missing = math.max(0, maxLevelXp - currentXp);

    return Panel3D(
      accent: WM.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.levelProgress,
                style: GoogleFonts.oswald(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                context.l10n.nextLevel(_profile.level + 1),
                style: GoogleFonts.oswald(
                  color: WM.cyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Bar3D(
            value: _profile.levelProgress,
            height: 24,
            label: context.l10n.xpProgress(currentXp, maxLevelXp),
          ),
          const SizedBox(height: 8),
          Text(
            missing == 0 ? context.l10n.readyToLevelUp : context.l10n.xpMissing(missing),
            style: GoogleFonts.oswald(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // RECURSOS
  // ---------------------------------------------------------------
  Widget _buildStatsGrid() {
    final stats = [
      ('🪙', context.l10n.statCoins, _profile.coins, WM.gold),
      ('💎', context.l10n.statGems, _profile.gems, WM.cyan),
      ('🧪', context.l10n.statPotions, _profile.healthPotions, const Color(0xFF5BE37A)),
      ('💡', context.l10n.statHints, _profile.letterHints, const Color(0xFFFF9D4D)),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 14,
      childAspectRatio: 1.55,
      children: [
        for (var i = 0; i < stats.length; i++)
          EntranceFlip(
            index: i + 1,
            child: _buildStatCard(
              emoji: stats[i].$1,
              title: stats[i].$2,
              value: stats[i].$3,
              color: stats[i].$4,
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required String emoji,
    required String title,
    required int value,
    required Color color,
  }) {
    return Panel3D(
      accent: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Socket3D(
            size: 48,
            color: color,
            child: Text(emoji, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.oswald(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                OutlinedGameText(
                  '$value',
                  size: 24,
                  colors: [Colors.white, shade(color, 0.15)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // GUARDAR EN GOOGLE
  // ---------------------------------------------------------------
  Widget _buildGoogleButton() {
    final linked = CloudService.isGoogleAccountLinked;
    final label = linked
        ? context.l10n.googleLinked
        : _isLinkingAccount
            ? context.l10n.googleLinking
            : context.l10n.googleSave;

    return SizedBox(
      width: double.infinity,
      child: Pressable3D(
        onTap: linked || _isLinkingAccount ? null : _connectGoogleAccount,
        color: WM.cyan,
        // Si ya está vinculado se muestra en verde (éxito), no en gris
        disabledColor: linked ? const Color(0xFF1E8C3A) : const Color(0xFF4A4660),
        height: 54,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              linked ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
              color: Colors.white,
              size: 22,
              shadows: const [Shadow(color: WM.outline, blurRadius: 3, offset: Offset(0, 2))],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: OutlinedGameText(label, size: 16, font: GameFont.oswald),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectGoogleAccount() async {
    setState(() => _isLinkingAccount = true);
    final result = await CloudService.connectGoogleAccount();
    if (!mounted) return;
    final refreshedProfile = await SaveService.loadPlayerData();
    if (!mounted) return;
    setState(() {
      _profile = refreshedProfile;
      _isLinkingAccount = false;
    });
    final message = switch (result) {
      GoogleAccountResult.linked => context.l10n.googleLinkedMsg,
      GoogleAccountResult.cancelled => context.l10n.googleCancelledMsg,
      GoogleAccountResult.failed => context.l10n.googleFailedMsg,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          Text(
            context.l10n.languageTitle,
            style: GoogleFonts.oswald(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final code in languages)
                SizedBox(
                  width: 140,
                  child: Pressable3D(
                    // El idioma activo se ve "pulsado" en verde y no se puede tocar.
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
}
