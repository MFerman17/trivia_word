# Publicar Words & Monsters en Google Play

Guía paso a paso. Las partes de código ya están hechas en la rama `publicacion`;
aquí está lo que hay que hacer **fuera del código** (Firebase, AdMob, Play Console).

## Ya hecho en el código

- Identificador permanente: `com.mferman.wordsandmonsters`.
- Nombre en el teléfono: **Words & Monsters**.
- Firma de publicación con `android/key.properties` (ver paso 2).
- Aviso de consentimiento de anuncios para Europa (RGPD) y botón
  «Privacidad de anuncios» en Ajustes.
- Botón **Borrar mis datos** en Ajustes → Cuenta y datos (lo exige Google Play).
- Páginas públicas en `docs/`: `privacidad.html` y `borrar-datos.html`.

## 0. Correo de contacto

Correo público de soporte: **wordsandmonsters.soporte@gmail.com**. Ya está en
`docs/privacidad.html` y `docs/borrar-datos.html`. Úsalo también como correo
de contacto en la ficha de Google Play y en AdMob.

## 1. Firebase: registrar el nuevo identificador

Al cambiar el identificador, Firebase debe conocerlo. **Hasta hacer este paso,
la app no compila** (el archivo `google-services.json` actual es del
identificador viejo).

1. Firebase Console → tu proyecto → ⚙️ Configuración del proyecto →
   **Añadir app** → Android.
2. Nombre del paquete: `com.mferman.wordsandmonsters`. Apodo: Words & Monsters.
3. Huella SHA-1 de depuración (para que funcione «Guardar avance en Google»
   al probar). En PowerShell, dentro de la carpeta del proyecto:

   ```powershell
   cd android
   .\gradlew signingReport
   cd ..
   ```

   Copia el `SHA1` de la variante `debug`.
4. Descarga el nuevo `google-services.json` y reemplaza el de `android/app/`.
5. Instala FlutterFire CLI (solo hace falta una vez):

   ```powershell
   dart pub global activate flutterfire_cli
   ```

   En Windows, Dart guarda sus comandos globales en
   `$env:LOCALAPPDATA\Pub\Cache\bin`. Si PowerShell sigue sin reconocer
   `flutterfire`, añade esa carpeta a la variable `Path` de usuario y vuelve
   a abrir PowerShell o VS Code. Para usarla solo en la sesión actual:

   ```powershell
   $env:Path += ";$env:LOCALAPPDATA\Pub\Cache\bin"
   ```

6. Regenera `lib/firebase_options.dart`:

   ```powershell
   flutterfire configure
   ```

   Si no quieres modificar `Path`, puedes ejecutar la CLI directamente:

   ```powershell
   dart pub global run flutterfire_cli:flutterfire configure
   ```

   Elige el mismo proyecto y marca **android, ios y web** (no solo
   android: el juego también se prueba en Chrome y necesita la configuración
   web). Si pregunta si reutilizar `firebase.json`, responde **no**.

   Si `flutterfire` da problemas, basta con cambiar a mano el `appId` de
   Android en `lib/firebase_options.dart` y en `firebase.json` por el
   `mobilesdk_app_id` de la app nueva que aparece en `google-services.json`.
7. Más adelante añade también (en la misma app de Firebase → Añadir huella):
   - el SHA-1 de tu **llave de subida** (paso 2), y
   - el SHA-1 de **firma de apps de Google Play** (Play Console → Prueba y
     publicación → Configuración → Integridad de la app). Sin este último,
     «Guardar avance en Google» falla en la versión descargada de la tienda.

## 2. Llave de subida (firma)

Google Play exige que cada versión vaya firmada con **tu** llave. Si la pierdes,
no podrás publicar actualizaciones con facilidad: guárdala en dos sitios
(por ejemplo, el PC y un USB o la nube personal).

1. Crea una carpeta para llaves **fuera del proyecto**, p. ej.
   `C:\Users\TU_USUARIO\llaves`.
2. Crea la llave (PowerShell). `keytool` viene con Android Studio:

   ```powershell
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v `
     -keystore "$env:USERPROFILE\llaves\words-and-monsters-upload.jks" `
     -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Te pedirá una contraseña y unos datos (nombre, país…). Apunta la contraseña.
3. Copia `android/key.properties.ejemplo` como `android/key.properties` y
   rellénalo. Ese archivo **no se sube a GitHub** (está en `.gitignore`).
4. Para ver el SHA-1 de esta llave (para Firebase, paso 1.6):

   ```powershell
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v `
     -keystore "$env:USERPROFILE\llaves\words-and-monsters-upload.jks" -alias upload
   ```

## 3. AdMob (anuncios reales)

1. AdMob → Apps → Añadir app → Android → *todavía no está en la tienda*.
2. Copia el **ID de la app** (`ca-app-pub-XXXX~YYYY`) y añádelo en
   `android/gradle.properties` (una línea nueva):

   ```properties
   ADMOB_APP_ID=ca-app-pub-XXXX~YYYY
   ```

3. Crea un **bloque de anuncios recompensado** y copia su ID
   (`ca-app-pub-XXXX/ZZZZ`). Se pasa al compilar (paso 5).
4. AdMob → **Privacidad y mensajes** → RGPD → crea el mensaje de
   consentimiento para la app y publícalo. Es el aviso que el juego muestra al
   abrir en Europa.
5. Cuando la app esté publicada, vincúlala en AdMob con su ficha de Google Play.

## 4. Icono

Hecho. A partir de `assets/icon/icono.png` (1024×1024) se generaron:

