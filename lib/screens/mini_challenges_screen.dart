import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/question_bank.dart';
import 'game_screen.dart';
import '../l10n/l10n.dart';

class MiniChallengesScreen extends StatelessWidget {
  final int worldId;

  const MiniChallengesScreen({super.key, required this.worldId});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0D0326);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background.withValues(alpha: 0.88),
        foregroundColor: Colors.white,
        title: Text(
          context.l10n.miniChallengesTitle,
          style: GoogleFonts.anton(color: const Color(0xFF1EE3CF)),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            QuestionBank.worldBackgroundAsset(worldId, 1),
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.68),
            colorBlendMode: BlendMode.darken,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x55100B22), Color(0xCC0F0C29)],
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.l10n.miniOptional(worldId),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.miniDescription,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 18),
              for (int challenge = 1; challenge <= 3; challenge++)
                _buildChallengeCard(context, challenge),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(BuildContext context, int challenge) {
    final config = QuestionBank.getConfigForMiniChallenge(worldId, challenge);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE8211638), Color(0xE8130F29)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1EE3CF).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 68,
          height: 76,
          child: Image.asset(
            config.enemyAsset,
            fit: BoxFit.contain,
            cacheWidth: 256,
            errorBuilder: (_, _, _) => Text(
              config.enemyEmoji,
              style: const TextStyle(fontSize: 34),
            ),
          ),
        ),
        title: Text(
          config.enemyName,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          context.l10n.miniChallengeInfo(challenge, config.difficulty),
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
        ),
        trailing: const Icon(Icons.play_circle_fill, color: Color(0xFFFFC857), size: 30),
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
