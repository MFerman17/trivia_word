import 'package:flutter/material.dart';
import '../models/leaderboard_user.dart';
import '../models/player_profile.dart';
import '../controllers/leaderboard_controller.dart'; // 👈 Importamos el controlador

class LeaderboardScreen extends StatefulWidget {
  final PlayerProfile? playerProfile;

  const LeaderboardScreen({super.key, this.playerProfile});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late LeaderboardController _controller;
  
  // Nombre del jugador actual para resaltarlo en oro
  late String userName;

  @override
  void initState() {
    super.initState();
    userName = widget.playerProfile?.name ?? 'Tú (Jugador)';
    _controller = LeaderboardController();
    
    // 👈 Pedimos los datos reales a Firebase al abrir la pantalla
    _controller.fetchLeaderboard(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Pequeña función para dar emojis variados según el nombre (ya que en FB aún no los guardamos)
  String _getAvatarForName(String name) {
    const emojis = ['🧙‍♂️', '🧝‍♀️', '🥷', '👑', '🦸‍♀️', '🤖', '🎮', '🦁', '🕵️‍♂️', '🚀'];
    return emojis[name.length % emojis.length];
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              // 1. BARRA DE ENCABEZADO (Siempre visible)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Tabla de Clasificación',
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
              ),
              const SizedBox(height: 10),

              // 2. CONSTRUCTOR REACTIVO (Escucha a Firebase)
              Expanded(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    // MIENTRAS CARGA DE INTERNET
                    if (_controller.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.amber),
                      );
                    }

                    // SI NO HAY DATOS (Nadie ha jugado)
                    if (_controller.topPlayers.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aún no hay jugadores en el ranking.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      );
                    }

                    // 3. MAPEAR DATOS DE FIREBASE AL MODELO LeaderboardUser
                    final List<LeaderboardUser> leaderboard = List.generate(
                      _controller.topPlayers.length,
                      (index) {
                        final item = _controller.topPlayers[index];
                        return LeaderboardUser(
                          rank: index + 1,
                          name: item['name'] ?? 'Desconocido',
                          countryFlag: '🌍', // Por defecto hasta que se guarde el país en BD
                          trophies: item['stars'] ?? 0, // Usamos las estrellas como ranking principal
                          avatarEmoji: item['name'] == userName 
                              ? '🎮' // Tu avatar fijo
                              : _getAvatarForName(item['name'] ?? 'A'),
                        );
                      },
                    );

                    // Separar podio y el resto de la lista
                    final topThree = leaderboard.take(3).toList();
                    final remainingUsers = leaderboard.skip(3).toList();

                    return Column(
                      children: [
                        // PODIO DE LOS TOP 3
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // PUESTO 2
                              if (topThree.length > 1)
                                _buildPodiumSpot(
                                  user: topThree[1],
                                  height: 110,
                                  crownColor: Colors.grey.shade300,
                                  borderColor: Colors.grey,
                                  isCurrentUser: topThree[1].name == userName,
                                ),
                              const SizedBox(width: 12),
                              // PUESTO 1
                              if (topThree.isNotEmpty)
                                _buildPodiumSpot(
                                  user: topThree[0],
                                  height: 140,
                                  crownColor: Colors.amber,
                                  borderColor: Colors.amber,
                                  isFirst: true,
                                  isCurrentUser: topThree[0].name == userName,
                                ),
                              const SizedBox(width: 12),
                              // PUESTO 3
                              if (topThree.length > 2)
                                _buildPodiumSpot(
                                  user: topThree[2],
                                  height: 90,
                                  crownColor: Colors.brown.shade300,
                                  borderColor: Colors.brown,
                                  isCurrentUser: topThree[2].name == userName,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // LISTA DEL RESTO DE JUGADORES
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF161329),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: remainingUsers.length,
                              itemBuilder: (context, index) {
                                final user = remainingUsers[index];
                                final isCurrentUser = user.name == userName;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isCurrentUser
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isCurrentUser ? Colors.amber : Colors.white10,
                                      width: isCurrentUser ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 30,
                                        child: Text(
                                          '#${user.rank}',
                                          style: TextStyle(
                                            color: isCurrentUser ? Colors.amber : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Text(user.avatarEmoji, style: const TextStyle(fontSize: 24)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                user.name,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isCurrentUser ? Colors.amber : Colors.white,
                                                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(user.countryFlag, style: const TextStyle(fontSize: 16)),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Text('🏆 ', style: TextStyle(fontSize: 14)),
                                          Text(
                                            '${user.trophies}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- El método de diseño del podio se mantiene idéntico a tu código original ---
  Widget _buildPodiumSpot({
    required LeaderboardUser user,
    required double height,
    required Color crownColor,
    required Color borderColor,
    bool isFirst = false,
    bool isCurrentUser = false,
  }) {
    final String displayName = user.name.length > 8
        ? '${user.name.substring(0, 7)}…'
        : user.name;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(isFirst ? 14 : 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? Colors.amber.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: isCurrentUser ? Colors.amber : borderColor,
                  width: isCurrentUser ? 3 : 2,
                ),
              ),
              child: Text(
                user.avatarEmoji,
                style: TextStyle(fontSize: isFirst ? 36 : 28),
              ),
            ),
            Positioned(
              top: -16,
              child: Icon(
                Icons.workspace_premium,
                color: crownColor,
                size: isFirst ? 26 : 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              style: TextStyle(
                color: isCurrentUser ? Colors.amber : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(user.countryFlag, style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '🏆 ${user.trophies}',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: isFirst ? 80 : 70,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                borderColor.withValues(alpha: 0.8),
                borderColor.withValues(alpha: 0.3),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Center(
            child: Text(
              '#${user.rank}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}