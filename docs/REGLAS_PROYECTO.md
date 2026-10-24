# Words & Monsters — reglas del proyecto

Reglas que siguen todas las IA que trabajan en este repositorio (Claude y ChatGPT).
Las mismas están en las instrucciones del Proyecto "Words & Monsters" de ChatGPT.

## Qué es

Juego móvil de trivia en Flutter, para todas las edades. Multilenguaje: idioma base español de España, luego inglés y otros.
Estilo fantasía oscura. Primero se publica en Android.
4 mundos (Bosque, Cavernas, Islas Flotantes, Volcán) x 3 capítulos x 5 niveles.
El nivel 5 de cada capítulo es una pelea tipo Street Fighter (guardián); la del capítulo 3 es la batalla final del mundo.
Para entrar a cada pelea hace falta un mínimo de estrellas en ese mundo (ver lib/services/fighter_service.dart).

## Estilo visual (obligatorio en pantallas nuevas o rediseñadas)

- Usa SIEMPRE las piezas de lib/widgets/game_3d.dart: GameBackground, GameHeader,
  Panel3D, Pressable3D, Bar3D, Socket3D, Chip3D, OutlinedGameText, Bob, Pulse, EntranceFlip.
- Colores solo desde la clase WM (cian #1EE3CF, contorno #0D0326, hueso #F4EBDD, oro...).
- Fuentes: Anton (títulos), Oswald (texto), Metal Mania (logo). Nunca Poppins.
- Nunca pongas emojis dentro de OutlinedGameText: se dibujan triplicados.
  Pon el emoji en un Text normal al lado.

## Imágenes

- Estilo: ilustración de fantasía semirrealista para juego móvil, colores saturados,
  luz desde arriba, igual que las imágenes de referencia.
- Avatares: busto de frente, cuadrado, fondo transparente real, sin marco ni círculo.
  En el repositorio, 512x512 px como máximo.
- Contenido apto para niños.

## Archivos que NO se tocan sin pedirlo explícitamente

lib/firebase_options.dart, android/app/google-services.json, firebase.json,
.firebaserc, firestore.rules.

## Forma de trabajar

- Cada tarea en su propia rama; nunca directamente en main.
- Nunca dos IA cambiando los mismos archivos a la vez.
- Antes de escribir código, explicar el plan en español sencillo y esperar el visto bueno.
- Cambiar solo lo que pide la tarea. Otros problemas se mencionan, no se arreglan por cuenta propia.
- No añadir paquetes nuevos a pubspec.yaml sin preguntar.
- Comprobar con `flutter analyze` antes de dar una tarea por terminada.
- Terminar con un resumen: archivos cambiados, qué cambió y por qué, y cómo probarlo.
- Comentar en español las partes no obvias del código.
- Cuando exista lib/l10n, nunca escribir textos visibles fijos en el código: añadirlos a los archivos .arb.
