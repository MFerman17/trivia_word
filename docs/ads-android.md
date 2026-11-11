# Anuncios recompensados en Android

Ver `docs/PUBLICAR_GOOGLE_PLAY.md`, pasos 3 a 3d (IDs reales, app-ads.txt,
mediación y Pase VIP).

- En debug se usan siempre los IDs de prueba de Google (no generan ingresos).
- ID del bloque recompensado: `lib/config/ads_config.dart`.
- ID de la app: `android/gradle.properties` → `ADMOB_APP_ID`.
- Cada video indica su sitio (`placement`) para la analítica.
- Topes diarios: 5 pociones y 5 pistas por video en la tienda, 5 vidas.
- Con el Pase VIP los premios se dan sin video (mismos topes).
