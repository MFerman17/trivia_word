// no utilizar por ahora import '../models/monster.dart';
import '../models/question.dart';

class GameService {
  static List<Question> getQuestions() {
    return [
      // CATEGORÍA: B / V
      Question(
        id: 'q1',
        prompt: '¿Cuál de las siguientes palabras está escrita correctamente?',
        options: ['Absolver', 'Avsolver', 'Absolverr', 'Avsolber'],
        correctIndex: 0,
        explanation: 'El prefijo "ab-" siempre se escribe con B.',
        category: 'Uso de B y V',
      ),
      Question(
        id: 'q2',
        prompt: 'Selecciona la opción correcta para completar la frase: "Ella ___ en Madrid".',
        options: ['vivía', 'bibía', 'vivia', 'bibia'],
        correctIndex: 0,
        explanation: 'El verbo "vivir" se escribe con V, y la terminación del pretérito imperfecto lleva tilde ("vivía").',
        category: 'Uso de B y V',
      ),

      // CATEGORÍA: C / S / Z
      Question(
        id: 'q3',
        prompt: '¿Qué palabra contiene una falta de ortografía?',
        options: ['Desición', 'Comprensión', 'Expresión', 'Consecuencia'],
        correctIndex: 0, // Todas están bien escritas salvo que forcemos un error común
        explanation: '"Decisión" se escribe con C en la primera sílaba y S en la última.',
        category: 'Uso de C, S y Z',
      ),
      Question(
        id: 'q4',
        prompt: 'El plural de la palabra "Luz" es:',
        options: ['Luces', 'Luzes', 'Lusses', 'Lucess'],
        correctIndex: 0,
        explanation: 'Las palabras que terminan en Z cambian a C al formar el plural con "-es".',
        category: 'Uso de C, S y Z',
      ),

      // CATEGORÍA: ACENTUACIÓN Y TILDES
      Question(
        id: 'q5',
        prompt: '¿Cuál de estas palabras es esdrújula y requiere tilde?',
        options: ['Música', 'Pared', 'Cancion', 'Arbol'],
        correctIndex: 0,
        explanation: 'Todas las palabras esdrújulas llevan tilde en la antepenúltima sílaba: "Mú-si-ca".',
        category: 'Acentuación',
      ),
      Question(
        id: 'q6',
        prompt: '¿En cuál de estos casos "solo" NO debe llevar tilde según la RAE?',
        options: [
          'Nunca es obligatoria si no hay ambigüedad',
          'Siempre lleva tilde si significa solamente',
          'Siempre lleva tilde si es adjetivo',
          'Nunca se acentúa en ningún contexto'
        ],
        correctIndex: 0,
        explanation: 'La RAE establece que el uso de la tilde diacrítica en "solo" únicamente es optativo en casos de ambigüedad.',
        category: 'Acentuación',
      ),

      // CATEGORÍA: G / J Y H
      Question(
        id: 'q7',
        prompt: '¿Cuál de las siguientes formas es la correcta?',
        options: ['Echar de menos', 'Hechar de menos', 'Echar de mas', 'Hechar de mas'],
        correctIndex: 0,
        explanation: 'El verbo "echar" (tirar, depositar, calcular) no lleva H. El verbo "hacer" sí ("hecho").',
        category: 'Uso de la H',
      ),
      Question(
        id: 'q8',
        prompt: 'El pasado del verbo "Conducir" (3ª persona del plural) es:',
        options: ['Condujeron', 'Conducieron', 'Condugeron', 'Condugieron'],
        correctIndex: 0,
        explanation: 'Los verbos terminados en "-ducir" hacen su pretérito indefinido con J ("conduje", "condujeron").',
        category: 'Uso de G y J',
      ),
    ];
  }
}