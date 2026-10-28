import 'dart:math';

import '../models/question.dart';
import '../config/world_map_config.dart';

class _KnowledgeFact {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _KnowledgeFact({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

/// Crea preguntas deterministas y propias para cada encuentro. Los índices
/// del nivel y de la pregunta forman parte de sus datos para evitar repetirlas
/// entre fases.
class ProceduralQuestionService {
  static const List<_KnowledgeFact> _historyFacts = [
    _KnowledgeFact(
      prompt: '¿Qué estudia principalmente la historia?',
      options: ['Las sociedades del pasado', 'Los planetas', 'Las plantas', 'Los números'],
      correctIndex: 0,
      explanation: 'La historia estudia las sociedades humanas y los hechos del pasado.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué invento de Gutenberg facilitó reproducir libros en Europa?',
      options: ['El telescopio', 'La imprenta', 'La brújula', 'La máquina de vapor'],
      correctIndex: 1,
      explanation: 'La imprenta de tipos móviles permitió producir muchos libros con mayor rapidez.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué civilización construyó Machu Picchu?',
      options: ['La romana', 'La maya', 'La inca', 'La egipcia'],
      correctIndex: 2,
      explanation: 'Machu Picchu fue una ciudad construida por los incas en los Andes.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué documento inglés de 1215 limitó algunos poderes del rey?',
      options: ['El Código de Hammurabi', 'La Declaración de Independencia', 'El Tratado de Versalles', 'La Carta Magna'],
      correctIndex: 3,
      explanation: 'La Carta Magna fue acordada en 1215 y estableció límites al poder real.',
    ),
    _KnowledgeFact(
      prompt: '¿En qué país comenzó la Revolución Industrial?',
      options: ['Italia', 'Gran Bretaña', 'Japón', 'México'],
      correctIndex: 1,
      explanation: 'La Revolución Industrial comenzó en Gran Bretaña durante el siglo XVIII.',
    ),
  ];

  static const List<_KnowledgeFact> _geographyFacts = [
    _KnowledgeFact(
      prompt: '¿Cuál es el océano más extenso?',
      options: ['Pacífico', 'Atlántico', 'Índico', 'Ártico'],
      correctIndex: 0,
      explanation: 'El océano Pacífico es el más extenso de la Tierra.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué línea imaginaria divide la Tierra en hemisferio norte y sur?',
      options: ['El meridiano de Greenwich', 'El ecuador', 'El trópico de Cáncer', 'El círculo polar'],
      correctIndex: 1,
      explanation: 'El ecuador divide la Tierra en los hemisferios norte y sur.',
    ),
    _KnowledgeFact(
      prompt: '¿En qué continente se encuentra la cordillera de los Andes?',
      options: ['Asia', 'Europa', 'América del Sur', 'África'],
      correctIndex: 2,
      explanation: 'Los Andes recorren el oeste de América del Sur.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué país tiene la mayor superficie del mundo?',
      options: ['Canadá', 'China', 'Estados Unidos', 'Rusia'],
      correctIndex: 3,
      explanation: 'Rusia es el país con mayor superficie terrestre.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué coordenada geográfica indica la posición al este o al oeste?',
      options: ['La latitud', 'La longitud', 'La altitud', 'La escala'],
      correctIndex: 1,
      explanation: 'La longitud mide la posición al este o al oeste del meridiano de Greenwich.',
    ),
  ];

  static const List<_KnowledgeFact> _artsFacts = [
    _KnowledgeFact(
      prompt: '¿Qué característica distingue a una escultura?',
      options: ['Tiene volumen y ocupa espacio', 'Siempre está escrita', 'Solo se escucha', 'Se representa con movimientos'],
      correctIndex: 0,
      explanation: 'La escultura es un arte visual tridimensional: tiene volumen y ocupa espacio.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué instrumento tiene teclas y produce sonido al golpear cuerdas internas?',
      options: ['La flauta', 'El piano', 'El violín', 'La trompeta'],
      correctIndex: 1,
      explanation: 'Al pulsar una tecla del piano, un mecanismo golpea una cuerda interna.',
    ),
    _KnowledgeFact(
      prompt: '¿Quién pintó «La noche estrellada»?',
      options: ['Pablo Picasso', 'Frida Kahlo', 'Vincent van Gogh', 'Claude Monet'],
      correctIndex: 2,
      explanation: 'Vincent van Gogh pintó «La noche estrellada» en 1889.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué técnica crea sensación de profundidad en un dibujo plano?',
      options: ['La rima', 'El compás', 'El montaje', 'La perspectiva'],
      correctIndex: 3,
      explanation: 'La perspectiva representa la profundidad y la distancia en una superficie plana.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué busca el claroscuro en una pintura?',
      options: ['Repetir formas geométricas', 'Contrastar luces y sombras', 'Crear una rima visual', 'Mostrar movimiento con sonido'],
      correctIndex: 1,
      explanation: 'El claroscuro usa contrastes entre luz y sombra para dar volumen y dramatismo.',
    ),
  ];

  static const List<_KnowledgeFact> _commonSenseFacts = [
    _KnowledgeFact(
      prompt: 'El cielo está muy nublado y comienza a llover. ¿Qué te ayuda a mantenerte seco?',
      options: ['Un paraguas', 'Unas gafas de sol', 'Una bufanda', 'Un abanico'],
      correctIndex: 0,
      explanation: 'Un paraguas crea una cubierta que desvía la lluvia.',
    ),
    _KnowledgeFact(
      prompt: 'Una sartén acaba de salir del fuego. ¿Qué conviene usar para moverla?',
      options: ['Una servilleta fina', 'Un guante de cocina', 'Las manos mojadas', 'Una bolsa de papel'],
      correctIndex: 1,
      explanation: 'Un guante de cocina aislante ayuda a proteger las manos del calor.',
    ),
    _KnowledgeFact(
      prompt: 'Dos rutas llevan al mismo lugar. ¿Qué dato permite compararlas mejor?',
      options: ['El color del mapa', 'El nombre de las calles', 'La distancia y el tiempo estimado', 'La cantidad de señales'],
      correctIndex: 2,
      explanation: 'La distancia y el tiempo estimado ayudan a elegir la ruta más conveniente.',
    ),
    _KnowledgeFact(
      prompt: 'Un correo inesperado pide tu contraseña mediante un enlace. ¿Qué es lo más prudente?',
      options: ['Responder con la contraseña', 'Reenviarlo a todos', 'Abrir el enlace para comprobarlo', 'No abrirlo y entrar al servicio por su sitio oficial'],
      correctIndex: 3,
      explanation: 'No compartas contraseñas por enlaces inesperados; verifica entrando directamente al sitio oficial.',
    ),
    _KnowledgeFact(
      prompt: 'Las instrucciones de un aparato no coinciden con lo que muestra la pantalla. ¿Qué conviene hacer?',
      options: ['Forzar cualquier botón', 'Detenerse y consultar el modelo y las instrucciones correctas', 'Desmontarlo encendido', 'Ignorar todos los avisos'],
      correctIndex: 1,
      explanation: 'Confirmar el modelo y consultar las instrucciones correctas evita errores y daños.',
    ),
  ];

  static const List<_KnowledgeFact> _dailyLifeFacts = [
    _KnowledgeFact(
      prompt: 'Una merienda cuesta 7 € y pagas con 10 €. ¿Cuánto cambio recibes?',
      options: ['3 €', '2 €', '4 €', '17 €'],
      correctIndex: 0,
      explanation: 'Restamos el precio al pago: 10 − 7 = 3 €.',
    ),
    _KnowledgeFact(
      prompt: '¿Cuántos minutos hay en dos horas?',
      options: ['100', '120', '140', '200'],
      correctIndex: 1,
      explanation: 'Cada hora tiene 60 minutos; 2 × 60 = 120.',
    ),
    _KnowledgeFact(
      prompt: 'Una actividad empieza a las 8:30 y dura 45 minutos. ¿A qué hora termina?',
      options: ['9:05', '9:10', '9:15', '9:25'],
      correctIndex: 2,
      explanation: 'De 8:30 a 9:00 pasan 30 minutos; quedan 15, así que termina a las 9:15.',
    ),
    _KnowledgeFact(
      prompt: 'Un paquete de 750 g cuesta 3 €. ¿Cuál es su precio por kilogramo?',
      options: ['3 €', '3,50 €', '3,75 €', '4 €'],
      correctIndex: 3,
      explanation: 'Un kilogramo contiene 1.000 g. 3 € ÷ 750 × 1.000 = 4 € por kilogramo.',
    ),
    _KnowledgeFact(
      prompt: 'Tienes 60 € para el mes y quieres reservar el 15 % para ahorrar. ¿Cuánto apartas?',
      options: ['6 €', '9 €', '12 €', '15 €'],
      correctIndex: 1,
      explanation: 'El 10 % de 60 € son 6 € y el 5 % son 3 €; juntos, 9 €.',
    ),
  ];

  static const List<_KnowledgeFact> _scienceFacts = [
    _KnowledgeFact(
      prompt: 'A presión normal, ¿a qué temperatura se congela el agua?',
      options: ['0 °C', '10 °C', '50 °C', '100 °C'],
      correctIndex: 0,
      explanation: 'A presión atmosférica normal, el agua se congela a 0 °C.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué hacen las abejas al visitar flores que ayuda a muchas plantas?',
      options: ['Cambian el color del suelo', 'Transportan polen', 'Producen semillas', 'Enfrían las raíces'],
      correctIndex: 1,
      explanation: 'Al transportar polen entre flores, las abejas ayudan a la polinización.',
    ),
    _KnowledgeFact(
      prompt: '¿Por qué vemos iluminada la Luna?',
      options: ['Porque es una estrella', 'Porque produce fuego', 'Porque refleja la luz del Sol', 'Porque recibe luz de la Tierra'],
      correctIndex: 2,
      explanation: 'La Luna refleja parte de la luz solar que recibe.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué proceso permite a las plantas usar luz para fabricar azúcares?',
      options: ['La erosión', 'La digestión', 'La condensación', 'La fotosíntesis'],
      correctIndex: 3,
      explanation: 'En la fotosíntesis, las plantas usan luz, agua y dióxido de carbono para producir azúcares.',
    ),
    _KnowledgeFact(
      prompt: '¿Qué afirmación sobre los antibióticos es correcta?',
      options: ['Eliminan cualquier virus', 'Actúan contra bacterias, no contra virus', 'Sustituyen todas las vacunas', 'Sirven para bajar la temperatura por sí solos'],
      correctIndex: 1,
      explanation: 'Los antibióticos tratan ciertas infecciones bacterianas; no actúan contra los virus.',
    ),
  ];

  static const List<_KnowledgeFact> _generalKnowledgeFacts = [
    _KnowledgeFact(
      prompt: '¿Qué significa normalmente una luz roja en un semáforo?',
      options: ['Detenerse', 'Acelerar', 'Girar siempre', 'Aparcar'],
      correctIndex: 0,
      explanation: 'La luz roja indica que hay que detenerse y respetar el paso seguro.',
    ),
    _KnowledgeFact(
      prompt: '¿Hacia qué punto cardinal suele señalar la aguja de una brújula?',
      options: ['Sur', 'Norte', 'Este', 'Oeste'],
      correctIndex: 1,
      explanation: 'La aguja imantada de una brújula se alinea aproximadamente con el norte magnético.',
    ),
    _KnowledgeFact(
      prompt: '¿Cuántos días tiene una semana?',
      options: ['5', '6', '7', '8'],
      correctIndex: 2,
      explanation: 'La semana civil tiene siete días.',
    ),
    _KnowledgeFact(
      prompt: '¿Cuántos céntimos forman un euro?',
      options: ['10', '50', '90', '100'],
      correctIndex: 3,
      explanation: 'Un euro equivale a 100 céntimos.',
    ),
    _KnowledgeFact(
      prompt: '¿Cuánto tarda aproximadamente la Tierra en completar una rotación?',
      options: ['Una hora', 'Un día', 'Un mes', 'Un año'],
      correctIndex: 1,
      explanation: 'La Tierra tarda aproximadamente 24 horas en girar una vez sobre su eje.',
    ),
  ];

  static List<Question> forEncounter({
    required int world,
    required int chapter,
    required int level,
    required int difficulty,
    required int count,
    bool isMiniChallenge = false,
    bool increaseDifficulty = true,
  }) {
    final encounterIndex = isMiniChallenge
        ? 200 + (world - 1) * 3 + (level - 1)
        : (world - 1) * kChaptersPerWorld * kLevelsPerChapter +
            (chapter - 1) * kLevelsPerChapter +
            (level - 1);

    return List.generate(count, (questionIndex) {
      final serial = encounterIndex * 10 + questionIndex;
      final template = (encounterIndex + questionIndex * 7) % 15;
      final questionDifficulty = increaseDifficulty
          ? (difficulty + questionIndex ~/ 2).clamp(1, 5).toInt()
          : difficulty;
      return _makeQuestion(
        serial: serial,
        template: template,
        world: world,
        difficulty: questionDifficulty,
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
        final sumFirst = 5 + serial % (10 * difficulty);
        final sumSecond = 3 + difficulty + serial % (7 * difficulty);
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
        final factorOne = 2 + serial % (3 + difficulty * 2);
        final factorTwo = 2 + (serial ~/ 7) % (2 + difficulty * 2);
        answer = factorOne * factorTwo;
        prompt = '¿Cuánto es $factorOne × $factorTwo?';
        explanation = '$factorOne grupos de $factorTwo suman $answer.';
        category = 'Multiplicación';
        break;
      case 3:
        final divisor = 2 + serial % (3 + difficulty);
        final quotient = 3 + (serial ~/ 7) % (4 + difficulty * 3);
        final dividend = divisor * quotient;
        answer = quotient;
        prompt = '¿Cuánto es $dividend ÷ $divisor?';
        explanation = '$divisor × $quotient = $dividend, así que el resultado es $quotient.';
        category = 'División';
        break;
      case 4:
        final sequenceFirst = 3 + serial % (15 * difficulty);
        final sequenceStep = 2 + difficulty + serial % 5;
        final sequenceSecond = sequenceFirst + sequenceStep;
        final sequenceThird = sequenceSecond + sequenceStep;
        answer = sequenceThird + sequenceStep;
        prompt = '¿Qué número sigue en esta secuencia: $sequenceFirst, $sequenceSecond, $sequenceThird, …?';
        explanation = 'La secuencia aumenta de $sequenceStep en $sequenceStep. El siguiente número es $answer.';
        category = 'Razonamiento';
        break;
      case 5:
        final denominator = 2 + serial % (2 + difficulty);
        answer = 4 + serial % (5 + difficulty * 4);
        final whole = denominator * answer;
        prompt = '¿Cuánto es 1/$denominator de $whole?';
        explanation = 'Dividimos $whole entre $denominator: el resultado es $answer.';
        category = 'Fracciones';
        break;
      case 6:
        final length = 5 + serial % (5 + difficulty * 5);
        final width = 3 + difficulty + serial % (3 + difficulty * 3);
        answer = 2 * (length + width);
        prompt = 'Un sendero rectangular mide $length m por $width m. ¿Cuál es su perímetro?';
        explanation = 'El perímetro es 2 × (largo + ancho): 2 × ($length + $width) = $answer m.';
        category = 'Geometría';
        break;
      case 7:
        final place = switch (world) {
          1 => 'el bosque',
          2 => 'las cavernas',
          3 => 'las islas flotantes',
          _ => 'el volcán',
        };
        final collected = 10 * difficulty + serial % (15 * difficulty);
        final found = 2 + difficulty + serial % (5 * difficulty);
        final used = 2 + serial % (3 + difficulty);
        answer = collected + found - used;
        prompt = 'En $place reúnes $collected cristales, encuentras $found más y usas $used. ¿Cuántos te quedan?';
        explanation = '$collected + $found − $used = $answer cristales.';
        category = 'Problema del mundo';
        break;
      case 8:
        final fact = _historyFacts[difficulty - 1];
        prompt = fact.prompt;
        explanation = fact.explanation;
        category = 'Historia';
        customOptions = fact.options;
        customCorrectIndex = fact.correctIndex;
        answer = 0;
        break;
      case 9:
        final fact = _geographyFacts[difficulty - 1];
        prompt = fact.prompt;
        explanation = fact.explanation;
        category = 'Geografía';
        customOptions = fact.options;
        customCorrectIndex = fact.correctIndex;
        answer = 0;
        break;
      case 10:
        final fact = _artsFacts[difficulty - 1];
        prompt = fact.prompt;
        explanation = fact.explanation;
        category = 'Artes';
        customOptions = fact.options;
        customCorrectIndex = fact.correctIndex;
        answer = 0;
        break;
      case 11:
        final fact = _commonSenseFacts[difficulty - 1];
        prompt = fact.prompt;
        explanation = fact.explanation;
        category = 'Sentido común';
        customOptions = fact.options;
        customCorrectIndex = fact.correctIndex;
        answer = 0;
        break;
      case 12:
        final fact = _dailyLifeFacts[difficulty - 1];
        prompt = fact.prompt;
        explanation = fact.explanation;
        category = 'Vida cotidiana';
        customOptions = fact.options;
        customCorrectIndex = fact.correctIndex;
        answer = 0;
        break;
      case 13:
        final fact = _scienceFacts[difficulty - 1];
        prompt = fact.prompt;
        explanation = fact.explanation;
        category = 'Ciencia';
        customOptions = fact.options;
        customCorrectIndex = fact.correctIndex;
        answer = 0;
        break;
      default:
        final fact = _generalKnowledgeFacts[difficulty - 1];
        prompt = fact.prompt;
        explanation = fact.explanation;
        category = 'Cultura general';
        customOptions = fact.options;
        customCorrectIndex = fact.correctIndex;
        answer = 0;
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
