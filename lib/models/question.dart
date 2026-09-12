enum QuestionType {
  multipleChoice,
  errorDetection,
  fillInBlank,
  homophones,
}

class Question {
  final String id;
  final int worldId;
  final int chapterId;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String category;
  final int difficulty;
  final String explanation; // <-- Mantenemos la explicación para no romper game_service.dart
  final QuestionType type;

  Question({
    required this.id,
    this.worldId = 1,        // <-- Valor por defecto para no dar error en instancias antiguas
    this.chapterId = 1,      // <-- Valor por defecto para no dar error en instancias antiguas
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.category,
    this.difficulty = 1,     // <-- Valor por defecto para no dar error en instancias antiguas
    this.explanation = '',   // <-- Valor por defecto opcional
    this.type = QuestionType.multipleChoice,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'worldId': worldId,
      'chapterId': chapterId,
      'prompt': prompt,
      'options': options,
      'correctIndex': correctIndex,
      'category': category,
      'difficulty': difficulty,
      'explanation': explanation,
      'type': type.index,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      worldId: json['worldId'] ?? 1,
      chapterId: json['chapterId'] ?? 1,
      prompt: json['prompt'],
      options: List<String>.from(json['options']),
      correctIndex: json['correctIndex'],
      category: json['category'],
      difficulty: json['difficulty'] ?? 1,
      explanation: json['explanation'] ?? '',
      type: QuestionType.values[json['type'] ?? 0],
    );
  }
}