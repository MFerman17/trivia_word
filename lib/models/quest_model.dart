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

  /// Las misiones diarias se reinician cada día (ver [QuestService]).
  final bool daily;

  /// Día (aaaa-mm-dd) al que pertenece el progreso de una misión diaria.
  String day;

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
    this.daily = false,
    this.day = '',
  });

  bool get isCompleted => currentAmount >= targetAmount;

  double get progress => (currentAmount / targetAmount).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'currentAmount': currentAmount,
      'isClaimed': isClaimed,
      if (daily) 'day': day,
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
      daily: template.daily,
      day: json['day'] as String? ?? '',
    );
  }
}