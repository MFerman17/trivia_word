import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player_profile.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import 'quests_screen.dart';
import '../services/save_service.dart';
import '../widgets/particle_explosion.dart';
import '../services/cloud_service.dart';

// Color de contorno común para todo el estilo "juego"
const Color kOutline = Color(0xFF0D0326);
// Cian de las cascadas del fondo y blanco hueso para títulos
const Color kCyan = Color(0xFF1EE3CF);
const Color kBone = Color(0xFFF4EBDD);
// Inclinación de botones y placa del logo
const double kSkew = -0.2;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  PlayerProfile? _profile;
  bool _isLoading = true;
  bool _triggerChestExplosion = false;

  // Respiración del dragón
  late AnimationController _dragonController;
  late Animation<double> _dragonScaleAnimation;

  // Flotación suave del aventurero
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Entrada del logo con rebote
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    _dragonController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _dragonScaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _dragonController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _dragonController.dispose();
    _floatController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    PlayerProfile loadedProfile = await SaveService.loadPlayerData();
    int stars = await SaveService.getTotalStarsObtained();
    loadedProfile.totalStars = stars;

    if (!mounted) return;

    setState(() {
      _profile = loadedProfile;
      _isLoading = false;
    });

    await SaveService.savePlayerData(_profile!);
    await CloudService.syncProfileToCloud(_profile!);
  }

  void _claimDailyReward() async {
    if (_profile == null || !_profile!.canClaimDailyReward) return;

    int rewardCoins = 100;
    int rewardPotions = 2;

    setState(() {
      _triggerChestExplosion = true;
      _profile!.coins += rewardCoins;
      _profile!.healthPotions += rewardPotions;
      _profile!.lastDailyReward = DateTime.now();
    });

    await SaveService.savePlayerData(_profile!);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _triggerChestExplosion = false);
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.amber, width: 2),
        ),
        title: Row(
          children: [
            const Text('🎁 ', style: TextStyle(fontSize: 24)),
            Text(
              '¡Recompensa Diaria!',
              style: GoogleFonts.oswald(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 22),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Has reclamado tu cofre diario. ¡Vuelve mañana por más!',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Chip(
                  backgroundColor: const Color(0xFF2B2B48),
                  avatar: const Text('🪙'),
                  label: Text(
                    '+$rewardCoins',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  backgroundColor: const Color(0xFF2B2B48),
                  avatar: const Text('🧪'),
                  label: Text(
                    '+$rewardPotions',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '¡EXCELENTE!',
              style: GoogleFonts.oswald(fontWeight: FontWeight.w700, color: Colors.amberAccent, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _profile == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0E17),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final profile = _profile!;
    final bool canClaim = profile.canClaimDailyReward;

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;

    // Los personajes "pisan" justo detrás del banner del cofre.
    // 190 ≈ altura del bloque inferior (cofre + jugar + tarjetas) menos un poco
    // para que los pies queden ocultos tras el banner.
    final double charBottom = 190 + media.padding.bottom;
    final double adventurerHeight = (screenHeight * 0.28).clamp(150.0, 300.0);
    final double dragonHeight = (screenHeight * 0.33).clamp(180.0, 360.0);
    const double dragonScale = 1.4;
    const double dragonLift = -25;
    const double dragonShift = 0.35;

    return Scaffold(
      body: Stack(
        children: [
          // ===========================================================
          // CAPA 1: FONDO
          // ===========================================================
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_landscape.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // Oscurecimiento: suave arriba, fuerte abajo para los botones
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.45, 0.75, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ===========================================================
          // CAPA 2: PERSONAJES
          // ===========================================================
          // Dragón PRIMERO: así queda detrás del aventurero y nunca le tapa la cara.
          // Ajustes rápidos:
          //   dragonScale  -> tamaño (1.35 = 35% más grande que la base)
          //   dragonLift   -> cuánto se eleva sobre el banner (en píxeles)
          //   dragonShift  -> cuánto sale por el borde derecho (0.28 = 28% del ancho)
          Positioned(
            right: -screenWidth * dragonShift,
            bottom: charBottom + dragonLift,
            child: IgnorePointer(
              child: ScaleTransition(
                scale: _dragonScaleAnimation,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: dragonHeight * dragonScale,
                  width: dragonHeight * dragonScale * 1.49,
                  child: Image.asset(
                    'assets/images/dragon.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // Aventurero DESPUÉS: queda por delante del dragón
          Positioned(
            left: -8,
            bottom: charBottom,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _floatAnimation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: child,
                ),
                child: SizedBox(
                  width: screenWidth * 0.46,
                  height: adventurerHeight,
                  child: Image.asset(
                    'assets/images/adventurer.png',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
          ),

          // ===========================================================
          // CAPA 3: INTERFAZ
          // ===========================================================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHud(profile),

                  const SizedBox(height: 18),

                  // --- LOGO (arriba, liberando el centro del paisaje) ---
                  ScaleTransition(
                    scale: _logoAnimation,
                    child: _buildLogo(screenWidth),
                  ),

                  const Spacer(),

                  // --- COFRE DIARIO ---
                  _buildChestBanner(canClaim),

                  const SizedBox(height: 12),

                  // --- BOTÓN PRINCIPAL ---
                  _buildSlantButton(
                    height: 58,
                    fill: kCyan,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MapScreen()),
                      );
                      _loadUserProfile();
                    },
                    child: Text(
                      'JUGAR AVENTURA',
                      style: GoogleFonts.anton(
                        fontSize: 24,
                        letterSpacing: 1.5,
                        color: kOutline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // --- MENÚ INFERIOR ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildMenuCard(
                          title: 'TIENDA',
                          icon: Icons.storefront_rounded,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ShopScreen(playerProfile: _profile)),
                            );
                            _loadUserProfile();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMenuCard(
                          title: 'MISIONES',
                          icon: Icons.assignment_rounded,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const QuestsScreen()),
                            );
                            _loadUserProfile();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMenuCard(
                          title: 'RANKING',
                          icon: Icons.leaderboard_rounded,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
                            );
                            _loadUserProfile();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // HUD SUPERIOR
  // =================================================================
  Widget _buildHud(PlayerProfile profile) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0845).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kOutline, width: 3),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                  _loadUserProfile();
                },
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF4FC3FF), Color(0xFF1B7FE0)],
                        ),
                        border: Border.all(color: kOutline, width: 2.5),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _outlinedText(profile.name, 17, stroke: 4),
                        Text(
                          'Nivel ${profile.level}',
                          style: GoogleFonts.oswald(fontWeight: FontWeight.w700, color: Colors.amber, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildResourceBadge('⭐', '${profile.totalStars}', Colors.amberAccent),
                  const SizedBox(width: 6),
                  _buildResourceBadge('🪙', '${profile.coins}', Colors.amber),
                  const SizedBox(width: 6),
                  _buildResourceBadge('💎', '${profile.gems}', Colors.cyanAccent),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: kOutline,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                // Mínimo visible para que la barra no parezca vacía/rota
                widthFactor: profile.levelProgress.clamp(0.04, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF9DFF7A), Color(0xFF2FC22A)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // LOGO: placa inclinada + "WORDS &" en blanco hueso + "MONSTERS"
  // en letra gótica cian, con contorno y extrusión
  // =================================================================
  Widget _buildLogo(double screenWidth) {
    final double size = (screenWidth * 0.14).clamp(40.0, 66.0);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform(
            transform: Matrix4.skewX(kSkew * 0.8),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.fromLTRB(26, 10, 26, 14),
              decoration: BoxDecoration(
                color: kOutline.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kCyan, width: 2.5),
                boxShadow: [
                  BoxShadow(color: kCyan.withValues(alpha: 0.35), blurRadius: 20),
                ],
              ),
              child: Transform(
                transform: Matrix4.skewX(-kSkew * 0.8),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _logoText(
                      'WORDS &',
                      GoogleFonts.anton(fontSize: size * 0.9, height: 1.05, letterSpacing: 3),
                      const [Color(0xFFFFFFFF), kBone],
                      size,
                    ),
                    Transform(
                      transform: Matrix4.skewX(kSkew * 0.6),
                      alignment: Alignment.center,
                      child: _logoText(
                        'MONSTERS',
                        GoogleFonts.metalMania(fontSize: size * 1.05, height: 1.0, letterSpacing: 1),
                        const [Color(0xFFA8FFF6), kCyan],
                        size,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'APRENDE  ·  JUEGA  ·  EVOLUCIONA',
            style: GoogleFonts.oswald(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 2,
              color: kCyan,
              shadows: const [Shadow(color: kOutline, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoText(String text, TextStyle base, List<Color> colors, double size) {
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.14
      ..strokeJoin = StrokeJoin.round
      ..color = kOutline;

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, size * 0.08),
          child: Text(text, style: base.copyWith(foreground: strokePaint)),
        ),
        Text(text, style: base.copyWith(foreground: strokePaint)),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(bounds),
          child: Text(text, style: base.copyWith(color: Colors.white)),
        ),
      ],
    );
  }

  // Texto blanco con contorno oscuro (para botones y etiquetas)
  Widget _outlinedText(String text, double fontSize, {double stroke = 5}) {
    final base = GoogleFonts.oswald(fontWeight: FontWeight.w700, fontSize: fontSize, letterSpacing: 0.8);
    return Stack(
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = stroke
              ..strokeJoin = StrokeJoin.round
              ..color = kOutline,
          ),
        ),
        Text(text, style: base.copyWith(color: Colors.white)),
      ],
    );
  }

  // =================================================================
  // BOTÓN INCLINADO (paralelogramo). El contenido se "desinclina"
  // para que el texto y los iconos queden rectos.
  // =================================================================
  Widget _buildSlantButton({
    required Widget child,
    required VoidCallback onTap,
    required Color fill,
    Color? border,
    double height = 58,
  }) {
    return Transform(
      transform: Matrix4.skewX(kSkew),
      alignment: Alignment.center,
      child: Material(
        color: fill,
        elevation: 6,
        shadowColor: fill.withValues(alpha: 0.6),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: border == null ? BorderSide.none : BorderSide(color: border, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Center(
              child: Transform(
                transform: Matrix4.skewX(-kSkew),
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _buildSlantButton(
      height: 70,
      fill: const Color(0xE61A0845),
      border: kCyan.withValues(alpha: 0.8),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kCyan, size: 26),
          const SizedBox(height: 2),
          Text(
            title,
            style: GoogleFonts.anton(fontSize: 15, letterSpacing: 1.2, color: kBone),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // BANNER DEL COFRE
  // =================================================================
  Widget _buildChestBanner(bool canClaim) {
    return ParticleExplosion(
      trigger: _triggerChestExplosion,
      particleEmoji: '🪙',
      child: InkWell(
        onTap: canClaim ? _claimDailyReward : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: canClaim ? const Color(0xFF2D1B4E) : const Color(0xFF161522),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canClaim ? Colors.amber : kOutline,
              width: 3,
            ),
            boxShadow: canClaim
                ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.45), blurRadius: 10)]
                : [],
          ),
          child: Row(
            children: [
              Text(canClaim ? '🎁' : '🔒', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canClaim ? '¡Cofre diario disponible!' : 'Cofre diario reclamado',
                      style: GoogleFonts.oswald(fontWeight: FontWeight.w700, 
                        color: canClaim ? Colors.amberAccent : Colors.white60,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      canClaim ? 'Toca para reclamar tu recompensa' : 'Vuelve mañana para más premios',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (canClaim)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFE37A), Color(0xFFFF9D00)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kOutline, width: 2.5),
                  ),
                  child: _outlinedText('Abrir', 14, stroke: 3.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceBadge(String emoji, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: kOutline,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text(
            value,
            style: GoogleFonts.oswald(fontWeight: FontWeight.w700, color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
