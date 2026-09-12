import 'package:flutter/material.dart';
import '../models/player_profile.dart';
import '../services/save_service.dart';

class ProfileScreen extends StatefulWidget {
  final PlayerProfile? playerProfile;

  const ProfileScreen({super.key, this.playerProfile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late PlayerProfile _profile;
  bool _isLoading = true;

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
      PlayerProfile loaded = await SaveService.loadPlayerData();
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
        backgroundColor: Color(0xFF0F0C20),
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final int currentXp = _profile.experience;
    final int maxLevelXp = _profile.maxExperienceForCurrentLevel;
    final double xpProgress = _profile.levelProgress;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C20), Color(0xFF1F1D36), Color(0xFF261C4C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 1. ENCABEZADO
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Perfil de Jugador',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),

                const SizedBox(height: 20),

                // 2. AVATAR Y NIVEL
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.amber,
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: Color(0xFF1F1D36),
                        child: Text(
                          '🦸‍♂️',
                          style: TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Nvl. ${_profile.level}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // NOMBRE Y TÍTULO ACTIVO
                Text(
                  _profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  '🎖️ Recluta Ortográfico',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 20),

                // BARRA DE EXPERIENCIA (XP)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progreso de Nivel',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            '$currentXp / $maxLevelXp XP',
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: xpProgress,
                          minHeight: 10,
                          backgroundColor: Colors.black38,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. TARJETAS DE ESTADÍSTICAS REALES Y RECURSOS
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: [
                    _buildStatCard(
                      title: 'Monedas Acumuladas',
                      value: '🪙 ${_profile.coins}',
                      icon: Icons.monetization_on,
                      color: Colors.amber,
                    ),
                    _buildStatCard(
                      title: 'Gemas',
                      value: '💎 ${_profile.gems}',
                      icon: Icons.diamond,
                      color: Colors.cyanAccent,
                    ),
                    _buildStatCard(
                      title: 'Pociones de Salud',
                      value: '🧪 ${_profile.healthPotions}',
                      icon: Icons.health_and_safety,
                      color: Colors.greenAccent,
                    ),
                    _buildStatCard(
                      title: 'Pistas de Respuesta',
                      value: '💡 ${_profile.letterHints}',
                      icon: Icons.lightbulb,
                      color: Colors.orangeAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}