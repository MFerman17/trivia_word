import 'package:flutter/material.dart';
import '../models/player_profile.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import 'quests_screen.dart';
import '../services/save_service.dart';
import '../widgets/particle_explosion.dart';
import '../services/cloud_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PlayerProfile? _profile;
  bool _isLoading = true;
  bool _triggerChestExplosion = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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
        title: const Row(
          children: [
            Text('🎁 ', style: TextStyle(fontSize: 24)),
            Text(
              '¡Recompensa Diaria!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  backgroundColor: const Color(0xFF2B2B48),
                  avatar: const Text('🧪'),
                  label: Text(
                    '+$rewardPotions',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '¡EXCELENTE!',
              style: TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
              ),
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
    bool canClaim = profile.canClaimDailyReward;

    return Scaffold(
      body: Stack(
        children: [
          // 1. IMAGEN DE FONDO ÉPICA
          Positioned.fill(
            child: Image.asset(
              'assets/images/home_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // 2. CAPA DE OSCURECIMIENTO (Overlay) para legibilidad perfecta
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // 3. CONTENIDO DE LA INTERFAZ
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HUD SUPERIOR ---
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1.5),
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
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                );
                                _loadUserProfile();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Color(0xFF2E2A54),
                                    child: Icon(Icons.person, color: Colors.amberAccent, size: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Nivel ${profile.level}',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: profile.levelProgress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FFA3)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // --- LOGOTIPO ÉPICO: WORDS & MONSTERS ---
                  Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFF007F), Color(0xFFFFD700)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          "WORDS &\nMONSTERS",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            letterSpacing: 1.5,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                offset: Offset(0, 5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          "APRENDE • JUEGA • EVOLUCIONA",
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // --- COFRE DIARIO ---
                  ParticleExplosion(
                    trigger: _triggerChestExplosion,
                    particleEmoji: '🪙',
                    child: InkWell(
                      onTap: canClaim ? _claimDailyReward : null,
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: canClaim ? const Color(0xFF2D1B4E).withValues(alpha: 0.9) : const Color(0xFF161522).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: canClaim ? Colors.amber : Colors.white10,
                            width: canClaim ? 2 : 1,
                          ),
                          boxShadow: canClaim
                              ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 8)]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Text(canClaim ? '🎁' : '🔒', style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    canClaim ? '¡Cofre Diario Disponible!' : 'Cofre Diario Reclamado',
                                    style: TextStyle(
                                      color: canClaim ? Colors.amberAccent : Colors.white54,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    canClaim ? 'Toca para reclamar tu recompensa' : 'Vuelve mañana para más premios',
                                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (canClaim)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ABRIR',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // --- BOTÓN PRINCIPAL: JUGAR AVENTURA ---
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FFA3), Color(0xFF00B8FF)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FFA3).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MapScreen()),
                        );
                        _loadUserProfile();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.play_arrow_rounded, color: Colors.black, size: 30),
                          SizedBox(width: 6),
                          Text(
                            'JUGAR AVENTURA',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- MENÚ INFERIOR ESTILO TARJETAS ---
                  Row(
                    children: [
                      _buildGameCard(
                        title: 'TIENDA',
                        icon: Icons.storefront_rounded,
                        color: const Color(0xFFFF9900),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ShopScreen(playerProfile: _profile)),
                          );
                          _loadUserProfile();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildGameCard(
                        title: 'MISIONES',
                        icon: Icons.assignment_rounded,
                        color: const Color(0xFFFF0055),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const QuestsScreen()),
                          );
                          _loadUserProfile();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildGameCard(
                        title: 'RANKING',
                        icon: Icons.leaderboard_rounded,
                        color: const Color(0xFF9900FF),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
                          );
                          _loadUserProfile();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceBadge(String emoji, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}