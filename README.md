# Words & Monsters

Juego móvil de trivia (Flutter) en español e inglés: el jugador recorre 6
mundos de 3 capítulos y 10 niveles cada uno, derrotando monstruos al
responder preguntas. Incluye peleas por rounds, mini-retos, torneo semanal,
desafío diario, torre infinita, racha de 7 días, misiones y tienda.

- **Android** (Google Play): `com.mferman.wordsandmonsters`.
- **Web** (Chrome) para probar durante el desarrollo.

## Empezar

```powershell
flutter pub get
flutter gen-l10n        # genera los textos a partir de lib/l10n/*.arb
flutter run -d chrome   # o con el móvil conectado: flutter run
```

Después de cambiar de rama, vuelve a ejecutar `flutter pub get` y
`flutter gen-l10n`.

## Pruebas

```powershell
flutter analyze
flutter test
```

- `test/l10n_test.dart`: todos los idiomas tienen los mismos textos.
- `test/question_bank_test.dart`: formato del banco de preguntas.
- `test/services_test.dart`: edad, racha, torre y topes de videos.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| `lib/screens/` | Pantallas (portada, mapa, nivel, pelea, tienda, desafíos…) |
| `lib/controllers/` | Lógica de un nivel (`game_controller`) y de una pelea (`fight_controller`) |
| `lib/services/` | Guardado, nube (Firebase), anuncios, Pase VIP, analítica, avisos… |
| `lib/widgets/` | Piezas visuales reutilizables (botones 3D, efectos de victoria, tutorial…) |
| `lib/config/` | Mapas de cada mundo e IDs de AdMob |
| `lib/l10n/` | Textos: `app_es.arb` (base) y `app_en.arb` |
| `assets/questions/` | Banco de preguntas por idioma y dificultad |
| `assets/images/` | Mapas (JPG), monstruos, luchadores, iconos (PNG) |
| `docs/` | Guías y páginas públicas (privacidad, borrar datos) |
| `firestore.rules` | Reglas de seguridad de Firestore (publicarlas en la consola) |

## Documentación

- `docs/PUBLICAR_GOOGLE_PLAY.md`: publicación paso a paso (firma, AdMob,
  mediación, app-ads.txt, Pase VIP, analítica, Play Console).
- `docs/GUIA_ESTILO_VISUAL.md`: estilo e instrucciones para generar imágenes.
- `docs/SONIDOS.md`: efectos de sonido y de dónde salen.
- `docs/REGLAS_PROYECTO.md`: normas de trabajo del proyecto.

## Monetización

- Videos **voluntarios** con premio (AdMob + mediación con Unity Ads).
- Botón «x2 monedas» tras cada victoria.
- **Pase VIP** (`vip_pass`, compra única): los premios de video se dan sin
  ver el anuncio.
- Sin anuncios obligatorios.
