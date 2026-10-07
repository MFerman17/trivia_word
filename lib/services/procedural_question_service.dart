import 'dart:math';

import '../models/question.dart';

/// Crea preguntas deterministas y propias para cada encuentro. Los índices
/// del nivel y de la pregunta forman parte de sus datos para evitar repetirlas
/// entre fases.
class ProceduralQuestionService {
  static List<Question> forEncounter({
    required int world,
    required int chapter,
    required int level,
    required int difficulty,
    required int count,
    bool isMiniChallenge = false,
  }) {
    final encounterIndex = isMiniChallenge
        ? 60 + (world - 1) * 3 + (level - 1)
        : (world - 1) * 15 + (chapter - 1) * 5 + (level - 1);

    return List.generate(count, (questionIndex) {
      final serial = encounterIndex * 10 + questionIndex;
      final template = (encounterIndex + questionIndex * 3) % 8;
      return _makeQuestion(
        serial: serial,
        template: template,
        world: world,
        difficulty: difficulty,
        id: '${isMiniChallenge ? 'mini' : 'stage'}_${world}_${chapter}_${level}_$questionIndex',
      );
    });
  }

  static Question _makeQuestion({
    required int serial,
    required int template,
    required int world,
    required int difficulty,
    required String id,
  }) {
    late String prompt;
    late String explanation;
    late String category;
    late int answer;
    List<String>? customOptions;
    int? customCorrectIndex;

    switch (template) {
      case 0:
        final sumFirst = 12 + serial;
        final sumSecond = 8 + difficulty + serial % 9;
        answer = sumFirst + sumSecond;
        prompt = '¿Cuánto es $sumFirst + $sumSecond?';
        explanation = '$sumFirst + $sumSecond = $answer.';
        category = 'Matemáticas';
        break;
      case 1:
        const subjects = [
          'La exploradora', 'El guardián', 'La maga', 'El aprendiz',
          'La criatura', 'El equipo', 'La viajera', 'El cartógrafo',
          'La bibliotecaria', 'El capitán',
        ];
        const verbs = [
          'explora', 'resuelve', 'observa', 'encuentra', 'reúne', 'cuida',
          'recorre', 'descifra', 'construye', 'comparte', 'descubrió',
          'protegía', 'escribirá', 'investigaba',
        ];
        const objects = [
          'el bosque', 'un mapa antiguo', 'las estrellas', 'la caverna',
          'varios cristales', 'una puerta secreta', 'el camino', 'una pista',
          'la isla', 'el volcán',
        ];
        final subject = subjects[serial % subjects.length];
        final verb = verbs[(serial ~/ subjects.length) % verbs.length];
        final object = objects[(serial ~/ (subjects.length * verbs.length)) % objects.length];
        prompt = 'En «$subject $verb $object», ¿qué palabra indica la acción?';
        explanation = '«$verb» es el verbo: expresa la acción que realiza el sujeto.';
        category = 'Lengua';
        answer = 0;
        final wordOptions = [
          verb,
          verbs[(serial ~/ subjects.length + 3) % verbs.length],
          verbs[(serial ~/ subjects.length + 7) % verbs.length],
          verbs[(serial ~/ subjects.length + 11) % verbs.length],
        ]..shuffle(Random(serial + difficulty * 97));
        customOptions = wordOptions;
        customCorrectIndex = wordOptions.indexOf(verb);
        break;
      case 2:
        final factorOne = 2 + serial % 11;
        final factorTwo = 2 + serial ~/ 11;
        answer = factorOne * factorTwo;
        prompt = '¿Cuánto es $factorOne × $factorTwo?';
        explanation = '$factorOne grupos de $factorTwo suman $answer.';
        category = 'Multiplicación';
        break;
      case 3:
        final divisor = 2 + serial % 9;
        final quotient = 5 + serial ~/ 9;
        final dividend = divisor * quotient;
        answer = quotient;
        prompt = '¿Cuánto es $dividend ÷ $divisor?';
        explanation = '$divisor × $quotient = $dividend, así que el resultado es $quotient.';
        category = 'División';
        break;
      case 4:
        final sequenceFirst = 3 + serial;
        final sequenceStep = 2 + difficulty + serial % 5;
        final sequenceSecond = sequenceFirst + sequenceStep;
        final sequenceThird = sequenceSecond + sequenceStep;
        answer = sequenceThird + sequenceStep;
        prompt = '¿Qué número sigue en esta secuencia: $sequenceFirst, $sequenceSecond, $sequenceThird, …?';
        explanation = 'La secuencia aumenta de $sequenceStep en $sequenceStep. El siguiente número es $answer.';
        category = 'Razonamiento';
        break;
      case 5:
        final denominator = 2 + serial % 7;
        final whole = denominator * (4 + serial);
        answer = 4 + serial;
        prompt = '¿Cuánto es 1/$denominator de $whole?';
        explanation = 'Dividimos $whole entre $denominator: el resultado es $answer.';
        category = 'Fracciones';
        break;
      case 6:
        final length = 5 + serial;
        final width = 3 + difficulty + serial % 8;
        answer = 2 * (length + width);
        prompt = 'Un sendero rectangular mide $length m por $width m. ¿Cuál es su perímetro?';
        explanation = 'El perímetro es 2 × (largo + ancho): 2 × ($length + $width) = $answer m.';
        category = 'Geometría';
        break;
      default:
        final place = switch (world) {
          1 => 'el bosque',
          2 => 'las cavernas',
          3 => 'las islas flotantes',
          _ => 'el volcán',
        };
        final collected = 15 + serial;
        final found = 4 + difficulty + serial % 12;
        final used = 2 + serial % 7;
        answer = collected + found - used;
        prompt = 'En $place reúnes $collected cristales, encuentras $found más y usas $used. ¿Cuántos te quedan?';
        explanation = '$collected + $found − $used = $answer cristales.';
        category = 'Problema del mundo';
    }

    final options = customOptions ??
        (<int>{
          answer,
          answer + 1,
          answer > 1 ? answer - 1 : answer + 4,
          answer + 2 + serial % 5,
        }.toList()..shuffle(Random(serial + difficulty * 97)))
            .map((option) => option.toString())
            .toList();

    return Question(
      id: id,
      worldId: world,
      prompt: prompt,
      options: options,
      correctIndex: customCorrectIndex ?? options.indexOf(answer.toString()),
      category: category,
      difficulty: difficulty,
      explanation: explanation,
    );
  }
}
