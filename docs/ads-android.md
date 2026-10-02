# Anuncios recompensados en Android

La tienda usa anuncios recompensados de Google Mobile Ads. En compilaciones de
depuración se usan los IDs de prueba oficiales de Google; no generan ingresos.

Antes de publicar, configura el ID real de aplicación de AdMob como propiedad de
Gradle `ADMOB_APP_ID` y el ID del bloque recompensado mediante
`--dart-define=ADMOB_REWARDED_ANDROID_ID=...`. El código de producción no carga
un anuncio si falta el ID real del bloque.

No guardes credenciales de cuenta ni claves privadas en el repositorio. Los IDs
de aplicación y de bloque de AdMob son identificadores de configuración, no
contraseñas. Añade el consentimiento de anuncios correspondiente a los países
de distribución antes de activar anuncios reales.
