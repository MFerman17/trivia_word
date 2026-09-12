import 'package:flutter/material.dart';
import '../models/quest_model.dart';
import '../models/player_profile.dart';
import '../services/quest_service.dart';
import '../services/save_service.dart';
import '../widgets/particle_explosion.dart';

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
    PlayerProfile profile = await SaveService.loadPlayerData();
    List<QuestModel> quests = await QuestService.loadQuests();

    if (!mounted) return;

    setState(() {
      _profile = profile;
      _quests = quests;
      _isLoading = false;
    });
  }

  void _onClaimReward(QuestModel quest) async {
    if (_profile == null || !quest.isCompleted || quest.isClaimed) return;

    setState(() {
      _claimingQuestId = quest.id;
    });

    bool success = await QuestService.claimReward(quest.id, _profile!);

    if (success && mounted) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _claimingQuestId = null);
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1D36),
        title: const Text(
          'MISIONES Y LOGROS',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _quests.length,
              itemBuilder: (context, index) {
                final quest = _quests[index];
                bool isTargetTriggered = _claimingQuestId == quest.id;

                return ParticleExplosion(
                  trigger: isTargetTriggered,
                  particleEmoji: '⭐',
                  particleCount: 20,
                  type: ExplosionType.burst,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1D36),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: quest.isCompleted && !quest.isClaimed
                            ? Colors.amber
                            : Colors.white10,
                        width: quest.isCompleted && !quest.isClaimed ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(quest.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quest.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    quest.description,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: quest.progress,
                                  minHeight: 10,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    quest.isCompleted
                                        ? Colors.amberAccent
                                        : Colors.indigoAccent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${quest.currentAmount}/${quest.targetAmount}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                if (quest.rewardCoins > 0) ...[
                                  Text('🪙 +${quest.rewardCoins}',
                                      style: const TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                ],
                                if (quest.rewardGems > 0)
                                  Text('💎 +${quest.rewardGems}',
                                      style: const TextStyle(
                                          color: Colors.cyanAccent,
                                          fontWeight: FontWeight.bold)),
                              ],
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: quest.isClaimed
                                    ? Colors.grey.shade800
                                    : quest.isCompleted
                                        ? Colors.amber
                                        : Colors.white10,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: (quest.isCompleted && !quest.isClaimed)
                                  ? () => _onClaimReward(quest)
                                  : null,
                              child: Text(
                                quest.isClaimed
                                    ? 'RECLAMADO'
                                    : quest.isCompleted
                                        ? 'RECLAMAR'
                                        : 'EN PROGRESO',
                                style: TextStyle(
                                  color: quest.isCompleted && !quest.isClaimed
                                      ? Colors.black
                                      : Colors.white38,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}