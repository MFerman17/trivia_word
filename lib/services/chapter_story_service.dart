import '../models/chapter_story.dart';

class ChapterStoryService {
  static const Map<String, ChapterStory> _stories = {
    '1_1': ChapterStory(
      heading: '¡Capítulo 1 completado!',
      destination: 'Capítulo 2 · El corazón del bosque',
      narrative:
          'El guardián reconoce tu valor y aparta las raíces que bloqueaban el camino. Al otro lado, una luz azul late bajo los árboles: algo antiguo está despertando.',
      objective: 'Sigue las luces y descubre qué protege el bosque.',
    ),
    '1_2': ChapterStory(
      heading: '¡Capítulo 2 completado!',
      destination: 'Capítulo 3 · La puerta de piedra',
      narrative:
          'Las piedras del bosque se alinean y forman un portal. El mapa muestra cavernas llenas de cristales; allí se esconde la pista sobre la fuerza que despierta en los mundos.',
      objective: 'Cruza el portal y busca la señal del siguiente mundo.',
    ),
    '1_3': ChapterStory(
      heading: '¡Bosque protegido!',
      destination: 'Mundo 2 · Las Cavernas',
      narrative:
          'Con el dragón vencido, el bosque recupera su brillo. Una corriente de cristales señala el camino hacia las cavernas, donde una nueva criatura guarda el siguiente fragmento.',
      objective: 'Explora las cavernas y reúne sus fragmentos de conocimiento.',
    ),
    '2_1': ChapterStory(
      heading: '¡Capítulo 1 completado!',
      destination: 'Capítulo 2 · El eco de los cristales',
      narrative:
          'El guardián de la entrada deja de rugir. Su eco revela un túnel secreto y, en sus paredes, cristales que repiten una melodía cada vez que resuelves un acertijo.',
      objective: 'Sigue la melodía hasta la cámara central.',
    ),
    '2_2': ChapterStory(
      heading: '¡Capítulo 2 completado!',
      destination: 'Capítulo 3 · El puente subterráneo',
      narrative:
          'La cámara se ilumina y un puente aparece sobre el abismo. Al fondo espera el coloso, pero las marcas del puente muestran que solo la observación permitirá cruzarlo.',
      objective: 'Alcanza el otro lado y prepárate para el coloso.',
    ),
    '2_3': ChapterStory(
      heading: '¡Cavernas superadas!',
      destination: 'Mundo 3 · Las Islas Flotantes',
      narrative:
          'El coloso abre la salida hacia el cielo. Las islas flotantes se acercan entre las nubes y una criatura alada lleva el siguiente fragmento a lo más alto.',
      objective: 'Sube por las islas y recupera el fragmento celeste.',
    ),
    '3_1': ChapterStory(
      heading: '¡Capítulo 1 completado!',
      destination: 'Capítulo 2 · Las corrientes del cielo',
      narrative:
          'La primera isla vuelve a elevarse. Un mapa de viento aparece en el suelo y señala una ruta cambiante entre las nubes; tendrás que leer sus señales para avanzar.',
      objective: 'Encuentra la corriente que conduce a la isla central.',
    ),
    '3_2': ChapterStory(
      heading: '¡Capítulo 2 completado!',
      destination: 'Capítulo 3 · La tormenta de cristal',
      narrative:
          'La ruta segura termina ante una tormenta azul. En su centro brilla el último fragmento del cielo, custodiado por el señor de las islas.',
      objective: 'Atraviesa la tormenta y reúne los fragmentos celestes.',
    ),
    '3_3': ChapterStory(
      heading: '¡Islas recuperadas!',
      destination: 'Mundo 4 · El Volcán',
      narrative:
          'La tormenta se disipa y las islas vuelven a su sitio. Desde lo alto ves un resplandor rojo: el volcán está despertando y amenaza con cubrir de ceniza todos los caminos.',
      objective: 'Llega al volcán antes de que la última ruta desaparezca.',
    ),
    '4_1': ChapterStory(
      heading: '¡Capítulo 1 completado!',
      destination: 'Capítulo 2 · El río de magma',
      narrative:
          'La salamandra se aparta y deja al descubierto un sendero entre rocas negras. Un río de magma corta el camino; sus antiguas señales indican cuándo es seguro avanzar.',
      objective: 'Lee las señales y cruza el río de magma.',
    ),
    '4_2': ChapterStory(
      heading: '¡Capítulo 2 completado!',
      destination: 'Capítulo 3 · El corazón del volcán',
      narrative:
          'El río se calma y la montaña guarda silencio. En lo profundo, el titán protege el corazón del volcán; resolver sus pruebas puede detener la erupción.',
      objective: 'Enfrenta al titán y protege los cuatro mundos.',
    ),
  };

  static ChapterStory? afterChapter(int world, int chapter) {
    if (world == 4 && chapter == 3) {
      return const ChapterStory(
        heading: '¡Aventura completada!',
        destination: 'Los cuatro mundos están a salvo',
        narrative:
            'El corazón del volcán se apaga y una luz recorre el bosque, las cavernas y las islas. Tus respuestas ayudaron a reunir los fragmentos y a restaurar el equilibrio.',
        objective: 'Tu leyenda queda escrita. Puedes volver a los mundos para mejorar tus estrellas.',
      );
    }
    return _stories['${world}_$chapter'];
  }
}
