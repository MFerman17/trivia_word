import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/question_bank.dart';
import 'game_screen.dart';

class MiniChallengesScreen extends StatelessWidget {
  final int worldId;

  const MiniChallengesScreen({super.key, required this.worldId});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0D0326);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: Colors.white,
        title: Text(
          'MINI-RETOS',
          style: GoogleFonts.anton(color: const Color(0xFF1EE3CF)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Encuentros opcionales del Mundo $worldId',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Derrota a criaturas más débiles con tus conocimientos. Cada mini-reto da monedas y XP una vez al día.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          for (int challenge = 1; challenge <= 3; challenge++)
            _buildChallengeCard(context, challenge),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(BuildContext context, int challenge) {
    final config = QuestionBank.getConfigForMiniChallenge(worldId, challenge);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF211638),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1EE3CF).withValues(alpha: 0.35)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Text(config.enemyEmoji, style: const TextStyle(fontSize: 34)),
        title: Text(
          config.enemyName,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          'Reto $challenge · Dificultad ${config.difficulty} · 15 🪙 + 10 XP diarios',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
        ),
        trailing: const Icon(Icons.play_circle_fill, color: Color(0xFF1EE3CF)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameScreen(
                worldId: worldId,
                chapterId: 1,
                levelNumber: challenge,
                isMiniChallenge: true,
              ),
            ),
          );
        },
      ),
    );
  }
}
