class QuestModel {
  final String id;
  final String title;
  final String description;
  final int targetAmount;
  int currentAmount;
  final int rewardCoins;
  final int rewardGems;
  final String emoji;
  bool isClaimed;

  QuestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    this.currentAmount = 0,
    this.rewardCoins = 0,
    this.rewardGems = 0,
    this.emoji = '🎯',
    this.isClaimed = false,
  });

  bool get isCompleted => currentAmount >= targetAmount;

  double get progress => (currentAmount / targetAmount).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'currentAmount': currentAmount,
      'isClaimed': isClaimed,
    };
  }

  factory QuestModel.fromJson(Map<String, dynamic> json, QuestModel template) {
    return QuestModel(
      id: template.id,
      title: template.title,
      description: template.description,
      targetAmount: template.targetAmount,
      currentAmount: json['currentAmount'] ?? 0,
      rewardCoins: template.rewardCoins,
      rewardGems: template.rewardGems,
      emoji: template.emoji,
      isClaimed: json['isClaimed'] ?? false,
    );
  }
}