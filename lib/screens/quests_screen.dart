import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/quest_model.dart';
import '../models/player_profile.dart';
import '../services/audio_service.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';
import '../widgets/particle_explosion.dart';
import '../widgets/game_3d.dart';
import '../l10n/l10n.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  List<QuestModel> _quests = [];
  PlayerProfile? _profile;
  bool _isLoading = true;
  String? _claimingQuestId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await SaveService.loadPlayerData();
    final quests = await QuestService.loadQuests();

    if (!mounted) return;

    setState(() {
      _profile = profile;
      _quests = quests;
      _isLoading = false;
    });
  }

  Future<void> _onClaimReward(QuestModel quest) async {
    // Se bloquea mientras otra recompensa se está reclamando (evita doble toque)
    if (_profile == null ||
        !quest.isCompleted ||
        quest.isClaimed ||
        _claimingQuestId != null) {
      return;
    }

    setState(() => _claimingQuestId = quest.id);

    final success = await QuestService.claimReward(quest.id, _profile!);
    if (!mounted) return;
    if (success) AudioService.playCoins();

    // Antes, si fallaba, el id se quedaba puesto para siempre.
    // Ahora se libera siempre, haya éxito o no.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _claimingQuestId = null);
    });
    if (success) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WM.outline,
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              GameHeader(title: context.l10n.questsTitle),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: WM.cyan));
    }
    if (_quests.isEmpty) {
      return Center(
        child: Text(
          context.l10n.noQuests,
          style: GoogleFonts.oswald(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      itemCount: _quests.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: EntranceFlip(index: 0, child: _buildSummary()),
          );
        }
        final quest = _quests[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: EntranceFlip(index: index, child: _buildQuestCard(quest)),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // RESUMEN: cuántas misiones van completadas y cuántas por reclamar
  // ---------------------------------------------------------------
  Widget _buildSummary() {
    final total = _quests.length;
    final completed = _quests.where((q) => q.isCompleted).length;
    final ready = _quests.where((q) => q.isCompleted && !q.isClaimed).length;

    return Panel3D(
      accent: ready > 0 ? WM.gold : WM.cyan,
      glow: ready > 0 ? 0.7 : 0,
      child: Row(
        children: [
          Socket3D(
            size: 54,
            color: WM.gold,
            child: const Text('📜', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedGameText(context.l10n.questsCompleted(completed, total), size: 18),
                const SizedBox(height: 8),
                Bar3D(
                  value: total == 0 ? 0 : completed / total,
                  color: WM.gold,
                  height: 14,
                ),
              ],
            ),
          ),
          if (ready > 0) ...[
            const SizedBox(width: 10),
            Pulse(
              amount: 0.08,
              child: Chip3D(emoji: '🎁', text: '$ready', accent: WM.gold, fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // TARJETA DE MISIÓN
  // Tres estados con colores distintos:
  //   en curso  -> cian
  //   lista     -> dorado + resplandor + botón latiendo
  //   reclamada -> gris apagado
  // ---------------------------------------------------------------
  /// Título y descripción en el idioma actual, según el id de la misión.
  /// (El texto guardado en la misión se usa solo si el id es desconocido.)
  ({String title, String description}) _questTexts(QuestModel quest) {
    final l = context.l10n;
    return switch (quest.id) {
      'win_battles_3' => (title: l.questWinBattles, description: l.questWinBattlesDesc),
      'answer_trivia_10' => (title: l.questAnswerTrivia, description: l.questAnswerTriviaDesc),
      'use_potion_2' => (title: l.questUsePotion, description: l.questUsePotionDesc),
      'buy_shop_item_1' => (title: l.questBuyItem, description: l.questBuyItemDesc),
      _ => (title: quest.title, description: quest.description),
    };
  }

  Widget _buildQuestCard(QuestModel quest) {
    final bool ready = quest.isCompleted && !quest.isClaimed;
    final bool claimed = quest.isClaimed;
    final Color accent = ready
        ? WM.gold
        : claimed
            ? const Color(0xFF6B6785)
            : WM.cyan;
    final int shownAmount = math.min(quest.currentAmount, quest.targetAmount);

    Widget claimButton = Pressable3D(
      slanted: true,
      height: 40,
      depth: 5,
      radius: 8,
      color: WM.gold,
      onTap: ready && _claimingQuestId == null ? () => _onClaimReward(quest) : null,
      child: OutlinedGameText(
        claimed
            ? context.l10n.questDone
            : ready
                ? context.l10n.questClaim
                : context.l10n.questInProgress,
        size: 15,
        font: GameFont.oswald,
      ),
    );
    if (ready) claimButton = Pulse(child: claimButton);

    return ParticleExplosion(
      trigger: _claimingQuestId == quest.id,
      particleEmoji: '⭐',
      particleCount: 20,
      type: ExplosionType.burst,
      child: Opacity(
        opacity: claimed ? 0.6 : 1,
        child: Panel3D(
          accent: accent,
          glow: ready ? 1 : 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Socket3D(
                    size: 56,
                    color: accent,
                    child: Text(quest.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedGameText(
                          _questTexts(quest).title.toUpperCase(),
                          size: 17,
                          colors: ready
                              ? const [Color(0xFFFFF1B0), WM.gold]
                              : const [Colors.white, WM.bone],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _questTexts(quest).description,
                          style: GoogleFonts.oswald(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Bar3D(
                value: quest.progress,
                color: quest.isCompleted ? WM.gold : WM.cyan,
                height: 20,
                label: '$shownAmount / ${quest.targetAmount}',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (quest.rewardCoins > 0) ...[
                    Chip3D(emoji: '🪙', text: '+${quest.rewardCoins}', accent: WM.gold),
                    const SizedBox(width: 8),
                  ],
                  if (quest.rewardGems > 0)
                    Chip3D(emoji: '💎', text: '+${quest.rewardGems}', accent: WM.cyan),
                  const Spacer(),
                  claimButton,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