- `android/app/src/main/res/mipmap-*/ic_launcher.png`: icono clásico.
- `mipmap-*/ic_launcher_foreground.png` + `mipmap-anydpi-v26/ic_launcher.xml`:
  icono adaptable de Android 8+ (cada fabricante lo recorta con su forma).
- `assets/icon/play_store_512.png`: el de 512×512 para la ficha de Google Play.

Si se cambia el icono, basta con reemplazar `icono.png` y pedir que se
vuelvan a generar.

## 5. Compilar el paquete para Google Play

1. Sube la versión en `pubspec.yaml` en cada envío
   (`version: 1.0.0+1` → `1.0.1+2`…; el número tras `+` siempre debe crecer).
2. Compila:

   ```powershell
   flutter clean
   flutter pub get
   flutter gen-l10n
   flutter build appbundle --release --dart-define=ADMOB_REWARDED_ANDROID_ID=ca-app-pub-XXXX/ZZZZ
   ```

3. El archivo para subir queda en
   `build/app/outputs/bundle/release/app-release.aab`.

## 6. Activar las páginas públicas (GitHub Pages)

Después de fusionar `publicacion` en `main`:
GitHub → repositorio → **Settings → Pages** → *Deploy from a branch* →
rama `main`, carpeta `/docs` → Save. En unos minutos estarán en:

- Privacidad: `https://mferman17.github.io/trivia_word/privacidad.html`
- Borrar datos: `https://mferman17.github.io/trivia_word/borrar-datos.html`

## 7. Play Console

### Cuenta

- Cuenta de desarrollador (pago único de 25 USD) con verificación de identidad.
- **Importante (cuentas personales nuevas):** antes de poder publicar en
  producción, Google exige una **prueba cerrada con al menos 12 personas
  durante 14 días seguidos**. Conviene ir reuniendo testers (familia, amigos)
  desde ya.

### Crear la app

- Nombre: **Words & Monsters** · Idioma predeterminado: Español (España) ·
  Juego · Gratis.
- Categoría: **Juegos → Trivia** (alternativa: Palabras).
- Por ahora solo hay preguntas en español: publica la ficha en español
  (España y Latinoamérica). La ficha en inglés, cuando exista el banco en inglés.

### Ficha de Play Store

**Descripción breve (máx. 80):**

> Palabras, lógica y monstruos: responde bien y salva cuatro mundos de fantasía.

**Descripción completa:**

> ¿Cuánto sabes de palabras? En Words & Monsters cada respuesta es un golpe:
> acierta para derrotar a los monstruos y avanza por el Bosque, las Cavernas,
> las Islas Flotantes y el Volcán.
>
> 📚 600 preguntas de ortografía, tildes, sinónimos, refranes, analogías,
> anagramas, adivinanzas, lógica y cultura general, que se vuelven más
> difíciles a medida que avanzas.
>
> ⚔️ Peleas al estilo de los juegos de lucha: responde rápido para dar patadas,
> encadena combos y lanza tu ataque SUPER contra los guardianes y el jefe
> final de cada mundo.
>
> ⭐ Consigue estrellas para desbloquear las peleas, completa misiones, abre el
> cofre diario y mejora tu luchador.
>
> 🧙 Personaliza tu héroe con personajes, marcos y accesorios.
>
> 🏆 Compite en el ranking y guarda tu avance con tu cuenta de Google.
>
> Para todas las edades: aprende jugando, sin darte cuenta.

**Gráficos necesarios:** icono 512×512, gráfico destacado 1024×500 (prompt
abajo) y al menos 2 capturas del teléfono (portada, mapa, combate, pelea).

> Feature graphic 1024x500 for the mobile game "Words & Monsters": a young
> fantasy hero in a fighting stance facing a cute crystal bat monster across a
> glowing arena, floating golden letters between them, dark purple fantasy
> sky, semi-realistic mobile game art, saturated colors, cyan and gold
> highlights, leave the left third calm for the title, no text.

### Contenido de la aplicación (respuestas)

- **Política de privacidad:** la URL de privacidad del paso 6.
- **Anuncios:** Sí, contiene anuncios.
- **Acceso a la app:** toda la funcionalidad está disponible sin credenciales
  especiales.
- **Público objetivo:** 13–15, 16–17 y 18+ (no menores de 13).
- **Clasificación de contenido (cuestionario IARC):** juego; violencia de
  fantasía/dibujos animados leve (golpes a monstruos, sin sangre); sin
  lenguaje ofensivo, sin contenido sexual, sin apuestas; interacción entre
  usuarios: no (el ranking solo muestra nombre y puntos); compras dentro de la
  app: no (las monedas y gemas se ganan jugando).
- **ID de publicidad:** Sí, se usa para publicidad (AdMob).
- **Eliminación de cuentas:** URL de borrar datos del paso 6.
- **Seguridad de los datos** (revísalo con la guía de AdMob/Firebase de
  Google, que puede cambiar):
  - Recoge datos: sí. Cifrados en tránsito: sí. El usuario puede pedir que se
    borren: sí.
  - *Información personal → Correo electrónico* (opcional, al vincular
    Google): gestión de la cuenta y funcionalidad.
  - *Actividad en la app → Otras acciones* (avance del juego): funcionalidad.
  - *Identificadores del dispositivo u otros* (Firebase y AdMob): funcionalidad,
    publicidad y prevención de fraude. AdMob los comparte con Google para
    anuncios.

### Lanzamiento

1. **Prueba interna** (tú solo): sube el `.aab`, instala desde Play y
   comprueba todo (anuncios reales, guardar en Google, compras con monedas).
2. **Prueba cerrada** con 12+ testers durante 14 días.
3. **Producción.**
