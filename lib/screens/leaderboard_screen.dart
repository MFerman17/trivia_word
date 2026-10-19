import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/leaderboard_user.dart';
import '../models/player_profile.dart';
import '../controllers/leaderboard_controller.dart';
import '../services/save_service.dart';
import '../widgets/player_avatar.dart';
import '../widgets/game_3d.dart';
import '../l10n/l10n.dart';

class LeaderboardScreen extends StatefulWidget {
  final PlayerProfile? playerProfile;

  const LeaderboardScreen({super.key, this.playerProfile});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late LeaderboardController _controller;

  // Perfil del jugador actual, para resaltarlo y mostrar su avatar real
  PlayerProfile? _me;
  String? get _userName => _me?.name;

  @override
  void initState() {
    super.initState();
    _me = widget.playerProfile;
    // La portada abre esta pantalla SIN pasar el perfil, así que antes el
    // nombre quedaba como "Tú (Jugador)" y nunca se resaltaba al jugador.
    // Ahora, si no llega, se carga del guardado.
    if (_me == null) {
      SaveService.loadPlayerData().then((profile) {
        if (mounted) setState(() => _me = profile);
      });
    }
    _controller = LeaderboardController();
    _controller.fetchLeaderboard();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // El modelo LeaderboardUser exige un emoji; se mantiene la lógica original.
  String _getAvatarForName(String name) {
    const emojis = ['🧙‍♂️', '🧝‍♀️', '🥷', '👑', '🦸‍♀️', '🤖', '🎮', '🦁', '🕵️‍♂️', '🚀'];
    return emojis[name.length % emojis.length];
  }

  String _portraitFor(String name) {
    const portraits = [
      'assets/images/avatar_mage.png',
      'assets/images/avatar_guardian.png',
      'assets/images/avatar_explorer.png',
    ];
    final nameValue = name.codeUnits.fold<int>(0, (total, unit) => total + unit);
    return portraits[nameValue % portraits.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WM.outline,
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(title: context.l10n.rankingTitle),
              Expanded(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    if (_controller.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: WM.cyan),
                      );
                    }
                    if (_controller.topPlayers.isEmpty) return _buildEmpty();

                    final leaderboard = List.generate(
                      _controller.topPlayers.length,
                      (index) {
                        final item = _controller.topPlayers[index];
                        final String name = item['name'] ?? context.l10n.unknownPlayer;
                        return LeaderboardUser(
                          rank: index + 1,
                          name: name,
                          countryFlag: '🌍',
                          trophies: item['stars'] ?? 0, // las estrellas son el ranking
                          avatarEmoji: name == _userName ? '🎮' : _getAvatarForName(name),
                        );
                      },
                    );

                    final topThree = leaderboard.take(3).toList();
                    final rest = leaderboard.skip(3).toList();
                    final me = leaderboard.where((u) => u.name == _userName).firstOrNull;
                    // Barra fija "TU POSICIÓN" solo si no estás ya en el podio
                    final showMyBar = me != null && me.rank > 3;

                    return Column(
                      children: [
                        const SizedBox(height: 4),
                        _buildPodium(topThree),
                        const SizedBox(height: 12),
                        Expanded(child: _buildListSheet(rest, showMyBar ? me : null)),
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

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Panel3D(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              OutlinedGameText(context.l10n.noHeroesYet, size: 22),
              const SizedBox(height: 6),
              Text(
                context.l10n.beFirst,
                style: GoogleFonts.oswald(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // PODIO 3D: bloques dibujados con perspectiva que "crecen" al entrar
  // ---------------------------------------------------------------
  Widget _buildPodium(List<LeaderboardUser> top) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spotWidth = math.min((constraints.maxWidth - 40) / 3, 118.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (top.length > 1)
              _buildPodiumSpot(user: top[1], width: spotWidth, blockHeight: 88, medal: WM.silver),
            const SizedBox(width: 8),
            if (top.isNotEmpty)
              _buildPodiumSpot(
                user: top[0],
                width: spotWidth,
                blockHeight: 120,
                medal: WM.gold,
                isFirst: true,
              ),
            const SizedBox(width: 8),
            if (top.length > 2)
              _buildPodiumSpot(user: top[2], width: spotWidth, blockHeight: 66, medal: WM.bronze),
          ],
        );
      },
    );
  }

  Widget _buildPodiumSpot({
    required LeaderboardUser user,
    required double width,
    required double blockHeight,
    required Color medal,
    bool isFirst = false,
  }) {
    final isMe = user.name == _userName;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFirst)
            const Bob(
              amplitude: 5,
              child: Text(
                '👑',
                style: TextStyle(
                  fontSize: 30,
                  shadows: [Shadow(color: Colors.amber, blurRadius: 18)],
                ),
              ),
            )
          else
            const SizedBox(height: 12),
          _medalAvatar(user, isFirst ? 76 : 62, medal, isMe),
          const SizedBox(height: 6),
          OutlinedGameText(
            user.name,
            size: isFirst ? 16 : 14,
            font: GameFont.oswald,
            colors: isMe ? const [Color(0xFFFFF1B0), WM.gold] : const [Colors.white, WM.bone],
          ),
          const SizedBox(height: 4),
          Chip3D(emoji: '⭐', text: '${user.trophies}', accent: medal, fontSize: 12),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: blockHeight),
            duration: Duration(milliseconds: isFirst ? 900 : 700),
            curve: Curves.easeOutBack,
            builder: (context, h, _) => SizedBox(
              width: width,
              height: math.max(h, PodiumBlockPainter.topFace + 2),
              child: CustomPaint(
                painter: PodiumBlockPainter(medal),
                child: Padding(
                  padding: const EdgeInsets.only(top: PodiumBlockPainter.topFace),
                  child: Center(
                    child: h > 44
                        ? OutlinedGameText(
                            '${user.rank}',
                            size: isFirst ? 40 : 32,
                            colors: [Colors.white, shade(medal, 0.2)],
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Avatar dentro de un aro metálico del color de la medalla.
  // Para el jugador actual se usa su avatar real (personaje, marco y accesorio).
  Widget _medalAvatar(LeaderboardUser user, double size, Color ring, bool isMe) {
    // Jugador actual: su avatar real escalado al hueco.
    // Resto: retrato recortado en círculo que llena el hueco.
    final Widget face = isMe && _me != null
        ? Center(child: FittedBox(child: PlayerAvatar(profile: _me!, radius: size * 0.36)))
        : ClipOval(
            child: ColoredBox(
              color: const Color(0xFF1F1D36),
              child: SizedBox.expand(
                child: Image.asset(
                  _portraitFor(user.name),
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.12),
                ),
              ),
            ),
          );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.07),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: WM.outline, width: 2.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [shade(ring, 0.22), ring, shade(ring, -0.3)],
        ),
        boxShadow: [
          BoxShadow(color: shade(ring, -0.42), offset: const Offset(0, 4)),
          if (isMe) BoxShadow(color: WM.cyan.withValues(alpha: 0.7), blurRadius: 18),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: WM.outline, width: 2),
        ),
        child: face,
      ),
    );
  }

  // ---------------------------------------------------------------
  // LISTA (puesto 4 en adelante) sobre una "losa" con borde de luz
  // ---------------------------------------------------------------
  Widget _buildListSheet(List<LeaderboardUser> rest, LeaderboardUser? myBar) {
    const radius = BorderRadius.vertical(top: Radius.circular(28));

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE62A1A5E), Color(0xF2160E36), Color(0xFA0D0326)],
        ),
        boxShadow: [
          BoxShadow(
            color: WM.cyan.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Filo de luz cian en el borde superior de la losa
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      WM.cyan.withValues(alpha: 0),
                      WM.cyan,
                      WM.cyan.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            if (rest.isEmpty)
              Center(
                child: Text(
                  context.l10n.onlyPodium,
                  style: GoogleFonts.oswald(color: Colors.white54, fontSize: 14),
                ),
              )
            else
              ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 18, 16, myBar != null ? 110 : 24),
                itemCount: rest.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EntranceFlip(index: i, child: _buildRow(rest[i])),
                ),
              ),
            if (myBar != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: _buildMyRankBar(myBar),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(LeaderboardUser user) {
    final isMe = user.name == _userName;
    final accent = isMe ? WM.gold : WM.violet;

    return Panel3D(
      accent: accent,
      glow: isMe ? 0.8 : 0,
      depth: 5,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          _rankBadge(user.rank, accent),
          const SizedBox(width: 10),
          _medalAvatar(user, 46, accent, isMe),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedGameText(
                  user.name,
                  size: 16,
                  font: GameFont.oswald,
                  colors: isMe ? const [Color(0xFFFFF1B0), WM.gold] : const [Colors.white, WM.bone],
                ),
                if (isMe)
                  Text(
                    context.l10n.you,
                    style: GoogleFonts.anton(color: WM.cyan, fontSize: 11, letterSpacing: 2),
                  ),
              ],
            ),
          ),
          Chip3D(emoji: '⭐', text: '${user.trophies}', accent: WM.gold),
        ],
      ),
    );
  }

  // Insignia de puesto: paralelogramo inclinado con canto sólido
  Widget _rankBadge(int rank, Color accent) {
    return Transform(
      transform: Matrix4.skewX(WM.skew),
      alignment: Alignment.center,
      child: Container(
        width: 42,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: WM.outline, width: 2.5),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [shade(accent, 0.15), accent, shade(accent, -0.15)],
          ),
          boxShadow: [BoxShadow(color: shade(accent, -0.4), offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Transform(
          transform: Matrix4.skewX(-WM.skew),
          alignment: Alignment.center,
          child: OutlinedGameText('$rank', size: 17),
        ),
      ),
    );
  }

  Widget _buildMyRankBar(LeaderboardUser me) {
    return Panel3D(
      accent: WM.gold,
      glow: 1,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(
            context.l10n.yourPosition,
            style: GoogleFonts.oswald(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          OutlinedGameText(
            '#${me.rank}',
            size: 24,
            colors: const [Color(0xFFFFF1B0), WM.gold],
          ),
          const SizedBox(width: 12),
          Chip3D(emoji: '⭐', text: '${me.trophies}', accent: WM.gold),
        ],
      ),
    );
  }
}
