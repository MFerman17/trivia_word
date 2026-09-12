import 'package:flutter/material.dart';
import '../models/player_profile.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import 'quests_screen.dart';
import '../services/save_service.dart';
import '../widgets/particle_explosion.dart';

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
  }

  void _claimDailyReward() async {
    if (_profile == null || !_profile!.canClaimDailyReward) return;

    // Configuración de la recompensa
    int rewardCoins = 100;
    int rewardPotions = 2;

    setState(() {
      _triggerChestExplosion = true; // 👈 Activa la lluvia de partículas
      _profile!.coins += rewardCoins;
      _profile!.healthPotions += rewardPotions;
      _profile!.lastDailyReward = DateTime.now();
    });

    await SaveService.savePlayerData(_profile!);

    // Restablece el disparador después de un momento para permitir futuras ejecuciones
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _triggerChestExplosion = false);
    });

    if (!mounted) return;

    // Diálogo emergente de recompensa
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
      backgroundColor: const Color(0xFF0F0E17),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // --- TARJETA DE PERFIL DEL JUGADOR ---
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1D36),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x4DFFC107)),
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
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      profile.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.edit,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Nivel ${profile.level}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            const Text('⭐ ', style: TextStyle(fontSize: 16)),
                            Text(
                              '${profile.totalStars}',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('🪙 ', style: TextStyle(fontSize: 16)),
                            Text(
                              '${profile.coins}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('💎 ', style: TextStyle(fontSize: 16)),
                            Text(
                              '${profile.gems}',
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // BARRA DE EXPERIENCIA (XP)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Progreso XP',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${profile.experience} / ${profile.maxExperienceForCurrentLevel}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: profile.levelProgress.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.purpleAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- BOTÓN COFRE DIARIO CON EFECTO DE PARTÍCULAS ---
              ParticleExplosion(
                trigger: _triggerChestExplosion,
                particleEmoji: '🪙',
                child: InkWell(
                  onTap: canClaim ? _claimDailyReward : null,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: canClaim
                          ? const Color(0xFF2D1B4E)
                          : const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: canClaim ? Colors.amber : Colors.white10,
                        width: canClaim ? 2 : 1,
                      ),
                      boxShadow: canClaim
                          ? [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Text(
                          canClaim ? '🎁' : '🔒',
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                canClaim
                                    ? '¡Cofre Diario Disponible!'
                                    : 'Cofre Diario Reclamado',
                                style: TextStyle(
                                  color: canClaim
                                      ? Colors.amberAccent
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                canClaim
                                    ? 'Toca para reclamar tu recompensa'
                                    : 'Vuelve mañana para más premios',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canClaim)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ABRIR',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // --- BOTÓN JUGAR BATALLA ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                  label: const Text(
                    'JUGAR BATALLA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapScreen(),
                      ),
                    );
                    _loadUserProfile();
                  },
                ),
              ),

              const SizedBox(height: 12),

              // --- BOTÓN TIENDA DE MEJORAS ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B1C4C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  icon: const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 28,
                  ),
                  label: const Text(
                    'TIENDA DE MEJORAS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ShopScreen(playerProfile: _profile),
                      ),
                    );
                    _loadUserProfile();
                  },
                ),
              ),

              const SizedBox(height: 12),

              // --- BOTÓN MISIONES Y LOGROS ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38235D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.amberAccent),
                    ),
                  ),
                  icon: const Icon(
                    Icons.stars,
                    color: Colors.amberAccent,
                    size: 26,
                  ),
                  label: const Text(
                    'MISIONES Y LOGROS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QuestsScreen(),
                      ),
                    );
                    _loadUserProfile();
                  },
                ),
              ),

              const SizedBox(height: 12),

              // --- BOTÓN CLASIFICACIÓN / LEADERBOARD ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B2B48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  icon: const Icon(
                    Icons.leaderboard,
                    color: Colors.amberAccent,
                    size: 26,
                  ),
                  label: const Text(
                    'CLASIFICACIÓN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LeaderboardScreen(),
                      ),
                    );
                    _loadUserProfile();
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
